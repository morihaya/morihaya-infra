# OpenClaw 自宅執事エージェント構築 — 引き継ぎ計画書

- 作成: 2026-07-29(Claude Fable 5 セッションからの引き継ぎ用)
- 目的: Proxmox 環境に OpenClaw を導入し、家族用 Slack に常駐する執事型 AI エージェントを構築する
- 状態: **設計・AWS 側 Terraform 実装まで完了(未コミット)**。以降の作業をこのドキュメントに従って進める

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
1. ブランチを切り、上記変更をコミット・push・PR(コミット規約: `feat(aws): ...` 形式・日本語、直近の git log 参照)
2. HCP Terraform の run を **confirm まで**確認(過去に confirm 忘れでワークスペースが長期ロックされた事故あり)
3. apply 後、コンソールか `aws iam create-access-key --user-name openclaw-butler` でアクセスキー発行
4. Bedrock コンソール(ap-northeast-1)で Anthropic モデルの Model access を有効化(忘れると 403)

### Phase 2: VM 構築(Proxmox)
1. Debian 12 VM(4vCPU/8GB/40GB〜)を作成。既存の ZFS + pvesr レプリケーション対象に載せる(HA 設計は別途メモリ/ドキュメント参照)
2. Docker Engine + Compose v2 導入
3. FW/VLAN: outbound のみ許可。NAS・Proxmox 管理面への到達は遮断。inbound は全閉じ(Socket Mode のため不要)

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
3. セキュリティ強化: サンドボックス有効化、ツール許可リスト、Slack 側は家族のユーザー ID allowlist、ClawHub スキルは導入前にソースを読む
4. 初回課金発生後、Cost Explorer で実際の Service 名を確認(Anthropic モデルは Marketplace 経由請求のため「... (Amazon Bedrock Edition)」等の別名になる可能性)。異なる場合は `budgets.tf` の `cost_filter` に追記

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
