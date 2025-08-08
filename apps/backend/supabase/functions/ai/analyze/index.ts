import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

// OpenAI minimal client over fetch to avoid heavy deps in Edge runtime
type ChatMessage = { role: "system" | "user" | "assistant"; content: string }

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

async function callOpenAI(messages: ChatMessage[], apiKey: string) {
  const resp = await fetch("https://api.openai.com/v1/chat/completions", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${apiKey}`,
    },
    body: JSON.stringify({
      model: "gpt-4o-mini",
      temperature: 0.3,
      messages,
    }),
  })
  if (!resp.ok) throw new Error(`OpenAI error: ${resp.status}`)
  const data = await resp.json()
  const content = data.choices?.[0]?.message?.content ?? "{}"
  return content as string
}

async function sha256(text: string): Promise<string> {
  const data = new TextEncoder().encode(text)
  const hashBuffer = await crypto.subtle.digest("SHA-256", data)
  const hashArray = Array.from(new Uint8Array(hashBuffer))
  return hashArray.map((b) => b.toString(16).padStart(2, "0")).join("")
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: corsHeaders })
  }

  try {
    const { entryId, blocks } = await req.json()
    if (!entryId || !Array.isArray(blocks)) {
      return json({ error: "entryId and blocks are required" }, { status: 400 })
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL")
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")
    const openaiKey = Deno.env.get("OPENAI_API_KEY")
    if (!supabaseUrl || !serviceKey) {
      return json({ error: "Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY" }, { status: 500 })
    }
    if (!openaiKey) {
      return json({ error: "Missing OPENAI_API_KEY" }, { status: 500 })
    }

    const supabase = createClient(supabaseUrl, serviceKey)

    // Set status to processing
    await supabase.from("diary_entries").update({ ai_analysis_status: "processing" }).eq("id", entryId)

    const updatedBlocks = [] as any[]
    for (const block of blocks as Array<any>) {
      if (!block?.content) {
        updatedBlocks.push(block)
        continue
      }
      const contentHash = await sha256(String(block.content))

      // Check cache
      const { data: cached } = await supabase
        .from("ai_analysis_cache")
        .select("analysis_result, confidence")
        .eq("content_hash", contentHash)
        .maybeSingle()

      if (cached) {
        const analysis = cached.analysis_result as any
        updatedBlocks.push({
          ...block,
          calories: analysis?.calories ?? 0,
          protein: analysis?.protein ?? 0,
          fat: analysis?.fat ?? 0,
          carbs: analysis?.carbs ?? 0,
          fiber: analysis?.fiber ?? 0,
          sugar: analysis?.sugar ?? 0,
          sodium: analysis?.sodium ?? 0,
          confidence: cached.confidence ?? 0,
          ai_analysis: analysis ?? null,
        })
        continue
      }

      // Analyze with OpenAI
      const prompt: ChatMessage[] = [
        {
          role: "system",
          content:
            "You are a nutrition expert. Analyze the food description and return JSON with calories, protein, fat, carbs, fiber, sugar, sodium, and confidence in [0,1]. Return only JSON.",
        },
        { role: "user", content: String(block.content) },
      ]
      const content = await callOpenAI(prompt, openaiKey)
      let analysis: any = {}
      try {
        analysis = JSON.parse(content)
      } catch {
        analysis = {}
      }

      // Cache
      await supabase.from("ai_analysis_cache").insert({
        content_hash: contentHash,
        content: String(block.content),
        analysis_result: analysis,
        confidence: analysis?.confidence ?? 0,
      })

      updatedBlocks.push({
        ...block,
        calories: analysis?.calories ?? 0,
        protein: analysis?.protein ?? 0,
        fat: analysis?.fat ?? 0,
        carbs: analysis?.carbs ?? 0,
        fiber: analysis?.fiber ?? 0,
        sugar: analysis?.sugar ?? 0,
        sodium: analysis?.sodium ?? 0,
        confidence: analysis?.confidence ?? 0,
        ai_analysis: analysis ?? null,
      })
    }

    // Write back results
    await supabase
      .from("diary_entries")
      .update({ blocks: updatedBlocks, ai_analysis_status: "completed" })
      .eq("id", entryId)

    return json({ success: true, updatedBlocksCount: updatedBlocks.length })
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err)
    // Best-effort set to failed if possible
    try {
      const { entryId } = await req.json()
      if (entryId) {
        const supabaseUrl = Deno.env.get("SUPABASE_URL")
        const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")
        if (supabaseUrl && serviceKey) {
          const supabase = createClient(supabaseUrl, serviceKey)
          await supabase
            .from("diary_entries")
            .update({ ai_analysis_status: "failed", ai_analysis_error: message })
            .eq("id", entryId)
        }
      }
    } catch (_) {
      // ignore secondary failure
    }
    return json({ error: message }, { status: 500 })
  }
})
