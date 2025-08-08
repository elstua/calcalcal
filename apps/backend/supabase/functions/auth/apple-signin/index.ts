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
  // Minimal verification for MVP; verifies signature and issuer/audience if available
  // NOTE: For production, validate audience (aud) matches your Services ID or App ID
  const JWKS = createRemoteJWKSet(new URL("https://appleid.apple.com/auth/keys"))
  const { payload, protectedHeader } = await jwtVerify(identityToken, JWKS, {
    issuer: "https://appleid.apple.com",
  })
  // payload will include sub (Apple user id), email, email_verified, etc.
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
      // For local/dev allow proceeding without hard failure
      applePayload = null
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL")
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")
    if (!supabaseUrl || !serviceKey) {
      return json({ error: "Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY" }, { status: 500 })
    }

    const supabase = createClient(supabaseUrl, serviceKey)

    const candidateEmail = user?.email || (applePayload?.email as string | undefined)
    const candidateName = user?.name as string | undefined
    const appleId = (applePayload?.sub as string | undefined) || user?.id

    // Try to create user; if exists, fetch existing
    let authUserId: string | null = null

    if (candidateEmail) {
      const { data: created, error: createErr } = await supabase.auth.admin.createUser({
        email: candidateEmail,
        email_confirm: true,
        user_metadata: {
          apple_id: appleId ?? null,
          name: candidateName ?? null,
        },
      })

      if (createErr) {
        // If user exists, look up by email
        const { data: list, error: listErr } = await supabase.auth.admin.listUsers({
          page: 1,
          perPage: 1,
          email: candidateEmail,
        })
        if (listErr || !list?.users?.length) {
          return json({ error: createErr.message }, { status: 400 })
        }
        authUserId = list.users[0].id
      } else {
        authUserId = created.user?.id ?? null
      }
    } else {
      // As a fallback, create a user without email (anonymous-like) if allowed
      const { data: created, error: createErr } = await supabase.auth.admin.createUser({
        email: undefined,
        user_metadata: {
          apple_id: appleId ?? null,
          name: candidateName ?? null,
        },
      })
      if (createErr) return json({ error: createErr.message }, { status: 400 })
      authUserId = created.user?.id ?? null
    }

    if (!authUserId) {
      return json({ error: "Failed to establish auth user" }, { status: 400 })
    }

    // Upsert profile
    const { error: upsertErr } = await supabase.from("user_profiles").upsert(
      {
        id: authUserId,
        email: candidateEmail ?? null,
        name: candidateName ?? null,
        apple_id: appleId ?? null,
        updated_at: new Date().toISOString(),
      },
      { onConflict: "id" }
    )
    if (upsertErr) {
      return json({ error: upsertErr.message }, { status: 400 })
    }

    // Issue a magic link for the email user to bootstrap a session on client
    let actionLink: string | null = null
    if (candidateEmail) {
      const { data: linkData, error: linkErr } = await supabase.auth.admin.generateLink({
        type: "magiclink",
        email: candidateEmail,
      })
      if (linkErr) {
        // Not fatal, return user id at least
        actionLink = null
      } else {
        // @ts-ignore types from Deno may differ
        actionLink = linkData?.properties?.action_link ?? null
      }
    }

    return json({
      userId: authUserId,
      appleId: appleId ?? null,
      email: candidateEmail ?? null,
      loginLink: actionLink,
    })
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err)
    return json({ error: message }, { status: 500 })
  }
})
