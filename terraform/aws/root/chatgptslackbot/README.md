# chatgptslackbot

以下をそのまま利用させてもらいました。

参考 [Slack][AWSサーバレス]Slackワークスペースへの読み取り権限がほぼゼロのChatGPTボットを作る
https://dev.classmethod.jp/articles/slack-chat-gpt-bot/


## ハマったポイントなど

- ApiGWのエンドポイントは `https://hoge.execute-api.ap-northeast-1.amazonaws.com/api/app_mention` のようになる。コードを読めばわかるが...
- slackBotTokenは `OAuth & Permissions` の `Bot User OAuth Token` のこと
