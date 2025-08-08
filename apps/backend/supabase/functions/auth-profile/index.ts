import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
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

  const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "http://127.0.0.1:54321"
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? Deno.env.get("ANON_KEY")
  if (!anonKey) {
    return json({ error: "Missing anon key in env" }, { status: 500 })
  }

  const authHeader = req.headers.get("Authorization")
  if (!authHeader) {
    return json({ success: false, error: "Missing Authorization header" }, { status: 401 })
  }

  // Create a client scoped to the provided user access token
  const client = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } },
  })

  // Get user id from token
  const { data: userData, error: userErr } = await client.auth.getUser()
  if (userErr || !userData?.user) {
    return json({ success: false, error: userErr?.message ?? "Invalid session" }, { status: 401 })
  }

  const userId = userData.user.id

  const { data: profile, error: profileErr } = await client
    .from("user_profiles")
    .select("*")
    .eq("id", userId)
    .single()

  if (profileErr) {
    return json({ success: false, error: profileErr.message }, { status: 400 })
  }

  return json({ success: true, user: profile })
})


