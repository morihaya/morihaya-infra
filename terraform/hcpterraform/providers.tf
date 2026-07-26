# 認証は HCP Terraform ワークスペースの環境変数 TFE_TOKEN で行う。
# このトークンは org の owners team のものが必要で、本リポジトリで使う
# どの認証情報よりも強い。詳細は README.md を参照。
provider "tfe" {
  organization = var.tfe_organization
}
