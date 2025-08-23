import type { ChatMessage } from "./types.ts"

export async function callOpenAI(messages: ChatMessage[], apiKey: string, model: string, temperature: number) {
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
    }),
  })
  if (!resp.ok) throw new Error(`OpenAI error: ${resp.status}`)
  const data = await resp.json()
  const content = data.choices?.[0]?.message?.content ?? "{}"
  return content as string
}


