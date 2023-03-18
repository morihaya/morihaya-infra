/*
　参考 [Slack][AWSサーバレス]Slackワークスペースへの読み取り権限がほぼゼロのChatGPTボットを作る
    https://dev.classmethod.jp/articles/slack-chat-gpt-bot/
*/

// server/src/schema.ts
import { z } from "zod";

export const messageDdbItemSchema = z.object({
  id: z.string(),
  content: z.string(),
  threadTs: z.string(),
  saidAt: z.string(),
  role: z.enum(["user", "system", "assistant"]),
});
export type MessageDdbItem = z.infer<typeof messageDdbItemSchema>;

export const messageDdbItemsSchema = z.array(messageDdbItemSchema);
export type MessageDdbItems = z.infer<typeof messageDdbItemsSchema>;
