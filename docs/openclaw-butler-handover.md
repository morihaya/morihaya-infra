# OpenClaw 自宅執事エージェント構築 — 引き継ぎ計画書

- 作成: 2026-07-29(Claude Fable 5 セッションからの引き継ぎ用)
- 更新: 2026-07-30(Phase 1 マージ済み、Phase 2 の VM コード化まで完了)
- 目的: Proxmox 環境に OpenClaw を導入し、家族用 Slack に常駐する執事型 AI エージェントを構築する
- 状態: **Phase 1-3 は完了 (VM 106 稼働中・Slack 常駐中)。Phase 4 と 5 が進行中**
- 更新: 2026-08-09(Phase 5 として Google カレンダー連携を追加)

> [!NOTE]
> **この文書は Phase 2 でつまずいていた頃の記述が多く残っている。**
> 以降の「起動しない」系の記述は解決済みの記録として読むこと。
> 現状の構成と運用手順は [docker/openclaw/README.md](../docker/openclaw/README.md) が正。

## 0. 現在の進捗

| Phase | 状態 | 補足 |
|---|---|---|
| 1. AWS 土台 | **#84 マージ・apply 済み** | IAM ユーザ `openclaw-butler` と予算が存在するはず。アクセスキー発行と Model access 有効化は未確認 |
| 2. VM 構築 | **apply 済みだが VM が起動しない** | #85 → #86 → #87 と修正を重ねて apply は通った。ただし起動時にカーネルパニック(下記)。シリアルコンソール追加で修正中 |
| 3. OpenClaw セットアップ | 未着手 | VM が SSH 可能になってから |
| 4. 執事化・運用 | 未着手 | |

> [!CAUTION]
> **VM 106 は起動に失敗している(2026-07-31 診断)。**
>
> apply 自体は成功し `qm status 106` は `running` だが、ゲストがネットワークへ
> **1 パケットも出さない**(`ip -s link show tap106i0` の RX が 0)。
> コンソールを screendump したところ次のパニックで停止していた。
>
> ```
> Kernel panic - not syncing: Attempted to kill init! exitcode=0x00000200
> ```
>
> 原因は **シリアルコンソール未定義**。Debian の cloud image は
> `console=tty0 console=ttyS0,115200 ...` をカーネルに渡しており、最後の
> `console=` が `/dev/console` になる。Proxmox の VM は既定でシリアルポートを
> 持たないため、PID 1 の書き込みが失敗して systemd が即死していた
> (パニック直前のスタックが `ksys_write` なのと一致)。
>
> `serial_device { device = "socket" }` を足して修正。
> cloud-init はこの起動失敗により**一度も走っていない**ので、
> 修正後の初回起動でネットワーク設定と SSH 鍵が投入される。

> [!NOTE]
> Phase 1 と Phase 2 は当初 1 つの PR にまとめていたが、#84 が AWS 分だけの
> 状態でマージされたため、Phase 2 は別ブランチの PR に切り出した。
> ワークスペースが別 (`aws-root` / `homelab`) なので分けるほうが plan も読みやすい。

### Phase 2 で確定した仕様(2026-07-30 にユーザー判断)

当初案の 4vCPU/8GB は**クラスタの物理メモリに収まらない**ことが判明したため見直した。
`pve` は既に約 8.3GB/16GB 使用済み、`pve3` は 8GB しかない。OpenClaw の推論は
すべて Bedrock 側なのでローカル資源はほぼ不要で、8GB は「ブラウザ自動化を使う場合」の数字。

| 項目 | 決定 |
|---|---|
| スペック | **2vCPU / 4GB / 40GB**(ブラウザ自動化なし前提) |
| 配置ノード | **pve3**(105 のみで最も空きがある) |
| 作成方法 | **Terraform で新規作成**(Debian 12 genericcloud + cloud-init) |
| IP | **192.168.1.12/24** 固定 |
| HA | primary `pve3` / standby **`pve`**(pve2 は 104+105 の standby 兼任で容量不足) |

## 1. 決定事項とその理由

| 決定 | 理由 |
|---|---|
| モデルは **Amazon Bedrock (ap-northeast-1) に統一** | ユーザーが Bedrock を触りたい意向。請求・IAM・監査の一本化、学習利用なし、Guardrails 利用可 |
| デフォルト **Claude Haiku 4.5** / エスカレーション **Sonnet**(Slack の `/model` で切替) | 執事用途はほぼ Haiku で足りる。月額目安は千円台(予算: 数千円まで) |
| Slack は **Socket Mode** | inbound ポート公開不要。自宅 NW と相性が良い |
| 専用 **Debian 12 VM**(4vCPU/8GB/40GB〜)+ Docker Compose | LXC ではなく VM。エージェントがシェルを持つため隔離を優先 |

### 却下済みの選択肢(再提案しないこと)

- **Gemini API 無料枠**: 無料枠は入出力が Google のモデル学習に利用される(自宅情報を扱う用途に不適)。Pro モデルは 2026-04 に無料枠から削除済み
- **Google AI Pro サブスクの流用**(gemini-cli OAuth): 非公式統合であり、2026 年初頭にアカウント BAN 事例あり
- **Claude Pro / ChatGPT Plus のサブスク流用**: Anthropic は方針が不安定(2026-02 禁止 → 2026-04 適用 → その後容認)。ChatGPT Plus のみ公式許可だが Bedrock 統一を優先して不採用
- **Azure AI Foundry**: プラグイン経由で可能だがデプロイメント管理の摩擦が大きい。今回は出番なし

## 2. 完了済みの作業

`terraform/aws/root`(HCP Terraform workspace: `morihaya-infra-aws-root`)に以下を追加済み。**`terraform fmt` / `validate` 通過済み、未コミット**。

- `iam_openclaw.tf`(新規): IAM ユーザー `openclaw-butler` + インラインポリシー `BedrockInvokeMinimal`
  - Invoke 系は Anthropic foundation-model と自アカウント inference-profile に限定(`apac.*` クロスリージョンプロファイル対応)
  - `bedrockDiscovery` 用の List/Get 権限
  - **アクセスキーは意図的に Terraform 管理外**(HCP の state に平文で残るため)。apply 後に手動発行する
- `budgets.tf`(追記): バジェット `OpenClaw Bedrock` 月 $15、`Service = Amazon Bedrock` フィルタ、ACTUAL 50/80/100% + FORECASTED 100%、既存 SNS トピック `budgets` とメール通知を流用
- `README.md`: Managed リストに IAM を追記

## 3. 残作業(推奨順)

### Phase 1: AWS 土台の反映
1. ~~ブランチを切り、上記変更をコミット・push・PR~~ → **完了。#84 としてマージ済み**
2. **[要対応] main の run を Confirm & Apply する**。plan は `3 added, 0 changed, 0 destroyed` で意図どおり。auto-apply は無効なので UI 操作が必須(過去に confirm 忘れでワークスペースが長期ロックされた事故あり)
3. **[要対応] アクセスキーを発行する**。この Mac に AWS の認証情報が無いため CLI からは実行できない。コンソールか `aws iam create-access-key --user-name openclaw-butler`
4. **[要対応] Bedrock コンソール(ap-northeast-1)で Anthropic モデルの Model access を有効化**(忘れると 403)

### Phase 2: VM 構築(Proxmox)

コードは実装済み(`terraform/homelab/106vm_openclaw.tf` + `ha.tf` の VM 対応)。残りは以下。

1. **apply 前に `192.168.1.12` が空いていることを確認する**。既存ゲストは .4/.5/.6/.8/.9 を使用し .7 は用途不明のため .12 を選定した。AdGuard Home(LXC 100)の DHCP プール範囲外であることも併せて確認し、必要なら予約する
2. homelab ワークスペースの apply を実行(HCP Agent 実行 = VM 103 経由)
3. cloud image は初回 apply 時に専用の `image-import` ストレージ(pve3 の `/var/lib/pve-image-import`)へダウンロードされる。ディレクトリごと Terraform が作るので事前準備は不要

> [!WARNING]
> **1 回目の apply は失敗している(2026-07-30)。** cloud image を `local` に
> `iso` タイプで置いていたため、ディスクの `import_from` が次のエラーで拒否された。
>
> ```
> scsi0: local:iso/debian-12-genericcloud-amd64.img has wrong type 'iso'
> - needs to be 'images' or 'import'
> ```
>
> 専用の `import` タイプストレージを新設して修正済み。併せて、Terraform が
> 同じ apply 内で作るゲストに対してレプリケーションジョブが並行実行される
> 順序の問題も `depends_on` で直した(詳細は
> [terraform/homelab/README.md](../terraform/homelab/README.md) の約束ごと)。
>
> VM・レプリケーションジョブ `106-0`・HA リソース `vm:106` は state に無い
> (修正 PR の plan で add 側だったため)。VM 作成が最初に失敗したため
> 後続は作られていない。

> [!CAUTION]
> **2 回目の apply も失敗した(2026-07-30)。旧 cloud image の削除だけは
> 人間が手を動かす必要がある。**
>
> ```
> Error: Error deleting datastore file
> Could not delete datastore file 'local:iso/debian-12-genericcloud-amd64.img'
> ... received an HTTP 400 response - Reason: Bad Request
> ```
>
> `local` → `image-import` への移動は Terraform 上「置き換え」になるが、その
> destroy が PVE 側で拒否される。PVE は content_type ごとにファイル名と拡張子を
> 検証しており、`iso` 配下の `.img` は削除 API でも弾かれる。
> **API 経由では消せないので Terraform には忘れさせるしかない。**
>
> コード側は `removed` ブロック(`destroy = false`)+ リソース名変更
> (`debian12_genericcloud` → `debian12_import`)で対処済み。
> 残りは以下を pve3 上で手動実行する。
>
> ```bash
> ssh root@192.168.1.11 'ls -la /var/lib/vz/template/iso/'
> ```
>
> ```bash
> ssh root@192.168.1.11 'rm -i /var/lib/vz/template/iso/debian-12-genericcloud-amd64.img'
> ```
>
> ファイルが既に無い場合もある(その場合 400 の原因は「存在しないファイルの
> 削除」側)。どちらでも `removed` ブロックで apply は進む。
> state から外れたことを確認したら `removed` ブロックは削除してよい。
4. VM 起動後 SSH(`morihaya@192.168.1.12`、鍵は ansible の common ロールと共用)→ Docker Engine + Compose v2 導入
5. `qemu-guest-agent` を導入(cloud image に同梱されていないため、入れてから `agent` ブロックを有効化する)。ansible の common ロール適用も併せて行う
6. FW/VLAN: outbound のみ許可。NAS・Proxmox 管理面への到達は遮断。inbound は全閉じ(Socket Mode のため不要)

### Phase 3: OpenClaw セットアップ
1. 公式 docker-compose で起動、`.env` に `AWS_REGION=ap-northeast-1` とアクセスキー
2. モデル設定(モデル ID は自動発見の結果に合わせて要調整):

```json5
{
  agents: {
    defaults: {
      model: { primary: "amazon-bedrock/apac.anthropic.claude-haiku-4-5-20251001-v1:0" },
    },
  },
  models: {
    bedrockDiscovery: { enabled: true, region: "ap-northeast-1" },
  },
}
```

3. Slack アプリ作成: Socket Mode 有効化、App Token(`xapp-`、`connections:write`)+ Bot Token(`xoxb-`)発行、イベント購読(`app_mention`, `message.im` など公式ドキュメント参照)、App Home の Messages Tab 有効化
4. 動作確認: DM 応答 → `/model` で Sonnet 切替 → チャンネルでのメンション応答

### Phase 4: 執事化・運用
1. 自宅情報(ゴミ出し日、家族の予定ルール等)をワークスペースファイル/メモリに投入
2. cron/heartbeat で定時通知(朝のブリーフィング等)。**heartbeat も Bedrock 呼び出しを消費する**ので頻度に注意
   - **サブスク更新の通知は実装済み**(2026-08-10)。毎日 9:00 JST に `#general` へ。
     判定は家庭情報リポジトリのスクリプトが行い、cron は `--command` でそれを
     実行するだけなので **Bedrock を一切消費しない**。定時通知を足すときは、
     エージェントに考えさせる必要が本当にあるか先に検討する。
     手順は [docker/openclaw/README.md](../docker/openclaw/README.md#サブスク更新の通知-cron)
3. セキュリティ強化: サンドボックス有効化、ツール許可リスト、Slack 側は家族のユーザー ID allowlist、ClawHub スキルは導入前にソースを読む
4. 初回課金発生後、Cost Explorer で実際の Service 名を確認(Anthropic モデルは Marketplace 経由請求のため「... (Amazon Bedrock Edition)」等の別名になる可能性)。異なる場合は `budgets.tf` の `cost_filter` に追記

### Phase 5: Google カレンダー連携(2026-08-09 着手)

`@cocal/google-calendar-mcp` を **stdio** で繋ぐ(OpenClaw が子プロセスとして起動)。
**まず読み取り専用**で入れて、運用が安定してから書き込みを検討する。

手順とハマりどころは [docker/openclaw/README.md](../docker/openclaw/README.md#google-カレンダー連携-mcp) に集約した。
設計判断だけここに残す。

| 判断 | 理由 |
|---|---|
| マネージド MCP (Composio 等) は不採用 | 家族の予定が第三者を経由する。Gemini 無料枠を却下したのと同じ筋 |
| **stdio** で繋ぐ(2026-08-12 に別コンテナ + HTTP から変更) | 隔離を狙って別コンテナ + `streamable-http` にしたが、上流の HTTP モードが MCP SDK と噛み合っておらず**どう調整しても壊れた**(下記)。バンドルへのパッチでは届かない範囲だったため、上流が想定する stdio に倒した |
| トークンがエージェントから読めることを**許容**する | stdio では認証情報が openclaw コンテナ側に載る。ただし Google 側で閲覧権限しか渡していないので、漏れても「既に読めるカレンダーを読める」だけで書き込みは ACL で不可。**変更権限へ上げるならこの前提が崩れる** |
| 本アカウントではなく**カレンダーが空のアカウント**で認可し、閲覧権限だけで共有 | このサーバは OAuth スコープが読み書き固定で readonly を選べない。本当の読み取り専用は Google の ACL 側でしか作れない。ただし primary カレンダーだけは共有権限で下げられないので、空のアカウントである必要がある |
| 専用アカウントを新設せず、**Android 開発用アカウントを流用**(2026-08-11 判断) | 条件 (カレンダーが空) を満たすうえに、普段ログインしている。専用に作ったアカウントは 2 年無操作の削除対象になり、トークン更新が「利用」と数えられる保証がないため、静かに死ぬ経路になる |
| **GCP プロジェクトは新規**に作る | OAuth 同意画面はプロジェクト単位で共有される。Android アプリのプロジェクトに相乗りすると、公開中のアプリと同じ同意画面に機微スコープが混ざり審査要件に波及しうる |
| パッケージは `~/.openclaw/vendor` へ npm で入れる | バインドマウント配下なので、イメージを pull し直しても消えない |

> [!CAUTION]
> **同意画面をテストモードのままにしないこと。** リフレッシュトークンが 7 日で失効し、
> 常駐エージェントとして機能しなくなる。「本番」へ昇格させる。

#### HTTP モードを捨てた経緯(再挑戦しないこと)

上流の HTTP モードは `connect()` で `StreamableHTTPServerTransport` を **1 個だけ作って
全リクエストで使い回している**。MCP SDK がステートレスで要求する「1 リクエスト =
1 transport」と噛み合っていない。一方 OpenClaw は MCP ランタイムをキャッシュして常駐
接続を張り、`initialize` は 1 回しか行わない。**この 2 つは両立しない。**

| 寄せ方 | 結果 |
|---|---|
| transport を毎回作り直す | OpenClaw のセッションが切れ、**1 回目は成功するのに 2 回目以降が必ず `MCP error -32001: Request timed out`** |
| 作り直さない(上流のまま) | SDK が**本文なしの 500**。アプリの catch は発火せずログにも出ず、`/health` は 200 のまま |

どちらも気づきにくい。サーバ単体に curl を投げると 200 が返るため、切り分けを誤りやすい
(実際 Node のバージョン差を疑って一度回り道した。無関係だった)。

SDK 自身が `use a separate Protocol instance per connection` と言っており、正しい修正は
上流が「リクエストごとに Server ごと作る」形にすること。ツール登録からやり直す話になり、
バンドルへの外科的パッチでは届かない。**stdio ならこの不整合が原理的に起きない。**

## 4. 既知の注意点・ハマりどころ

- **OpenClaw は認証情報を平文保存する** → IAM 最小権限 + Budget アラートが防御線。キーは定期ローテーション
- **`apac.*` プロファイルは APAC 内他リージョンへルーティングされうる**(学習利用なしは不変)。厳密な東京域内完結が必要なら ap-northeast-1 単発提供のモデルを選ぶ
- **プロンプトインジェクション**: エージェントが読む外部コンテンツ経由で指示注入されうる。永続メモリに汚染が残る点に注意
- HCP Terraform はこの Mac のローカル認証情報が別アカウントのため **state をローカルから読めない**。plan/apply は remote 実行で行う

## 5. 参考リンク

- OpenClaw Bedrock プロバイダ: https://docs.openclaw.ai/providers/bedrock
- OpenClaw Bedrock プラグイン(Guardrails 含む): https://docs.openclaw.ai/plugins/reference/amazon-bedrock
- OpenClaw Slack チャネル: https://docs.openclaw.ai/channels/slack
- OpenClaw セキュリティ関連の外部記事: https://redwerk.com/blog/openclaw-security-best-practices/
