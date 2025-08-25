import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createRemoteJWKSet, jwtVerify } from "https://deno.land/x/jose@v4.15.5/index.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

type AppleUserPayload = {
  identityToken: string
  authorizationCode?: string
  user?: {
    id?: string
    email?: string
    name?: string
  }
}

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
}

async function verifyAppleToken(identityToken: string): Promise<Record<string, unknown>> {
  const JWKS = createRemoteJWKSet(new URL("https://appleid.apple.com/auth/keys"))
  const { payload, protectedHeader } = await jwtVerify(identityToken, JWKS, {
    issuer: "https://appleid.apple.com",
  })
  return { payload, header: protectedHeader }
}

function json(data: unknown, init: ResponseInit = {}) {
  return new Response(JSON.stringify(data), {
    headers: { "Content-Type": "application/json", ...corsHeaders },
    ...init,
  })
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: corsHeaders })
  }

  try {
    const { identityToken, user }: AppleUserPayload = await req.json()
    if (!identityToken) {
      return json({ error: "identityToken is required" }, { status: 400 })
    }

    // Verify Apple identity token (best-effort for MVP)
    let applePayload: Record<string, unknown> | null = null
    try {
      const verified = await verifyAppleToken(identityToken)
      applePayload = verified.payload as Record<string, unknown>
    } catch (_err) {
      applePayload = null
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "http://127.0.0.1:54321"
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? Deno.env.get("SERVICE_ROLE_KEY")
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? Deno.env.get("ANON_KEY")
    if (!serviceKey || !anonKey) {
      return json({ error: "Missing service or anon key in env" }, { status: 500 })
    }

    // 1) Create a user session using Apple ID token (user context)
    const userClient = createClient(supabaseUrl, anonKey)
    const { data: signInData, error: signInErr } = await userClient.auth.signInWithIdToken({
      provider: "apple",
      token: identityToken,
    })
    if (signInErr || !signInData?.session || !signInData.user) {
      return json({ error: signInErr?.message ?? "Failed to sign in with Apple" }, { status: 400 })
    }

    const session = signInData.session
    const authedUser = signInData.user

    // 2) Upsert profile using service role (bypass RLS for write)
    const serviceClient = createClient(supabaseUrl, serviceKey)

    const candidateEmail = authedUser.email || (applePayload?.email as string | undefined) || user?.email
    const candidateName = (authedUser.user_metadata?.name as string | undefined) || (user?.name as string | undefined)
    const appleId = (authedUser.user_metadata?.apple_id as string | undefined) || (applePayload?.sub as string | undefined) || user?.id

    // Fetch existing profile; only set name/email on first sign-in to avoid overwriting with nulls later
    const { data: existingProfile, error: fetchErr } = await serviceClient
      .from("user_profiles")
      .select("id, email, name, apple_id")
      .eq("id", authedUser.id)
      .maybeSingle()

    if (fetchErr) {
      return json({ error: fetchErr.message }, { status: 400 })
    }

    if (!existingProfile) {
      const { error: insertErr } = await serviceClient.from("user_profiles").insert({
        id: authedUser.id,
        email: candidateEmail ?? null,
        name: candidateName ?? null,
        apple_id: appleId ?? null,
        updated_at: new Date().toISOString(),
      })
      if (insertErr) {
        return json({ error: insertErr.message }, { status: 400 })
      }

      // Best-effort: persist name/apple_id to Auth user_metadata on first sign-in
      try {
        if (candidateName || appleId) {
          await serviceClient.auth.admin.updateUserById(authedUser.id, {
            user_metadata: {
              ...(candidateName ? { name: candidateName } : {}),
              ...(appleId ? { apple_id: appleId } : {}),
            },
          })
        }
      } catch (_e) {
        // no-op
      }
    } else {
      const updates: Record<string, unknown> = { updated_at: new Date().toISOString() }
      if (!existingProfile.email && candidateEmail) updates.email = candidateEmail
      if (!existingProfile.name && candidateName) updates.name = candidateName
      if (!existingProfile.apple_id && appleId) updates.apple_id = appleId

      if (Object.keys(updates).length > 1) {
        const { error: updateErr } = await serviceClient
          .from("user_profiles")
          .update(updates)
          .eq("id", authedUser.id)
        if (updateErr) {
          return json({ error: updateErr.message }, { status: 400 })
        }
      }
    }

    // 3) Fetch the full profile row (user-scoped)
    const authedClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: `Bearer ${session.access_token}` } },
    })
    const { data: profile, error: profileErr } = await authedClient
      .from("user_profiles")
      .select("*")
      .eq("id", authedUser.id)
      .single()

    if (profileErr) {
      return json({ error: profileErr.message }, { status: 400 })
    }

    // 4) Return iOS-friendly response
    return json({
      success: true,
      user: profile,
      session: {
        access_token: session.access_token,
        refresh_token: session.refresh_token,
        expires_in: session.expires_in ?? 3600,
      },
    })
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err)
    return json({ error: message }, { status: 500 })
  }
})


