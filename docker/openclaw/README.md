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

同じ VM には StackChan 用の MCP ブリッジも同居している
([docs/stackchan-mcp-bridge.md](../../docs/stackchan-mcp-bridge.md))。

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

> [!CAUTION]
> **`openclaw.json` をそのまま scp してはいけない。**
> このリポジトリは Public のため、`channels.slack` の `allowFrom` と
> `channels` は**意図的に空にしてある**。実際のユーザー ID / チャンネル ID は
> VM 上のファイルにだけ存在する。上書きすると Bot が誰にも反応しなくなる。
>
> 配布する場合は、VM 側の該当ブロックを退避してから差し替えるか、
> 変更箇所だけを手で反映すること。

```bash
scp openclaw.json morihaya@192.168.1.12:~/openclaw/data/config/
```

### 0. Bedrock の use case details を提出する

**Anthropic モデルはモデルアクセスの有効化だけでは呼べない。** アカウント単位で
use case details の提出が要る。未提出だとモデルを問わず次で失敗する。

```
ResourceNotFoundException: Model use case details have not been submitted for
this account. Fill out the Anthropic use case details form before using the
model. If you have already filled out the form, try again in 15 minutes.
```

Bedrock コンソール (ap-northeast-1) の Model access からフォームを提出する。
反映まで数分かかる。

> [!TIP]
> OpenClaw を疑う前に AWS CLI で切り分けられる。これが通らなければ AWS 側の問題。
>
> ```bash
> aws bedrock-runtime converse --region ap-northeast-1 --model-id jp.anthropic.claude-haiku-4-5-20251001-v1:0 --messages '[{"role":"user","content":[{"text":"hi"}]}]'
> ```

### 1.5. プラグインを入れる

**Bedrock も Slack も標準イメージに同梱されていない** (同梱チャネルは telegram のみ)。
入れないと、起動はするが Bedrock は `No API provider registered for api:
bedrock-converse-stream`、Slack は無反応になる。

```bash
docker compose exec openclaw openclaw plugins install @openclaw/amazon-bedrock-provider
```

```bash
docker compose exec openclaw openclaw plugins install @openclaw/slack
```

インストール先は `~/.openclaw/npm/` 配下 (バインドマウント下) なので永続する。

> [!IMPORTANT]
> インストーラは `openclaw.json` を書き換えようとするが、コメントごと消える
> 縮小になるため OpenClaw 自身の安全機構に弾かれる (`Config write rejected:
> size-drop`)。**これは想定どおり**で、`plugins.entries` と `plugins.allow` は
> リポジトリ側の設定ファイルに既に書いてある。

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

その後ブラウザで <http://127.0.0.1:18789/>。接続には `.env` の
`OPENCLAW_GATEWAY_TOKEN` を Gateway Token 欄に貼る。値は VM 上で確認する。

```bash
docker exec openclaw printenv OPENCLAW_GATEWAY_TOKEN
```

> [!IMPORTANT]
> **`openclaw dashboard --no-open` はトークン入り URL を出さない。**
> コンテナ内にはブラウザもクリップボードもないため「Token auto-auth not
> delivered」で終わる。トークンが未設定に見えるが、実際は `.env` から
> 環境変数で入っている (`openclaw config get gateway` には出ない)。
> `doctor --generate-gateway-token` は不要。
>
> また、ポートフォワード越しだと origin が食い違って `origin not allowed`
> で切られる。`openclaw.json` の `gateway.controlUi.allowedOrigins` で
> 許可済み。

### MCP (channel bridge)

`openclaw mcp serve` で OpenClaw のチャネルを stdio の MCP サーバとして
公開できる。公開ツールは会話系9つ (`conversations_list` `messages_read`
`events_poll` ほか、送信は `messages_send`、承認は `permissions_respond`)。

```bash
docker exec -i openclaw openclaw mcp serve
```

> [!CAUTION]
> **接続時に `operator.approvals` を無条件で要求する。** 読み取り系ツールしか
> 使わない場合でも要求される。デバイスの既定は `operator.read` +
> `operator.write` なので、承認しないと接続できない。
> `devices approve` にスコープを絞るオプションはない。

承認まわりに落とし穴が多い。

- **pending は1デバイス1枠**。後から来た要求で上書きされ、要求スコープは合算される
- `openclaw devices list` **自身が `operator.pairing` を要求する**。確認のつもりで
  打つと、承認したい要求を壊す。状態はホスト側のファイルを直読みする:

  ```bash
  python3 -c 'import json,sys;print(json.load(open("/home/morihaya/openclaw/data/config/devices/pending.json")))'
  ```

- `devices reject` も `operator.pairing` を要するため、CLI では却下もできない
- 承認は Control UI からでもできるが、**ゲートウェイトークンを使えば1行で済む**
  (origin 問題も回避できる)

  ```bash
  docker exec openclaw sh -c 'openclaw devices approve <requestId> --token "$OPENCLAW_GATEWAY_TOKEN"'
  ```

保留要求が残っていても Gateway と Slack エージェントの動作には影響しない。

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
