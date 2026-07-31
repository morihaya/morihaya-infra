# OpenClaw 執事エージェント

自宅 Slack に常駐する執事型 AI エージェント。VM 106 (`192.168.1.12`) の Docker で動かす。
設計の経緯と全体計画は [docs/openclaw-butler-handover.md](../../docs/openclaw-butler-handover.md) を参照。

## 構成

| 項目 | 値 |
|------|-----|
| ホスト | VM 106 `openclaw` / 192.168.1.12 (pve3, HA 対象) |
| イメージ | `ghcr.io/openclaw/openclaw:latest` |
| モデル | Amazon Bedrock (ap-northeast-1) / 既定 Claude Haiku 4.5 |
| チャネル | Slack Socket Mode (inbound のポート公開なし) |
| デプロイ先 | `~/openclaw/` |

VM そのものは Terraform 管理 ([terraform/homelab/106vm_openclaw.tf](../../terraform/homelab/106vm_openclaw.tf))。

## ディレクトリ構成

```
~/openclaw/                    # VM 106 上
├── compose.yaml               # このリポジトリから配布
├── .env                       # 秘密情報 (git 管理外・手で作る)
└── data/
    ├── config/                # /home/node/.openclaw
    │   ├── openclaw.json      # このリポジトリから配布
    │   └── workspace/         # メモリ・自宅情報
    └── secrets/               # /home/node/.config/openclaw
```

## セットアップ

### 1. 資材を配る

```bash
scp compose.yaml morihaya@192.168.1.12:~/openclaw/
```

```bash
scp openclaw.json morihaya@192.168.1.12:~/openclaw/data/config/
```

### 2. 秘密情報を置く

`.env.example` を雛形に、VM 上で `~/openclaw/.env` を作る。**この作業だけは手で行う**
(アクセスキーやトークンをリポジトリにも会話にも残さないため)。

- `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY`
  IAM ユーザ `openclaw-butler` のもの。`aws iam create-access-key --user-name openclaw-butler`
- `SLACK_APP_TOKEN` / `SLACK_BOT_TOKEN` — 次項で発行する

```bash
chmod 600 ~/openclaw/.env
```

### 3. Slack アプリを作る

<https://api.slack.com/apps> で新規作成し、以下を設定する。

1. **Socket Mode** を有効化 → App-Level Token (`xapp-`) を `connections:write` スコープで発行
2. **OAuth & Permissions** で Bot Token Scopes を付与

   ```
   app_mentions:read, channels:history, channels:read, chat:write, commands,
   files:read, files:write, groups:history, groups:read, im:history, im:read,
   im:write, mpim:history, mpim:read, mpim:write, reactions:read,
   reactions:write, users:read
   ```

3. **Event Subscriptions** で購読

   ```
   app_mention, message.channels, message.groups, message.im, message.mpim
   (任意: app_home_opened, pin_added, reaction_added)
   ```

4. **App Home** で Messages Tab を有効化 (DM を使うため)
5. ワークスペースにインストールし、Bot User OAuth Token (`xoxb-`) を取得

### 4. 許可リストを埋める

`openclaw.json` の `allowFrom` に家族の Slack ユーザー ID (`U...`)、
常駐させるチャンネルがあれば `channels` にチャンネル ID (`C...`) を入れる。

> [!IMPORTANT]
> **表示名ではなく ID で書くこと。** 起動時に ID で解決されるため、
> 名前で書くと黙って無視される。

### 5. 起動

```bash
cd ~/openclaw && docker compose up -d
```

```bash
docker compose logs -f
```

## 運用

### モデル ID の確認

`openclaw.json` の `model.primary` は `bedrockDiscovery` で見えている ID と
一致している必要がある。

```bash
docker compose exec openclaw openclaw models list
```

### Control UI

LAN へは晒していないので、手元から見る場合は SSH ポートフォワードする。

```bash
ssh -L 18789:127.0.0.1:18789 morihaya@192.168.1.12
```

その後ブラウザで <http://127.0.0.1:18789/>。

### 更新

```bash
cd ~/openclaw && docker compose pull && docker compose up -d
```

## セキュリティ上の約束ごと

- **OpenClaw は認証情報を平文で保存する。** IAM は Bedrock の呼び出しのみに
  絞ってあり、AWS Budgets のアラートも設定済み。キーは定期的に回す
- **Control UI を LAN へ公開しない。** 過去に公開インスタンスの大量露出が
  問題になっている
- **ClawHub のスキルは入れる前にソースを読む。** エージェントと同じ権限で
  動くコードとして扱う
- **プロンプトインジェクションに注意。** エージェントが読む外部コンテンツ経由で
  指示が混入しうる。永続メモリを持つぶん汚染が残りやすい
