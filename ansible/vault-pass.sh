#!/usr/bin/env bash
#
# Ansible Vault のパスワードを 1Password から取り出す client script。
#
# 旧 inventories/hosts はパスワードを紛失して復号不能になった。同じことを
# 繰り返さないよう、パスワードは手元に置かず 1Password から都度読み出す。
#
# 【使い方】
#   ANSIBLE_VAULT_PASSWORD_FILE=./vault-pass.sh ansible-playbook play-main.yml
#
# 【ansible.cfg に設定していない理由】
#   vault_password_file に指定すると、1Password にサインインしていない環境で
#   暗号化ファイルを使わない実行まで巻き添えで失敗するため、明示的に
#   環境変数で渡す運用にしている。
#
# 【事前準備】1Password に item を作る
#   op item create --category=password --title=morihaya-infra-ansible-vault \
#     --vault=Private 'password=<生成したパスワード>'
#
set -euo pipefail

if ! command -v op >/dev/null 2>&1; then
	echo "vault-pass.sh: 1Password CLI (op) が見つかりません" >&2
	exit 1
fi

exec op read "op://Private/morihaya-infra-ansible-vault/password"
