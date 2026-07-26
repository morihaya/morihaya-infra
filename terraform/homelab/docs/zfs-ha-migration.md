# local-lvm から ZFS への移行と HA 有効化の手順

2026-07-25 に pve (192.168.1.2) が停止し、DNS / DHCP / Traefik が同時に落ちた件の
恒久対策手順。**この手順書の作業はまだ実施していない。**

> [!WARNING]
> Phase 1 以降はストレージを作り直す破壊的作業を含む。必ず Phase 0 の
> バックアップを取得してから着手すること。

## 背景 — なぜ 1 台落ちただけで全部落ちたのか

3 ノードのクラスタは正常に組まれており quorate だったが、以下の 2 点により
HA が機能する状態になっていなかった。

1. **HA 登録されていたゲストが `ct:105` (gh-runner) の 1 つだけだった。**
   dns01 / pulse / traefik / homepage / hcp-terraform-agent は全て pve 上にあり
   HA 未登録。pve の停止 = これらの停止。

2. **共有ストレージもレプリケーションも無い。**
   全ゲストのディスクは各ノードローカルの `local-lvm` (LVM-thin, `shared 0`) に
   あり、`pvesr` のジョブも 0 件。HA は他ノードにディスクが無いゲストを起動
   できないため、仮に全ゲストを HA 登録していても移動できなかった。
   唯一 HA 登録されていた `ct:105` も同じ理由で実際には移動できない。

さらに `ct:102` (traefik) だけ `onboot=0` だったため、pve が復帰した後も
自動起動せず手動起動まで停止したままだった (Terraform 側で修正済み)。

## 方式の選定

| 方式 | 判定 |
|------|------|
| Ceph | **不可**。各ノードのディスクが 1 本のみで OSD 用の空きが無く、pve2 が AMD E1-2500 (2 core) と非力、ネットワークも 1GbE |
| NFS / iSCSI 共有ストレージ | **見送り**。常時稼働の NAS が無い (nasune は録画専用機) |
| ZFS + `pvesr` レプリケーション | **採用**。非同期複製のため最大で複製間隔ぶんのデータ欠損はあるが、追加ハードなしで実現できる唯一の現実解 |

## 現状のストレージ構成

全ノードとも同じ構造 (VG `pve` + thin pool `data`)。

| ノード | ディスク | thin pool `data` | 使用量 | VG 空き |
|--------|----------|------------------|--------|---------|
| pve  | NVMe 477GB | 373GB | 30.0GB (100/101/102/103/104) | 16GB |
| pve2 | SATA SSD 480GB | 344GB | 0 (ゲスト無し) | 16GB |
| pve3 | NVMe 256GB | 152GB | 0.9GB (105) | 16GB |

pve2 が空、pve3 がほぼ空なので **pve2 → pve3 → pve の順**で作り直すのが
最も安全 (ゲストの退避先を先に確保できる)。

## ZFS プールの作り方について

ディスクが 1 本しかなく、既に `p1/p2/p3` で全域が割り当て済みのため、
パーティションを切り直すには稼働中のブートディスクに対する切り直しが必要になる。
リスクが高いので、**thin pool を削除して空いた領域に LV を作り、その上に
zpool を作る**方式を採る。

```
nvme0n1p3 (PV) ── VG pve ─┬─ pve-root  (変更なし)
                          ├─ pve-swap  (変更なし)
                          └─ pve-zfsvol (新規) ── zpool rpool_data
```

LVM を 1 層挟むぶん TRIM の透過などは効かなくなるが、パーティション操作も
Proxmox の再インストールもクラスタの抜き差しも不要で、完全に巻き戻せる。
(より綺麗にやるなら各ノードを ZFS-on-root で再インストールする方法もあるが、
クラスタからの削除と再参加が必要になるため本手順では採らない)

---

## Phase 0 — 事前準備 (非破壊)

### 0-1. バックアップを取る (現状ゼロ)

`/var/lib/vz/dump/` は空で `vzdump` のジョブも未設定。まずここを埋める。

```bash
ssh root@192.168.1.2 'for id in 100 101 102 104; do vzdump $id --storage local --mode snapshot --compress zstd; done'
```

```bash
ssh root@192.168.1.2 'vzdump 103 --storage local --mode stop --compress zstd'
```

`ct:105` は pve3 上にあるので pve3 側で取得する。**取り漏らしやすいので注意**
(2026-07-26 の実施時、pve 側の 5 台は取得されたが pve3 の `ct:105` は
未取得だった)。

```bash
ssh root@192.168.1.11 'vzdump 105 --storage local --mode snapshot --compress zstd'
```

### 0-2. ノード間 SSH の疎通確認

pve から pve2 / pve3 への SSH が host key 未登録で失敗する状態だった。
マイグレーションは SSH を使うため先に解消しておく。

```bash
ssh root@192.168.1.2 'for h in 192.168.1.10 192.168.1.11; do ssh-keyscan -H $h >> ~/.ssh/known_hosts; done && pvecm updatecerts'
```

### 0-3. VM 103 (HCP Terraform Agent) の扱いを決める

103 には `local:iso/ubuntu-24.04.3-live-server-amd64.iso` が刺さったままで、
この ISO は pve にしか存在しないためマイグレーションできない。
インストールは完了しているので CD-ROM を外す。

```bash
ssh root@192.168.1.2 'qm set 103 --delete ide2 && qm set 103 --boot order=scsi0'
```

> [!WARNING]
> **VM が起動中だとこの変更は `[PENDING]` に入り、即時反映されない。**
> `/etc/pve/qemu-server/103.conf` の末尾に次のセクションが付く。
>
> ```
> [PENDING]
> boot: order=scsi0
> delete: ide2
> ```
>
> 反映には VM の停止・起動が必要 (ゲスト OS 内からの再起動では不十分)。
> **保留のままだと稼働中の VM には ISO が刺さったままなので、
> マイグレーションできず Phase 0-3 の目的を達成できない。**
>
> ```bash
> ssh root@192.168.1.2 'qm stop 103 && qm start 103'
> ```
>
> 停止中は HCP Terraform の Agent も止まるため、plan / apply が実行できない
> ことに注意。

> [!IMPORTANT]
> Proxmox の API は保留後の値を返すため、この操作の直後から Terraform に
> 差分が出る。[103vm_hcp_terraform_agent.tf](../103vm_hcp_terraform_agent.tf)
> は対応済み (`cdrom` ブロックを削除し `boot_order = ["scsi0"]`)。
> 未対応のまま apply すると `ide2` と `net0` を boot 順序へ戻そうとする。

> [!IMPORTANT]
> 103 は HCP Terraform の Agent であり、これが停止している間は Terraform の
> plan / apply が実行できない。pve が落ちると Terraform も使えなくなるため、
> 移行完了後は 103 を pve 以外のノードへ移すことを推奨する。

### 0-4. homepage のメモリを見直す

`ct:104` は dashboard 用途で 4096MB 割り当てられている。フェイルオーバー先の
pve2 は物理 7.5GB しかなく、ZFS ARC と同居させると苦しい。1024MB 程度への
減量を検討すること (減らす場合は `104lxc_homepage.tf` の `memory.dedicated`)。

---

## Phase 1 — pve2 を ZFS 化 (ゲスト無し / 最も安全)

### 1-1. `local-lvm` を pve2 から外す

`local-lvm` はノード制限なしで定義されているため、pve2 の thin pool を消す前に
対象ノードを絞る。

```bash
ssh root@192.168.1.2 'pvesm set local-lvm --nodes pve,pve3'
```

### 1-2. thin pool を削除して ZFS プールを作る

```bash
ssh root@192.168.1.10 'lvremove -y pve/data && lvcreate -l 95%FREE -n zfsvol pve && zpool create -f -o ashift=12 rpool_data /dev/pve/zfsvol && zfs set compression=lz4 rpool_data && zpool status'
```

### 1-3. ARC を絞る

ZFS の ARC は既定でメモリを大きく使う。pve2 は 7.5GB しかないため 1GB に制限する。

```bash
ssh root@192.168.1.10 'echo "options zfs zfs_arc_max=1073741824" > /etc/modprobe.d/zfs.conf && echo 1073741824 > /sys/module/zfs/parameters/zfs_arc_max && update-initramfs -u'
```

pve3 (8GB) も同様に 1GB、pve (16GB) は 2GB 程度を目安にする。

### 1-4. ZFS ストレージを登録する

移行の途中は対象ノードが増えていくので、この段階では手動で登録し、
全ノード完了後に Terraform 管理へ引き継ぐ (Phase 4)。

```bash
ssh root@192.168.1.2 'pvesm add zfspool local-zfs --pool rpool_data --content images,rootdir --nodes pve2'
```

---

## Phase 2 — pve3 を ZFS 化 (`ct:105` のみ)

### 2-1. HA 登録を一旦外す

HA 管理下のゲストは手動マイグレーションが弾かれるため先に外す。

```bash
ssh root@192.168.1.2 'ha-manager remove ct:105'
```

> [!NOTE]
> ここで外した HA 登録は**手動で戻さない**。Phase 4 の apply で
> `proxmox_haresource.guest["105"]` として Terraform が作り直す。
> 手動で `ha-manager add` すると apply 時に既存リソース衝突で失敗する。

### 2-2. `ct:105` を pve2 の ZFS へ退避

> [!IMPORTANT]
> **`pct` / `qm` はノードローカルのコマンドで、そのゲストを実際にホストして
> いるノード上で実行する必要がある。** `ct:105` は pve3 にいるので pve3
> (192.168.1.11) から実行する。pve で実行すると次のエラーになる。
>
> ```
> Configuration file 'nodes/pve/lxc/105.conf' does not exist
> ```

```bash
ssh root@192.168.1.11 'pct migrate 105 pve2 --restart --target-storage local-zfs'
```

### 2-3. pve3 を ZFS 化

> [!WARNING]
> **この `pvesm set` は 2-2 の移行が完了してから実行すること。**
> 先に実行すると `ct:105` のディスク (`local-lvm:vm-105-disk-0`) を pve3 から
> 解決できなくなり、2-2 が次のエラーで失敗する。
>
> ```
> ERROR: migration aborted: storage 'local-lvm' is not available on node 'pve3'
> ```
>
> 稼働中のコンテナ自体は影響を受けない (マウント済みのため) が、移行できなく
> なる。その状態になったら次で戻してから 2-2 をやり直す。
>
> ```bash
> ssh root@192.168.1.2 'pvesm set local-lvm --nodes pve,pve3'
> ```
>
> 原則は「**移行元ノードから `local-lvm` を外すのは、そのノードのゲストを
> 全て退避し終えた後**」。Phase 3 の 3-2 も同じ。

```bash
ssh root@192.168.1.2 'pvesm set local-lvm --nodes pve'
```

```bash
ssh root@192.168.1.11 'lvremove -y pve/data && lvcreate -l 95%FREE -n zfsvol pve && zpool create -f -o ashift=12 rpool_data /dev/pve/zfsvol && zfs set compression=lz4 rpool_data && zpool status'
```

```bash
ssh root@192.168.1.2 'pvesm set local-zfs --nodes pve2,pve3'
```

ARC 制限 (1GB) も 1-3 と同様に pve3 へ適用する。

### 2-4. `ct:105` を pve3 へ戻す

```bash
ssh root@192.168.1.10 'pct migrate 105 pve3 --restart --target-storage local-zfs'
```

---

## Phase 3 — pve を ZFS 化 (本番ゲスト 5 台の退避を伴う)

> [!WARNING]
> このフェーズ中、各ゲストはマイグレーションのたびに再起動する。
> DNS / DHCP は `ct:100` の停止中に断となるため、作業時間帯に注意すること。

### 3-1. ゲストを退避する

メモリ収容を考え、pve3 に 100/101/102、pve2 に 103/104 を寄せる。

```bash
ssh root@192.168.1.2 'for id in 100 101 102; do pct migrate $id pve3 --restart --target-storage local-zfs; done'
```

```bash
ssh root@192.168.1.2 'pct migrate 104 pve2 --restart --target-storage local-zfs'
```

```bash
ssh root@192.168.1.2 'qm migrate 103 pve2 --online 0 --targetstorage local-zfs'
```

`pvesh get /cluster/resources --type vm` で pve 上にゲストが残っていないことを確認する。

### 3-2. pve を ZFS 化

```bash
ssh root@192.168.1.2 'pvesm set local-lvm --disable 1'
```

```bash
ssh root@192.168.1.2 'lvremove -y pve/data && lvcreate -l 95%FREE -n zfsvol pve && zpool create -f -o ashift=12 rpool_data /dev/pve/zfsvol && zfs set compression=lz4 rpool_data && zpool status'
```

ARC 制限 (2GB) を適用したうえで、ストレージを全ノードへ広げる。

```bash
ssh root@192.168.1.2 'pvesm set local-zfs --nodes pve,pve2,pve3'
```

`local-lvm` はどのノードにも実体が無くなるので削除する。

```bash
ssh root@192.168.1.2 'pvesm remove local-lvm'
```

### 3-3. ゲストを pve へ戻す

100 / 101 / 102 は pve3 に、103 / 104 は pve2 に退避しているので、
それぞれの退避先ノードから実行する。

```bash
ssh root@192.168.1.11 'for id in 100 101 102; do pct migrate $id pve --restart; done'
```

```bash
ssh root@192.168.1.10 'pct migrate 104 pve --restart'
```

```bash
ssh root@192.168.1.10 'qm migrate 103 pve'
```

`ct:105` は pve3 が定位置なので戻さない。

---

## Phase 4 — Terraform で HA を有効化

ここまでで全ゲストのディスクが `local-zfs` 上にある状態になる。

### 4-1. コードの default を更新

この 2 つは**コード内の `default` で管理する**。HCP のワークスペース変数として
は設定しない (UI に隠れた状態を作らず、PR の speculative plan で差分を確認
できるようにするため)。[variables.tf](../variables.tf) を編集する。

| 変数 | 変更前 | 変更後 |
|------|--------|--------|
| `guest_datastore_id` | `local-lvm` | `local-zfs` |
| `enable_ha` | `false` | `true` |

> [!WARNING]
> `guest_datastore_id` は実機の状態に追従させるための変数なので、
> **Phase 3 完了前に変更してはいけない**。逆に Phase 3 完了後に変更を忘れると、
> コードが `local-lvm` を指したまま実機が `local-zfs` になり、plan が
> **全コンテナの破壊・再作成**を出す。実際に 2026-07-26 の実施時、この状態で
> 次の plan が出た。
>
> ```
> ~ datastore_id = "local-zfs" -> "local-lvm" # forces replacement
> Plan: 5 to add, 0 to change, 5 to destroy.
> ```

### 4-2. 手動登録したストレージを Terraform へ引き継ぐ

Phase 1 で `pvesm add` した `local-zfs` を import する。

```bash
terraform import proxmox_storage_zfspool.guest_storage[0] local-zfs
```

### 4-3. apply

```bash
terraform apply
```

作成されるもの:

- `pvesr` レプリケーションジョブ 5 本 (`100-0`, `101-0`, `102-0`, `104-0`, `105-0`)
- HA リソース 5 件 (`ct:100`, `ct:101`, `ct:102`, `ct:104`, `ct:105`)
- node-affinity ルール 5 件 (`strict = true`)

割り当ては [ha.tf](../ha.tf) の `local.ha_guests` を参照。

| ゲスト | 通常ノード | 退避先 | 複製間隔 |
|--------|-----------|--------|---------|
| dns01 (100) | pve | pve3 | 5 分 |
| pulse (101) | pve | pve3 | 15 分 |
| traefik (102) | pve | pve3 | 5 分 |
| homepage (104) | pve | pve2 | 15 分 |
| gh-runner (105) | pve3 | pve2 | 15 分 |

---

## Phase 5 — 動作確認

### 5-1. レプリケーションが回っていること

```bash
ssh root@192.168.1.2 'pvesr status'
```

`LastSync` が更新され `FailCount` が 0 であること。初回同期はフルコピーになる
ため 1GbE では数分かかる。

### 5-2. HA の状態

```bash
ssh root@192.168.1.2 'ha-manager status && ha-manager rules config'
```

全ノードの `lrm` が `active` になっていること (以前は pve / pve2 が `idle` だった)。

### 5-3. フェイルオーバーの実地確認

初回同期の完了を確認してから、pve を意図的に落として `ct:100` が pve3 で
起動することを確認する。**必ず手元で復旧できる時間帯に行うこと。**

```bash
ssh root@192.168.1.2 'ha-manager migrate ct:100 pve3'
```

まずは上記の計画移動で動作を確認し、そのうえで電源断相当の試験を行う。

---

## フェイルオーバー後の state 復旧 (bpg プロバイダの既知の制約)

bpg プロバイダはコンテナを **state に記録された `node_name` のノードにだけ**
問い合わせる。HA がフェイルオーバーさせると state のノードには居なくなるため、
次の `terraform plan` が以下のように出る。

```
# proxmox_virtual_environment_container.lxc_100 has been deleted
# proxmox_virtual_environment_container.lxc_100 will be created
```

プロバイダ README の Known Issues "HA VMs / containers" に記載された仕様で、
`ignore_changes = [node_name]` では防げない (config と state の差分を無視する
だけで、読み取り時の 404 は防げないため)。

> [!NOTE]
> VMID は Proxmox クラスタ全体で一意なので、この状態で apply しても
> 「CT 100 already exists」で**失敗するだけ**であり、稼働中のコンテナが
> 消えることはない。とはいえ plan が汚れたままになるので下記で直す。

フェイルオーバーが起きたら、実際に居るノードを確認して state を貼り直す。

```bash
ssh root@192.168.1.2 'pvesh get /cluster/resources --type vm --output-format json' | python3 -c 'import json,sys; [print(r["id"], r["node"]) for r in json.load(sys.stdin)]'
```

```bash
terraform state rm proxmox_virtual_environment_container.lxc_100
```

そのうえで `100lxc_dns01.tf` に import ブロックを一時的に足して apply する。

```hcl
import {
  to = proxmox_virtual_environment_container.lxc_100
  id = "pve3/100" # 実際に居るノード
}
```

import が終わったらブロックは削除してよい。

## 補足 — HA だけでは DNS / DHCP は守り切れない

PVE の HA は「ノードが落ちたことを検知して別ノードで起動し直す」仕組みなので、
フェンス待ちと起動を含めて **復旧までに 1〜2 分の断が発生する**。加えて
レプリケーションは非同期なので最大 5 分ぶんの書き込みが失われる。

`ct:100` は AdGuard Home が DNS (53/udp) と DHCP (67/udp) を兼ねており、
ここが単一障害点であることは HA を入れても変わらない。次の対策も検討する価値がある。

1. **DHCP をルータ (192.168.1.1) へ戻す。**
   AdGuard の DHCP は冗長化できない。ルータ側の DHCP なら Proxmox の障害と
   独立する。現状のレンジは `192.168.1.129-199` / lease 86400 秒。

2. **DNS を 2 台構成にする。**
   pve3 上にもう 1 台 AdGuard のコンテナを立て、DHCP が配る DNS サーバを
   2 つにする。クライアント側が自動で切り替わるため断がゼロになり、
   フェイルオーバー待ちが不要になる。

3. **Traefik を 2 台 + keepalived の VIP にする。**
   同様に切り替え時間をゼロにできる。

HA (ノード障害からの自動復旧) とアプリ層の冗長化は目的が違うので、
両方入れておくのが望ましい。
