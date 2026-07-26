# 認証は環境変数 TFE_TOKEN で行う (provider 標準の方式)。
# HCP Terraform 側ではワークスペース morihaya-infra の
# Environment variable として sensitive で設定する。
#
# このトークンは org の owners team 権限が必要で、本リポジトリで使う
# どの認証情報よりも強い。詳細は README.md を参照。
#
# 手元から実行する場合は Terraform CLI config の credentials
# (~/.terraformrc-morihaya) が使われる。
provider "tfe" {
  organization = var.tfe_organization
}
