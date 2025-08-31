import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"
import { callOpenAI } from "./openai.ts"
import { buildPrimaryPrompt, buildRetryPrompt } from "./prompt.ts"

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

function err(code: string, message: string, status: number, ai_step?: string) {
  return json({ error: message, code, ai_step: ai_step ?? null }, { status })
}

// LLM call helper moved to openai.ts

// Track prompt changes for easier debugging of cache behavior
const PROMPT_VERSION = "2024-08-24_v1"

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
    const startedAt = Date.now()
    let aiStep = "init"
    let cacheHits = 0
    let cacheMisses = 0
    let parseFailures = 0
    const { entryId, blocks } = await req.json()
    if (!entryId || !Array.isArray(blocks)) {
      return err("bad_request", "entryId and blocks are required", 400, "validate_input")
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL")
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")
    const openaiKey = Deno.env.get("OPENAI_API_KEY")
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY")
    if (!supabaseUrl || !serviceKey) {
      return err("server_misconfig", "Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY", 500, "env")
    }
    if (!anonKey) {
      return err("server_misconfig", "Missing SUPABASE_ANON_KEY", 500, "env")
    }
    if (!openaiKey) {
      return err("server_misconfig", "Missing OPENAI_API_KEY", 500, "env")
    }

    // Model and temperature from env with safe defaults
    const model = Deno.env.get("AI_MODEL") || "gpt-4o-mini"
    const tempEnv = Number(Deno.env.get("AI_TEMPERATURE") || "0.2")
    const temperature = Math.max(0, Math.min(0.3, isNaN(tempEnv) ? 0.2 : tempEnv))
    const maxBlocksEnv = Number(Deno.env.get("AI_MAX_BLOCKS") || "50")
    const maxBlocks = Math.max(1, Math.min(200, isNaN(maxBlocksEnv) ? 50 : maxBlocksEnv))
    const debug = Deno.env.get("AI_DEBUG") === "true"

    const supabase = createClient(supabaseUrl, serviceKey)

    // Auth & ownership check
    const authHeader = req.headers.get("Authorization") ?? ""
    if (!authHeader.startsWith("Bearer ")) {
      return err("unauthorized", "Missing Authorization header", 401, "auth")
    }
    const userClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authHeader } },
    })
    const { data: ownedEntry } = await userClient
      .from("diary_entries")
      .select("id")
      .eq("id", entryId)
      .maybeSingle()
    if (!ownedEntry) {
      const { data: exists } = await supabase
        .from("diary_entries")
        .select("id")
        .eq("id", entryId)
        .maybeSingle()
      if (!exists) {
        return err("not_found", "Entry not found", 404, "auth_ownership")
      }
      return err("forbidden", "Forbidden", 403, "auth_ownership")
    }

    // Enforce block limit (count non-empty text blocks only)
    const nonEmptyCount = (blocks as Array<any>).reduce((n, b) => {
      const t = typeof b?.content === "string" ? b.content.trim() : ""
      return n + (t ? 1 : 0)
    }, 0)
    const totalBlocks = (blocks as Array<any>).length
    if (nonEmptyCount > maxBlocks) {
      return err("too_many_blocks", `Too many blocks: ${nonEmptyCount} > ${maxBlocks}`, 400, "validate_blocks")
    }

    console.log(
      JSON.stringify({
        event: "ai_analyze_start",
        entryId,
        totalBlocks,
        nonEmptyCount,
        model,
        temperature,
      }),
    )

    // Set status to processing
    aiStep = "set_processing_status"
    await supabase.from("diary_entries").update({ ai_analysis_status: "processing" }).eq("id", entryId)

    const updatedBlocks = [] as any[]
    for (const block of blocks as Array<any>) {
      // Normalize/namespace client-provided block ids to be unique per entry
      const originalId = typeof (block as any)?.id === "string" ? String((block as any).id) : String((block as any)?.id ?? "")
      const safeId = originalId
        ? (originalId.startsWith(`${entryId}:`) ? originalId : `${entryId}:${originalId}`)
        : crypto.randomUUID()
      const normalizedBlock = { ...block, id: safeId }
      const contentText = typeof (normalizedBlock as any)?.content === "string" ? String((normalizedBlock as any).content).trim() : ""
      if (!contentText) {
        updatedBlocks.push(normalizedBlock)
        continue
      }
      const contentHash = await sha256(contentText)

      // Check cache
      aiStep = "cache_lookup"
      const { data: cached } = await supabase
        .from("ai_analysis_cache")
        .select("analysis_result, confidence, parse_ok")
        .eq("content_hash", contentHash)
        .maybeSingle()

      if (cached && (cached as any)?.parse_ok !== false) {
        const analysis = cached.analysis_result as any
        cacheHits++
        updatedBlocks.push({
          ...normalizedBlock,
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
      const prompt = buildPrimaryPrompt(contentText)
      // First attempt (tolerate provider failures in dev by falling back to zeros)
      aiStep = "openai_call_primary"
      let content = ""
      let usedModel: string | undefined = undefined
      let usage: { prompt_tokens?: number; completion_tokens?: number; total_tokens?: number } | undefined = undefined
      let parseError: string | null = null
      let attempt: "primary" | "retry" = "primary"
      try {
        const result = await callOpenAI(prompt, openaiKey, model, temperature)
        content = result?.content ?? ""
        usedModel = result?.model ?? model
        usage = result?.usage
        if (debug) {
          console.log(
            JSON.stringify({
              event: "openai_call_primary_ok",
              contentLength: content.length,
              model: usedModel,
              temperature,
              promptVersion: PROMPT_VERSION,
            }),
          )
        }
      } catch (e) {
        if (debug) {
          console.log(
            JSON.stringify({
              event: "openai_call_primary_error",
              error: e instanceof Error ? e.message : String(e),
              model: usedModel ?? model,
              temperature,
              promptVersion: PROMPT_VERSION,
            }),
          )
        }
        content = ""
      }
      let analysis: any = {}
      let parsedOk = false
      try {
        analysis = JSON.parse(content)
        parsedOk = typeof analysis === "object" && analysis !== null
      } catch {
        parsedOk = false
        parseError = "Invalid JSON from provider"
      }
      if (debug) {
        console.log(
          JSON.stringify({
            event: "openai_parse_primary",
            parsedOk,
            hasCalories: typeof analysis?.calories !== "undefined",
            contentPreview: content?.slice(0, 80) ?? "",
          }),
        )
      }
      // One-time retry with stricter instruction if parsing failed
      if (!parsedOk) {
        const retryPrompt = buildRetryPrompt(contentText)
        aiStep = "openai_call_retry"
        try {
          const result = await callOpenAI(retryPrompt, openaiKey, model, temperature)
          content = result?.content ?? ""
          usedModel = result?.model ?? model
          usage = result?.usage
          attempt = "retry"
          if (debug) {
            console.log(
              JSON.stringify({
                event: "openai_call_retry_ok",
                contentLength: content.length,
                model: usedModel,
                temperature,
                promptVersion: PROMPT_VERSION,
              }),
            )
          }
        } catch (e) {
          if (debug) {
            console.log(
              JSON.stringify({
                event: "openai_call_retry_error",
                error: e instanceof Error ? e.message : String(e),
                model: usedModel ?? model,
                temperature,
                promptVersion: PROMPT_VERSION,
              }),
            )
          }
          content = ""
        }
        try {
          analysis = JSON.parse(content)
          parsedOk = typeof analysis === "object" && analysis !== null
        } catch {
          analysis = {}
          parsedOk = false
          parseError = "Invalid JSON from provider (retry)"
        }
        if (debug) {
          console.log(
            JSON.stringify({
              event: "openai_parse_retry",
              parsedOk,
              hasCalories: typeof analysis?.calories !== "undefined",
              contentPreview: content?.slice(0, 80) ?? "",
            }),
          )
        }
      }
      if (!parsedOk) {
        parseFailures++
      }
      cacheMisses++

      // Cache
      aiStep = "cache_insert"
      await supabase.from("ai_analysis_cache").insert({
        content_hash: contentHash,
        content: contentText,
        analysis_result: analysis,
        confidence: analysis?.confidence ?? 0,
        raw_response_text: content ?? null,
        provider_model: usedModel ?? model,
        temperature,
        prompt_version: PROMPT_VERSION,
        parse_ok: parsedOk,
        parse_error_text: parsedOk ? null : parseError,
        attempt,
        usage_prompt_tokens: usage?.prompt_tokens ?? null,
        usage_completion_tokens: usage?.completion_tokens ?? null,
        usage_total_tokens: usage?.total_tokens ?? null,
      })
      if (debug) {
        console.log(
          JSON.stringify({
            event: "cache_inserted",
            contentHash,
            cachedCalories: analysis?.calories ?? null,
            parseOk: parsedOk,
            attempt,
          }),
        )
      }

      updatedBlocks.push({
        ...normalizedBlock,
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

    // Recompute totals via DB function; fallback to local sum if RPC fails
    let totals: any = null
    try {
      aiStep = "rpc_calculate_totals"
      const { data: totalsData } = await supabase.rpc("calculate_diary_totals", {
        blocks_json: updatedBlocks as any,
      })
      totals = totalsData || null
    } catch (_) {
      totals = null
    }
    if (!totals) {
      totals = (updatedBlocks as any[]).reduce(
        (acc, b: any) => ({
          total_calories: acc.total_calories + (Number(b?.calories) || 0),
          total_protein: acc.total_protein + (Number(b?.protein) || 0),
          total_fat: acc.total_fat + (Number(b?.fat) || 0),
          total_carbs: acc.total_carbs + (Number(b?.carbs) || 0),
          total_fiber: acc.total_fiber + (Number(b?.fiber) || 0),
          total_sugar: acc.total_sugar + (Number(b?.sugar) || 0),
          total_sodium: acc.total_sodium + (Number(b?.sodium) || 0),
        }),
        {
          total_calories: 0,
          total_protein: 0,
          total_fat: 0,
          total_carbs: 0,
          total_fiber: 0,
          total_sugar: 0,
          total_sodium: 0,
        },
      )
    }

    // Write back results with totals atomically
    aiStep = "write_entry_update"
    await supabase
      .from("diary_entries")
      .update({
        blocks: updatedBlocks,
        total_calories: Number(totals?.total_calories) || 0,
        total_protein: Number(totals?.total_protein) || 0,
        total_fat: Number(totals?.total_fat) || 0,
        total_carbs: Number(totals?.total_carbs) || 0,
        total_fiber: Number(totals?.total_fiber) || 0,
        total_sugar: Number(totals?.total_sugar) || 0,
        total_sodium: Number(totals?.total_sodium) || 0,
        ai_analysis_status: "completed",
      })
      .eq("id", entryId)

    const durationMs = Date.now() - startedAt
    console.log(
      JSON.stringify({
        event: "ai_analyze_completed",
        entryId,
        totalBlocks,
        nonEmptyCount,
        cacheHits,
        cacheMisses,
        updatedBlocksCount: updatedBlocks.length,
        durationMs,
        model,
        temperature,
      }),
    )

    const response: any = { success: true, updatedBlocksCount: updatedBlocks.length }
    if (debug) {
      response.debug = { cacheHits, cacheMisses, parseFailures }
    }
    return json(response)
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err)
    try {
      const { entryId } = await req.json()
      console.error(
        JSON.stringify({
          event: "ai_analyze_error",
          entryId: entryId ?? null,
          message,
        }),
      )
    } catch (_) {
      console.error(JSON.stringify({ event: "ai_analyze_error", entryId: null, message }))
    }
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
    return err("internal_error", message, 500, "catchall")
  }
})
