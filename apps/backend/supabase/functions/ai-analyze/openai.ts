import type { ChatMessage } from "./types.ts"

type OpenAIUsage = { prompt_tokens?: number; completion_tokens?: number; total_tokens?: number }
type OpenAIResult = { content: string; usage?: OpenAIUsage; model?: string }

export async function callOpenAI(
  messages: ChatMessage[],
  apiKey: string,
  model: string,
  temperature: number,
): Promise<OpenAIResult> {
  const resp = await fetch("https://api.openai.com/v1/chat/completions", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${apiKey}`,
    },
    body: JSON.stringify({
      model,
      temperature,
      messages,
      response_format: { type: "json_object" },
    }),
  })
  if (!resp.ok) throw new Error(`OpenAI error: ${resp.status}`)
  const data = await resp.json()
  const content: string = data?.choices?.[0]?.message?.content ?? ""
  const usage: OpenAIUsage | undefined = data?.usage
  const usedModel: string | undefined = data?.model ?? model
  return { content, usage, model: usedModel }
}


