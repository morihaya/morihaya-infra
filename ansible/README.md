# Ansible

自宅 Proxmox クラスタ `morihaya` の構成管理。

## インベントリ

[inventories/hosts.yml](inventories/hosts.yml) — **平文**の YAML インベントリ。

| グループ | ホスト | 備考 |
|----------|--------|------|
| `proxmox` | pve (.2) / pve2 (.10) / pve3 (.11) | ハイパーバイザ。Debian 13 / PVE 9.1 |
| `containers` | dns01 (.4) / homepage (.8) / gh-runner (.9) | Ansible で管理できる LXC |
| `managed` | 上記 2 グループの親 | `play-main.yml` の対象 |
| `pending` | traefik (.6) / pulse (.5) / hcp-terraform-agent | 未対応。下記参照 |

### `pending` のホストに必要な手当て

| ホスト | 問題 | 対応 |
|--------|------|------|
| traefik | Alpine 3.22 に python3 が無く Ansible モジュールが動かない | `apk add python3` |
| pulse | sshd は稼働中だが root の `authorized_keys` に鍵が無い | 鍵を配置する |
| hcp-terraform-agent | QEMU guest agent が無効で IP 不明 | `qm set 103 --agent enabled=1` + agent 導入 |

済んだら `containers` グループへ移す。

## なぜ平文なのか

旧 `inventories/hosts` は `ansible-vault` で暗号化されていたが、**パスワードを
紛失して復号不能**になったため実機の状態から作り直した (2026-07-26)。

再作成にあたり平文へ切り替えた理由:

- 中身はホスト名と内部 IP のみで、秘匿する価値が無い。`home.morihaya.tech` は
  公開 Route53 ゾーンなので、内部 IP は誰でも `dig` で引ける
- RFC1918 アドレスは経路を持たないため、知られても外部から到達できない
- このリポジトリは公開されている。Ansible Vault 1.1 は PBKDF2-HMAC-SHA256
  10,000 回であり、公開された blob は**時間無制限のオフライン総当たり**に
  さらされる。守る価値の無いものを弱い暗号で公開する意味が無い

## 秘密情報が必要になったら

パスワードを手元に置かず 1Password から都度読み出す。

### 1. 1Password に item を作る

```bash
op item create --category=password --title=morihaya-infra-ansible-vault --vault=Private 'password=<生成したパスワード>'
```

### 2. 秘密だけを別ファイルに分けて暗号化する

インベントリ全体ではなく `group_vars/all/vault.yml` に秘密変数を集約し、
そのファイルだけを暗号化する。

```bash
ANSIBLE_VAULT_PASSWORD_FILE=./vault-pass.sh ansible-vault create inventories/group_vars/all/vault.yml
```

### 3. 実行時に渡す

```bash
ANSIBLE_VAULT_PASSWORD_FILE=./vault-pass.sh ansible-playbook play-main.yml
```

[vault-pass.sh](vault-pass.sh) は `op read` を実行するだけの client script。
`ansible.cfg` の `vault_password_file` には**あえて設定していない** — 設定すると
1Password にサインインしていない環境で、暗号化ファイルを使わない実行まで
巻き添えで失敗するため。

## ロール

- `common` — ユーザー作成、`authorized_keys` 配置、`.bashrc` のエイリアス

`docker-compose` と `postgres` ロールは削除した。どの play からも参照されておらず、
かつ内容が現環境と合っていなかったため (compose のバージョンが実在しない `5.3.1`、
postgres が `postgresql-server` など RHEL 系のパッケージ名を指定していたが対象は
Debian / Alpine)。必要になったら履歴から復元して作り直すこと。

> [!NOTE]
> `group_vars/all.yml` の管理者グループも同じ理由で `wheel` から `sudo` へ修正した。
> `wheel` は RHEL 系のグループ名で、対象ホストには存在しない。

## 実行

`ansible` 自体は未インストールなので `uv` で一時的に呼ぶ。

### 疎通確認

`play-ping.yml` と `play-debug.yml` は診断用なので、あえて `pending` を含む
`all` を対象にしている。**`pending` の 3 台が失敗するのが正常**で、それが
「まだ手当てが済んでいない」ことの表示になる。

```bash
uvx --from ansible-core ansible-playbook play-ping.yml
```

2026-07-26 時点の期待される結果:

```text
dns01       : ok=1  ...  failed=0
gh-runner   : ok=1  ...  failed=0
homepage    : ok=1  ...  failed=0
pve         : ok=1  ...  failed=0
pve2        : ok=1  ...  failed=0
pve3        : ok=1  ...  failed=0
traefik     : ok=0  ...  failed=1      <- python3 が無い
pulse       : ok=0  ...  unreachable=1 <- 鍵が無い
hcp-terraform-agent : unreachable=1    <- IP 未確定
```

### 構成適用

`play-main.yml` は実際に変更を加えるため `managed` のみを対象にする。

```bash
uvx --from ansible-core ansible-playbook play-main.yml
```

> [!WARNING]
> `common` ロールは対象ホスト全てに `morihaya` ユーザーを作り `sudo` グループへ
> 入れる。2026-07-26 時点でどのホストにもこのユーザーは存在しないため、
> 初回実行は **6 台すべてで変更が入る**。
>
> また `authorized_key` は `exclusive: true` なので、そのユーザーの
> `authorized_keys` は [roles/common/keys/authorized_keys.morihaya](roles/common/keys/authorized_keys.morihaya)
> の内容で**丸ごと置き換わる**。

> [!NOTE]
> **`--check` は初回実行前だと必ず失敗する。** `ansible.posix.authorized_key` は
> チェックモードでユーザーが存在しないとホームディレクトリを解決できず
> `Either user must exist or you must provide full path to key file in check mode`
> になるため。モジュール側の制約であり設定の誤りではない。実行時は
> 「ユーザー作成 → 鍵配置」の順で進むので問題ない。
>
> ユーザー作成後は `--check --diff` が正常に使える。
