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

  try {
    const { filename, contentType } = await req.json()
    if (!filename || !contentType) {
      return json({ error: "filename and contentType are required" }, { status: 400 })
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL")
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")
    if (!supabaseUrl || !serviceKey) {
      return json({ error: "Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY" }, { status: 500 })
    }

    const supabase = createClient(supabaseUrl, serviceKey)
    // Ensure bucket exists (idempotent)
    await supabase.storage.createBucket("images", { public: true }).catch(() => {})

    const { data, error } = await supabase.storage
      .from("images")
      .createSignedUploadUrl(filename)

    if (error) return json({ error: error.message }, { status: 400 })

    return json({ uploadUrl: data.signedUrl, path: data.path, token: data.token })
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err)
    return json({ error: message }, { status: 500 })
  }
})
