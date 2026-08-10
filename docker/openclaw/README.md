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
| 外部ツール | Google カレンダー (MCP / **読み取り専用**) |
| デプロイ先 | `~/openclaw/` |

VM そのものは Terraform 管理 ([terraform/homelab/106vm_openclaw.tf](../../terraform/homelab/106vm_openclaw.tf))。

同じ VM には StackChan 用の MCP ブリッジも同居している
([docs/stackchan-mcp-bridge.md](../../docs/stackchan-mcp-bridge.md))。

## ディレクトリ構成

```
~/openclaw/                    # VM 106 上
├── compose.yaml               # このリポジトリから配布
├── google-calendar-mcp/       # このリポジトリから配布 (Dockerfile)
├── .env                       # 秘密情報 (git 管理外・手で作る)
├── gcp-oauth.keys.json        # 秘密情報 (git 管理外・手で置く)
└── data/
    ├── config/                # /home/node/.openclaw
    │   ├── openclaw.json      # このリポジトリから配布
    │   └── workspace/         # メモリ・自宅情報
    ├── gcal/                  # カレンダー MCP の OAuth トークン
    └── secrets/               # /home/node/.config/openclaw
```

## セットアップ

### 1. 資材を配る

```bash
scp -r compose.yaml google-calendar-mcp morihaya@192.168.1.12:~/openclaw/
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

## Google カレンダー連携 (MCP)

[`@cocal/google-calendar-mcp`](https://github.com/nspady/google-calendar-mcp) を
**別コンテナ**で動かし、OpenClaw から `streamable-http` の MCP サーバとして参照する。
`ports` は publish せず、compose の内部ネットワークからのみ到達させる。

別コンテナにしているのは隔離のため。エージェントはシェルを持つので、同じコンテナに
OAuth トークンを置くとエージェント自身 (= プロンプトインジェクションの経路) から
ファイルとして読める。

### 読み取り専用をどこで担保しているか

> [!IMPORTANT]
> **このサーバは OAuth スコープを `.../auth/calendar` (読み書き) にハードコードしており、
> readonly スコープを選べない。** そのため 3 層で担保している。

| 層 | 手段 | 効果 |
|---|---|---|
| Google の ACL | 執事用アカウントへ**閲覧権限だけ**で共有 | トークンが漏れても書けない。これが本丸 |
| MCP サーバ | compose の `ENABLED_TOOLS` | 書き込みツールが登録されない |
| OpenClaw | `openclaw.json` の `toolFilter.include` | 二重の網 |

書き込みを許したくなったら、まず Google 側で対象カレンダーだけを「変更権限」に上げ、
それから上の 2 つに書き込みツールを足す。順番を逆にしない。

### 1. Google 側の準備

1. **執事用の Google アカウントを 1 つ作る。** 自分の本アカウントは使わない
   (トークンが自分の全カレンダーへの書き込み権を持ってしまうため)
2. 自分と家族のカレンダーを、そのアカウントへ
   **「予定の表示 (すべての予定の詳細)」** で共有する。「変更権限」にはしない
3. GCP プロジェクトを作り、**Google Calendar API を有効化**する
4. OAuth 同意画面: User type は外部、テストユーザーに執事アカウントを追加

> [!CAUTION]
> **公開ステータスを「本番」に昇格させること。** テストモードのままだと
> リフレッシュトークンが **7 日で失効**し、常駐エージェントとしては使えない。
> 未確認アプリの警告は出るが、自分しか使わないので実害はない。

5. OAuth クライアント ID を **「デスクトップアプリ」型**で作成する。
   Web アプリ型だと loopback リダイレクトが通らない
6. ダウンロードした JSON を VM 上へ置く。**この作業は手で行う**
   (`client_secret` を含むためリポジトリにも会話にも残さない)

```bash
chmod 600 ~/openclaw/gcp-oauth.keys.json
```

### 2. 置き場を先に作ってからビルド

> [!WARNING]
> **`gcp-oauth.keys.json` を置く前に `up` しないこと。** bind mount の元が無いと
> Docker が**同名のディレクトリを勝手に作り**、`Is a directory` ではなく
> 「認証情報が読めない」系の分かりにくいエラーになる。
>
> 同じ理由で、トークンの置き場は**先に自分で掘っておく**。Docker に作らせると
> root 所有になり、コンテナ内の node ユーザ (uid 1000) が書き込めない。

```bash
mkdir -p ~/openclaw/data/gcal && ls -l ~/openclaw/gcp-oauth.keys.json
```

```bash
cd ~/openclaw && docker compose build google-calendar-mcp
```

### 3. 一度きりの OAuth

認証サーバはポート **3500-3505** を使い、リダイレクト URI は
`http://localhost:3500/oauth2callback` になる。VM にブラウザはないので手元から掘る。

```bash
ssh -L 3500:127.0.0.1:3500 morihaya@192.168.1.12
```

その SSH セッションの中で:

```bash
cd ~/openclaw && docker compose run --rm -p 127.0.0.1:3500:3500 google-calendar-mcp google-calendar-mcp auth
```

標準エラーに出る URL を手元のブラウザで開き、**執事アカウントで**承認する。
トークンは `~/openclaw/data/gcal/tokens.json` に落ちて永続する。

> [!TIP]
> HTTP モードの `/accounts` 画面からも認証できる作りだが、リダイレクト URI を
> 設定値の host から組み立てるため、`HOST=0.0.0.0` だと
> `http://0.0.0.0:3000/oauth2callback` になって Google に弾かれる。CLI の
> `auth` を使うこと。

### 4. 起動と確認

```bash
cd ~/openclaw && docker compose up -d google-calendar-mcp && docker compose restart openclaw
```

サーバ単体の疎通:

```bash
docker compose exec openclaw curl -s http://google-calendar-mcp:3000/health
```

OpenClaw から見えているか。**読み取り 7 つだけ**が並び、`create-event` や
`delete-event` が出ていないことを確認する。

```bash
docker compose exec openclaw openclaw mcp status --verbose
```

### 落とし穴

- **エンドポイントのパスを `/` にしない。** このサーバは `GET /` をアカウント管理 UI に
  横取りしており、streamable-http の SSE ストリームと衝突する。`/mcp` を使う
  (既知ルート以外は MCP トランスポートへフォールスルーする)
- **`Origin` ヘッダ検査**がある。localhost 以外の origin は 403 になる。
  OpenClaw 側は Origin を送らないので通るが、403 が出たらここを疑う
- **予定のタイトルと説明は外部入力**になる。招待経由で第三者が書き込める欄なので、
  プロンプトインジェクションの面が一段広がる
- **予定一覧はトークンを食う。** cron で朝のブリーフィングを回すなら期間を絞る

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

### サブスク更新の通知 (cron)

サブスクの更新日が近づいたら Slack の `#general` へ `@channel` で流し、継続するか
判断させる。**判定は LLM にやらせない。** 家庭情報リポジトリ (private:
`morihaya-homeinfo`) の `scripts/renewal_notify.py` が日付を計算し、cron は
`--command` でそれを実行して標準出力をそのまま流すだけにしてある。

| 区分 | 通知タイミング |
|---|---|
| 年払い | 次回更新日の **7日前から当日まで毎日**。ただし**リアクションが付いたら打ち切る** |
| 月払い | 月額 ¥3,000 以上のものだけ、課金の **3日前に1回** |

該当が無い日はスクリプトが**何も出力しない**。空振りの日に投稿しないのは
この「出力が空」に依存している。空出力は `command ok with no output` として
扱われ `deliveryStatus: not-delivered` になる (投稿に失敗しているのではなく、
そもそも投げていない)。`--announce` の挙動を変えるときはここを確認すること。

### 気づいた後に鳴り続けさせない

年払いを毎日鳴らすのは判断を促すためだが、気づいた後も鳴るのは鬱陶しい。
通知に**リアクションかスレッド返信**が付いたら、その件は以後鳴らさない。

判定はスクリプトが Slack の `conversations.history` を読み、同じサービス名と
同じ更新日に触れている過去の投稿を探す方式。投稿自体は `--announce` に任せた
ままなので、メッセージ ts を持ち回る必要がない。

そのため cron の `--command` に `--slack-channel <general-channel-id>` を渡す。
トークンは `SLACK_BOT_TOKEN` をそのまま読む (コンテナの env に入っており、
`--command` は `sh -lc` で実行されるので見える)。**秘密情報の置き場は増えない。**

> [!IMPORTANT]
> **Slack が読めないときは通知する側に倒してある。** API エラー、スコープ不足、
> Bot 未参加はいずれも「未反応」扱いになり、通知は止まらない。黙って握り潰して
> 見落とすより鳴らしすぎるほうがマシという判断。理由は標準エラーに出るので
> `cron runs` で追える (標準出力に混ぜると Slack へ流れてしまう)。

スクリプトは `openclaw-homeinfo-sync.timer` (15分ごと) が同期しているクローンを
見るので、リポジトリへ push すれば反映される。VM 側に置くファイルは無い。

> [!IMPORTANT]
> **Bot が `#general` に参加していないとイベントも配信も届かない。**
> Slack 側で `/invite` しておく。`openclaw.json` の `channels` に ID がある
> だけでは足りない (許可と参加は別)。

登録は一度だけ。`<general-channel-id>` は VM 上の `openclaw.json` から引く
(このリポジトリは Public なのでチャンネル ID は置かない)。

```bash
docker exec openclaw openclaw cron add --name "subscription-renewal-notice" --cron "0 9 * * *" --tz "Asia/Tokyo" --command "python3 /home/node/.openclaw/workspace/home/scripts/renewal_notify.py --slack-channel <general-channel-id>" --announce --channel slack --to "channel:<general-channel-id>" --best-effort-deliver --exact
```

チャンネル ID が2回出てくるのは役割が違うため。`--to` は**投稿先**、
`--slack-channel` は**リアクションを探しに行く先**。同じ値になる。

`--exact` を付けているのは、既定では毎時ちょうどのジョブに最大5分のスタッガーが
入るため。通知が9時ちょうどに来ないと気持ち悪いだけで、実害は無い。

動作確認は日付を指定して手元で回すのが早い (Slack へは飛ばない)。

```bash
docker exec openclaw python3 /home/node/.openclaw/workspace/home/scripts/renewal_notify.py --today 2026-11-13
```

登録後の確認と手動実行。**`cron run` は実際に Slack へ投稿する**ので、
試すなら `--to` を test チャンネルにしたジョブを別に作ること。

```bash
docker exec openclaw openclaw cron list
```

> [!CAUTION]
> **`cron add` は初回に Gateway のスコープ昇格を要求する。** 承認しないと
> `pairing required: device is asking for more scopes than currently approved`
> で失敗する。上の「MCP (channel bridge)」節と同じ手順で承認する。

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
- **カレンダーの読み取り専用は Google の共有権限で担保している。** ツール絞り込みは
  あくまで補助。執事用アカウントを「変更権限」に上げる操作は、書き込みを本当に
  許すと決めたときだけ行う
