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
**stdio** で繋ぐ。OpenClaw が子プロセスとして起動する。

> [!CAUTION]
> **HTTP モードは使わないこと。別コンテナ + `streamable-http` は一度試して破棄した。**
>
> 上流の HTTP モードは transport を 1 個だけ作って全リクエストで使い回しており、
> MCP SDK がステートレスで要求する「1 リクエスト = 1 transport」と噛み合っていない。
> 一方 OpenClaw は MCP ランタイムをキャッシュして常駐接続を張り、`initialize` は
> 1 回しか行わない。**どちらに寄せても壊れる。**
>
> | 寄せ方 | 結果 |
> |---|---|
> | transport を毎回作り直す | OpenClaw のセッションが切れ、**1 回目は成功するのに 2 回目以降が必ず `Request timed out`** |
> | 作り直さない | SDK が**本文なしの 500**。サーバログには何も出ず、`/health` は 200 のまま |
>
> SDK 自身が `use a separate Protocol instance per connection` と言っており、
> 正しい修正は上流が Server ごとリクエスト単位で作ること。バンドルへのパッチでは
> 届かない範囲なので stdio に切り替えた。経緯は
> [handover の Phase 5](../../docs/openclaw-butler-handover.md) を参照。

パッケージは**永続領域**に入れる。`~/.openclaw/` はバインドマウントなので、
イメージを pull し直しても消えない。

```bash
docker compose exec openclaw npm install --prefix /home/node/.openclaw/vendor @cocal/google-calendar-mcp@2.6.2
```

### 読み取り専用をどこで担保しているか

> [!IMPORTANT]
> **このサーバは OAuth スコープを `.../auth/calendar` (読み書き) にハードコードしており、
> readonly スコープを選べない。** そのため 3 層で担保している。

| 層 | 手段 | 効果 |
|---|---|---|
| Google の ACL | 執事役アカウントへ**閲覧権限だけ**で共有 | トークンが漏れても書けない。**これが本丸** |
| MCP サーバ | `openclaw.json` の `env.ENABLED_TOOLS` | 書き込みツールが登録されない |
| OpenClaw | `openclaw.json` の `toolFilter.include` | 二重の網 |

> [!NOTE]
> **stdio では OAuth トークンがエージェントから読める。** エージェントはシェルを
> 持つので、`/run/secrets/` と `/run/gcal/` のファイルに触れる。これを許容している
> のは、Google 側で閲覧権限しか渡していないから — 漏れても「エージェントが既に
> 読めるカレンダーを読める」だけで、書き込みは ACL で不可。
> **変更権限へ上げるなら、この前提が崩れる点を再検討すること。**

書き込みを許したくなったら、まず Google 側で対象カレンダーだけを「変更権限」に上げ、
それから上の 2 つに書き込みツールを足す。順番を逆にしない。

### 1. Google 側の準備

1. **執事役の Google アカウントを決める。** 条件は 2 つだけ。
   - **そのアカウント自身のカレンダーが空であること。** どのアカウントも自分の
     primary カレンダーには必ず書き込み権を持ち、共有権限では下げられない。
     空でないアカウント (= 自分の本アカウント) を使うと readonly の前提が崩れる
   - **普段ログインしているアカウントであること。** Google は 2 年無操作の
     アカウントを削除対象にする。機械のトークン更新が「利用」と数えられる保証は
     ないので、専用に新規作成したアカウントは静かに消える経路になりうる

   > 現在は Android 開発用アカウント (カレンダー未使用) を流用している。
2. 自分と家族のカレンダーを、そのアカウントへ
   **「予定の表示 (すべての予定の詳細)」** で共有する。「変更権限」にはしない

   > [!IMPORTANT]
   > **共有しただけでは API から見えない。受け取り側での「追加」が要る。**
   > Google は共有時に招待メールを送り、そのリンクを踏んで追加して初めて
   > `calendarList` に載る。共有した側の画面では完了して見えるので気づきにくい。
   >
   > 見えているかは `list-calendars` で確認する。執事自身の primary と
   > 「日本の祝日」しか出てこないなら、まだ追加されていない。
3. **GCP プロジェクトは新規に作り**、**Google Calendar API を有効化**する

   > [!IMPORTANT]
   > **既存プロジェクトに相乗りしない。OAuth 同意画面はプロジェクト単位で共有される。**
   > Android アプリのプロジェクトに載せると、公開中のアプリと同じ同意画面に
   > カレンダーのスコープが混ざる。`auth/calendar` は機微スコープ扱いなので、
   > アプリ側の審査要件に波及しかねない。アカウントは同じでもプロジェクトは分ける。
4. OAuth 同意画面: User type は外部、テストユーザーに執事役アカウントを追加

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

> [!CAUTION]
> **クライアント作成直後のダイアログを閉じると client secret は二度と表示できない。**
> その場でダウンロードすること。閉じてしまったらクライアントを作り直す。

現在の構成 (2026-08-11 時点)。プロジェクト ID とクライアント ID は
このリポジトリが Public のため載せない。コンソール側で確認すること。

| 項目 | 値 |
|---|---|
| GCP プロジェクト名 | `openclaw-butler` (本アカウント所有 / Android アプリのプロジェクトとは別) |
| 同意画面のアプリ名 | `OpenClaw Butler` |
| Publishing status | **In production** (テストのままだとトークンが 7 日で失効するため) |
| OAuth クライアント | Desktop app `openclaw-vm106` |
| 認可するアカウント | Android 開発用アカウント (カレンダー未使用) |

### 2. 置き場を先に作る

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

### 3. 一度きりの OAuth

認証サーバはポート **3500-3505** を使い、リダイレクト URI は
`http://localhost:3500/oauth2callback` になる。VM にブラウザはないので手元から掘る。

```bash
ssh -L 3500:127.0.0.1:3500 morihaya@192.168.1.12
```

その SSH セッションの中で:

```bash
cd ~/openclaw && docker compose exec openclaw /home/node/.openclaw/vendor/node_modules/.bin/google-calendar-mcp auth
```

標準エラーに出る URL を手元のブラウザで開き、**執事役アカウントで**承認する。
トークンは `~/openclaw/data/gcal/tokens.json` に落ちて永続する。

> [!IMPORTANT]
> **承認するアカウントを間違えないこと。** 本アカウントで承認すると、トークンが
> 自分の全カレンダーへの書き込み権を持ってしまい、読み取り専用の前提が崩れる。

### 4. 起動と確認

```bash
cd ~/openclaw && docker compose up -d
```

OpenClaw から見えているか。`stdio tool-filtered` と**読み取り 7 つ**が出ればよい。

```bash
docker compose exec openclaw openclaw mcp status
```

```bash
docker compose exec openclaw openclaw mcp probe google-calendar
```

### 落とし穴

- **`ENABLED_TOOLS` は `manage-accounts` を止められない。** サーバは指定外のこのツールも
  公開してくる (サーバ生では 8 個、`ENABLED_TOOLS` は 7 個)。止めているのは
  `openclaw.json` の `toolFilter.include` のほう。**二重の網が実際に効いている箇所**なので、
  どちらか一方に減らさないこと
- **エージェントは `calendarId: "primary"` を使いたがる。** primary は執事役アカウント
  自身のカレンダーで、常に空。放っておくと「今日は予定がありません」と自信を持って
  答える。どのカレンダーを見るかは workspace の `TOOLS.md` に書いてある
  (家庭の情報なのでこのリポジトリには入れない)
- **カレンダーは共有しただけでは見えない。** 受け取り側が招待メールから追加して初めて
  `calendarList` に載る。`list-calendars` に執事自身の primary と祝日しか出てこない
  なら、まだ追加されていない
- **執事役アカウントのカレンダーのタイムゾーンを東京にしておく。** 既定は UTC で、
  API の返す時刻も UTC 基準になる。コンテナの `TZ` は別物なので効かない。
  9 時間ずれた回答をする事故につながる
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

### 朝のブリーフィング (cron)

毎朝 9:00 JST に、その日に知っておくべきことを `#general` へ 1 通だけ流す。
実体は家庭情報リポジトリ (private: `morihaya-homeinfo`) の
`scripts/morning_brief.py`。cron は `--command` でこれを実行するだけ。

> [!IMPORTANT]
> **いちばん大事な性質は「何も無い日は一切投稿しない」こと。** 何もない日に鳴る
> 通知は、いずれ全員が無視するようになる。そのため判定は LLM に委ねず、
> スクリプトが機械的に決める。3系統すべてが空なら Slack を叩かずに終了する。
> **Bedrock も一切消費しない。**

インプットは 3 系統。

| 系統 | 取得元 |
|---|---|
| 今日の予定 | Google カレンダー (`--calendar` で指定したものだけ。**祝日は入れない**) |
| サブスクの更新 | `renewal_notify.py` の判定を import して再利用 |
| リマインダ | `workspace/reminders.md` (エージェントが追記、当日以前の行を拾う) |

> [!NOTE]
> **カレンダーは MCP を介さず API を直叩きしている。** MCP はエージェント側の口
> なので、Bedrock を使わない cron からは呼べない。トークンは MCP サーバと同じ
> ファイルを**読むだけ**で書き戻さない (競合させないため)。

#### チャンネルを流さないための2段構え

```
親  : 8/12(水) 予定3件 / サブスク1件      ← 1行。開くか決められる
└─ スレッドに各セクションの詳細
```

親を日付だけにしないのは、それだと開くべきか判断できず「毎回開く」か「一切
開かない」のどちらかに倒れるため。件数を出せば 1 行のまま判断できる。

`@channel` は **要判断の件 (サブスク) がある日だけ**付ける。**Slack のスレッド
返信は通知が飛ばない**ので、人間が決めないと進まない件は親行の側に出す必要がある。
予定やリマインダだけの日は静かに投稿する。

#### 気づいた後に鳴り続けさせない

サブスクは更新日まで毎日鳴る。止めるには**親メッセージに :white_check_mark: を付ける**。

> [!IMPORTANT]
> **合図は ✅ 限定。** 何でもいいリアクションにすると 👀 や 😂 のような何気ない
> 反応で判断が止まってしまう。押し忘れても鳴り続けるだけなので、見落とすより
> 安全な側に倒れる。受け付ける絵文字は `--ack-emoji` で変えられる。
>
> **リアクションは親メッセージに付けること。** スレッド返信側では効かない。

> [!CAUTION]
> **判定は `renewal_notify.py` のものから作り直してある。元のままだと必ず誤爆する。**
>
> 元の実装は `reply_count` も「反応」と見なしていた。ブリーフィングは自分で
> スレッド返信を付けるので、投稿した瞬間に `reply_count >= 1` になり、**初日から
> 「対応済み」と誤判定されて二度と鳴らなくなる。** さらに `conversations.history`
> はスレッド返信を返さないため、明細をスレッドへ移すと本文マッチ自体が効かない。
>
> 現在は **✅ が付いている親だけスレッドを読みに行き、親 + 返信を連結した本文**から
> 該当件を探す。ここを触るときは「Bot 自身のスレッド返信で止まらないこと」を必ず
> 回帰確認すること。

Slack が読めないときは通知する側に倒してある (API エラー・スコープ不足・Bot 未参加は
いずれも「未対応」扱い)。理由は標準エラーに出るので `cron runs` で追える。
また**予期しない例外はチャンネルへ短く投稿する** — 毎朝黙って落ちているのが
いちばん気づけないため。

#### リマインダの置き場

`workspace/reminders.md` に `- YYYY-MM-DD | 本文` の形式で 1 行 1 件。
エージェントへの指示は workspace の `TOOLS.md` に書いてある。

> [!WARNING]
> **`workspace/home/` の下に置いてはいけない。** `openclaw-homeinfo-sync.timer`
> が 15 分ごとに `git reset --hard` + `git clean -fd` するので、エージェントが
> 書いても消える。`workspace` 直下はそれ自体が別の git リポジトリで
> `backup-state.sh` の対象。

#### 登録

登録は一度だけ。チャンネル ID は VM 上の `openclaw.json` から引く
(このリポジトリは Public なので置かない)。

```bash
docker exec openclaw openclaw cron add --name "morning-brief" --cron "0 9 * * *" --tz "Asia/Tokyo" --command "python3 /home/node/.openclaw/workspace/home/scripts/morning_brief.py --slack-channel <general-channel-id> --calendar 林家ファミリー" --announce --channel slack --to "channel:<general-channel-id>" --best-effort-deliver --exact
```

スクリプトが自分で `chat.postMessage` するので、`--announce` 経由では何も流れない
(標準出力は常に空)。それでも `--to` を明示しているのは、既定の `last` だと
`no route, will fail-closed` になるため。`--exact` は既定の最大 5 分のスタッガーを
避けるため。

> [!IMPORTANT]
> **`cron rm` は名前ではなく ID を取る。** `cron list` で ID を引いてから消す。

動作確認は日付を指定した `--dry-run` が早い (Slack へは飛ばない)。

```bash
docker compose exec openclaw python3 /home/node/.openclaw/workspace/home/scripts/morning_brief.py --today 2026-08-15 --calendar 林家ファミリー --dry-run
```

**まず「何も無い日」で試して、出力が空になることを確認する。** これが最優先要件そのもの。

```bash
docker compose exec openclaw openclaw cron list
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
