# 認証トークンはワークスペース変数 TFE_TOKEN から受け取る。
# このトークンは org の owners team のものが必要で、本リポジトリで使う
# どの認証情報よりも強い。詳細は README.md を参照。
#
# 空の場合は null を渡し、provider 標準の探索
# (環境変数 TFE_TOKEN → Terraform CLI config の credentials) に委ねる。
# 手元から実行する場合は ~/.terraformrc-morihaya がこれで使われる。
provider "tfe" {
  organization = var.tfe_organization
  token        = var.TFE_TOKEN != "" ? var.TFE_TOKEN : null
}
