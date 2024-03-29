/*
　参考 [Slack][AWSサーバレス]Slackワークスペースへの読み取り権限がほぼゼロのChatGPTボットを作る
    https://dev.classmethod.jp/articles/slack-chat-gpt-bot/
*/


// server/src/handler.ts
import { App, AwsLambdaReceiver } from "@slack/bolt";
import { ChatCompletionRequestMessage, Configuration, OpenAIApi } from "openai";
import { DynamoDBClient } from "@aws-sdk/client-dynamodb";
import {
  DeleteCommand,
  DynamoDBDocumentClient,
  PutCommand,
  QueryCommand,
} from "@aws-sdk/lib-dynamodb";
import dayjs from "dayjs";
import utc from "dayjs/plugin/utc";
import advancedFormat from "dayjs/plugin/advancedFormat";
import { orderBy, pick } from "lodash-es";
import type { MessageDdbItem } from "./schema";
import type { APIGatewayProxyHandler } from "aws-lambda";

dayjs.extend(utc);
dayjs.extend(advancedFormat);

const nanoSecondFormat = "YYYY-MM-DDTHH:mm:ss.SSSSSSSSS[Z]";

const messagesTableName = process.env["MESSAGES_TABLE_NAME"] ?? "";
const threadTsIndexName = "threadTsIndex";

const ddbDocClient = DynamoDBDocumentClient.from(
  new DynamoDBClient({
    region: "ap-northeast-1",
  })
);

const openAiApi = new OpenAIApi(
  new Configuration({
    apiKey: process.env["OPEN_AI_API_KEY"] ?? "",
  })
);

// @see https://slack.dev/bolt-js/deployments/aws-lambda
const awsLambdaReceiver = new AwsLambdaReceiver({
  signingSecret: process.env["SLACK_SIGNING_SECRET"] ?? "",
});
const app = new App({
  token: process.env["SLACK_BOT_TOKEN"] ?? "",
  receiver: awsLambdaReceiver,
});

// @see https://zenn.dev/yukiueda/articles/ef0f085f2bef8e
app.event(
  "app_mention",
  async ({ event, say, context, logger, body, ...rest }) => {
    logger.info({ event, context, rest });

    try {
      // @see https://dev.classmethod.jp/articles/slack-resend-matome/
      if (context.retryNum != null && context.retryReason === "http_timeout") {
        logger.info({
          message: "Slackからのタイムアウト再送リクエストのため無視します",
        });
        return;
      }

      const threadTs = event.thread_ts ?? event.ts;
      const mentionRegex = /<@.*?>/g;

      // スレッドの発言履歴を保存する
      await ddbDocClient.send(
        new PutCommand({
          TableName: messagesTableName,
          Item: {
            // @ts-expect-error
            id: `${event.client_msg_id}#user`,
            content: event.text.replaceAll(mentionRegex, "").trim(),
            threadTs,
            saidAt: dayjs().format(nanoSecondFormat),
            role: "user",
          } satisfies MessageDdbItem,
        })
      );

      // 会話中ユーザのこれまでの発言履歴を取得する
      const { Items: messages = [] } = await ddbDocClient.send(
        new QueryCommand({
          TableName: messagesTableName,
          IndexName: threadTsIndexName,
          KeyConditionExpression: "#threadTs = :threadTs",
          ExpressionAttributeNames: {
            "#threadTs": "threadTs",
          },
          ExpressionAttributeValues: {
            ":threadTs": threadTs,
          },
        })
      );

      // 時系列順にソートする
      const orderedMessages = orderBy(messages, "saidAt", "asc");
      // 直近10件を取得
      // orderedMessagesは .splice の破壊的操作により古い要素のみになる
      const resentMessages = orderedMessages.splice(-10);
      // 10件を超える発言は削除する
      await Promise.all(
        orderedMessages.map((message) =>
          ddbDocClient.send(
            new DeleteCommand({
              TableName: messagesTableName,
              Key: {
                id: message["id"],
              },
            })
          )
        )
      );

      // ユーザとChatGPTの会話履歴をChatGPT APIに投げ、返答を得る
      const completion = await openAiApi.createChatCompletion({
        model: "gpt-3.5-turbo",
        messages: [
          {
            role: "system",
            // キャラ設定を記述（不要な場合は除去する）
            content: `
あなたは「GPT執事」です。以下の制約を厳密に守って会話してください。

# 制約条件

* 名前を聞かれたら、"ジェバンニ"と答えてください。
* GPT執事は、執事のような丁寧な言葉遣いで話します。
* GPT執事は、70歳の落ち着いた熟年の初老男性として振る舞います。
* GPT執事は電子の世界で人々のために執事をしています。
* セクシャルな話題は誤魔化してください。
* GPT執事の一人称は"わたくし"です。
* GPT執事の二人称は"ご主人様"です。

# GPT執事の台詞の例

* おはようございます。本日も大変よい天気でございます。
* 何かお役に立てることはございますか？
* お力になれることはございますか？
* かしこまりました。
* 大変良い質問でございます。
* 喜んでお答えいたします。
* 他に質問はございますか？
* まだまだ序ノ口でございます。
* 時にはご自分で考えたほうが良い場合もございます。

`,
          },
          ...resentMessages.map((message) =>
            pick(message, ["role", "content"])
          ),
        ] as ChatCompletionRequestMessage[],
      });

      const chatGptMessageContent =
        completion.data.choices[0]!.message!.content;
      // ChatGPTの発言を保存する
      await ddbDocClient.send(
        new PutCommand({
          TableName: messagesTableName,
          Item: {
            // @ts-expect-error
            id: `${event.client_msg_id}#assistant`,
            content: chatGptMessageContent.replaceAll(mentionRegex, "").trim(),
            threadTs,
            saidAt: dayjs().format(nanoSecondFormat),
            role: "assistant",
          } satisfies MessageDdbItem,
        })
      );

      await say({
        channel: event.channel,
        text: chatGptMessageContent,
        thread_ts: event.thread_ts ?? event.ts,
      });
    } catch (error) {
      logger.error(error);
      await say({
        channel: event.channel,
        // @ts-expect-error
        text: `[システム]予期せぬエラーが発生しました。トークン制限超過の可能性があるため、新しいスレッドで会話を始めてみてください。client_msg_id=${event.client_msg_id}`,
        thread_ts: event.thread_ts ?? event.ts,
      });
    }
  }
);

// @see https://slack.dev/bolt-js/deployments/aws-lambda
export const handler: APIGatewayProxyHandler = async (
  event,
  context,
  callback
) => {
  const awsLambdaReceiverHandler = await awsLambdaReceiver.start();
  return awsLambdaReceiverHandler(event, context, callback);
};
