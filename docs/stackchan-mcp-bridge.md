# StackChan MCP ブリッジ

M5Stack の卓上ロボット StackChan から、自宅の情報を音声で引けるようにするための
常駐ブリッジ。VM 106 (`192.168.1.12`) で systemd サービスとして動かす。

- 構築: 2026-08-08
- ホスト: VM 106 `openclaw` / 192.168.1.12 (OpenClaw と同居)
- サービス: `stackchan-bridge.service`

## 何をしているか

StackChan の出荷時ファームは xiaozhi ベースで、AI エージェントが **MCP クライアント**
として振る舞う。`api.xiaozhi.me` の MCP エンドポイントに WebSocket でツールを登録
しておくと、端末に話しかけたときにそのツールが呼ばれる。

```
StackChan ──(音声)── xiaozhi クラウド ──(wss)── mcp_pipe.py ──(stdio)── MCP サーバ
                                                 [VM 106]              homeinfo_mcp.py
```

> [!IMPORTANT]
> **ツール登録用の pull 型チャネルであって、端末を操作する経路ではない。**
> 外部から「喋らせる」ことはできない。push したい場合はファーム差し替えか
> xiaozhi サーバの自前運用が必要になる。

通信は outbound の wss のみ。ポート開放も traefik 配下への配置も不要。

## 構成

| 項目 | 値 |
|------|-----|
| ブリッジ本体 | [78/mcp-calculator](https://github.com/78/mcp-calculator) の `mcp_pipe.py` |
| 配置 | `/opt/stackchan/` |
| 実行ユーザ | `morihaya` |
| 消費 | 常時 約65MB |
| MCP サーバ | 家庭情報リポジトリ (private: `morihaya-homeinfo`) の `scripts/homeinfo_mcp.py` |

```
/opt/stackchan/
├── venv/                # python3.11 -m venv (mcp / websockets / python-dotenv)
├── mcp-calculator/      # git clone。mcp_pipe.py 本体
├── mcp_config.json      # 接続する MCP サーバの定義
└── run.sh               # クレデンシャルを復号して mcp_pipe.py を起動
```

MCP サーバのスクリプトは OpenClaw の workspace 配下に自動同期されている
クローンを参照している (`/home/morihaya/openclaw/data/config/workspace/home`)。
そのため、家庭情報リポジトリへ push すれば内容がそのまま反映される。

## エンドポイントの扱い

エンドポイントは `wss://api.xiaozhi.me/mcp/?token=...` の形で、**URL にトークンが
埋まっている**。実体は 1Password (`M5StackChan MCP`) に置き、VM 上では systemd の
暗号化クレデンシャルとして保持する。

```bash
sudo systemd-creds encrypt --name=mcp_endpoint <平文ファイル> \
  /etc/credstore.encrypted/stackchan.mcp_endpoint
```

平文はディスクに置かない。起動時にだけ復号され、環境変数として渡る。

> [!CAUTION]
> **復号鍵は `/var/lib/systemd/credential.secret` に紐づく。** 他ホストでは
> 復号できないが、TPM なし VM のためディスクごと持ち出された場合は復号可能。
> 家庭内前提の割り切り。vTPM を足せば締められる。

再発行したら上記コマンドで入れ替えて `systemctl restart stackchan-bridge`。
平文ファイルは `shred -u` で消すこと。

## systemd ユニット

`/etc/systemd/system/stackchan-bridge.service`

```ini
[Unit]
Description=StackChan MCP bridge (homeinfo)
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=morihaya
Group=morihaya
WorkingDirectory=/opt/stackchan
LoadCredentialEncrypted=mcp_endpoint:/etc/credstore.encrypted/stackchan.mcp_endpoint
ExecStart=/opt/stackchan/run.sh
Restart=always
RestartSec=5

NoNewPrivileges=yes
PrivateTmp=yes
ProtectSystem=strict
ProtectHome=read-only
ProtectKernelTunables=yes
ProtectControlGroups=yes
RestrictSUIDSGID=yes
MemoryMax=256M

[Install]
WantedBy=multi-user.target
```

> [!TIP]
> `ProtectSystem=strict` は `/run` も read-only にするため、MCP サーバを
> `docker exec` で起動する場合は drop-in で `ReadWritePaths=/run/docker.sock`
> を足す必要がある (unix ソケットへの接続に書き込み権限が要るため)。

## 運用

```bash
sudo systemctl status stackchan-bridge
journalctl -u stackchan-bridge -f
```

正常時のログ。サーバごとに WebSocket が1本張られる。

```
MCP_PIPE - Starting servers: homeinfo
MCP_PIPE - [homeinfo] Successfully connected to WebSocket server
MCP_PIPE - [homeinfo] Started server process: ...
```

接続が切れても `mcp_pipe.py` 側が指数バックオフ (最大600秒) で再接続する。
サービス自体の異常終了は systemd が拾う。

MCP サーバ単体の動作確認は、家庭情報リポジトリ側で完結する。

```bash
uv run scripts/homeinfo_mcp.py --selftest
```

## はまった点

- **xiaozhi は同一エンドポイントへの複数接続を受け付ける。** `mcp_config.json` に
  複数サーバを書くと、`mcp_pipe.py` はサーバごとに1本ずつ WebSocket を張る。
  ただし**同じブリッジを2箇所 (母艦と VM) で動かすのは避ける**
- `uv` は入れず、`python3 -m venv` で固定した。起動のたびに依存解決が挟まらない
- Debian 12 の `python3-venv` は既定で入っていないので `apt install python3.11-venv` が要る

## OpenClaw との連携について

同じ VM の OpenClaw を MCP 経由で StackChan に繋ぐ構想は**保留中**。
`openclaw mcp serve` が `operator.approvals` を無条件で要求する件が壁になっている。
詳細と再挑戦の手順は [docker/openclaw/README.md](../docker/openclaw/README.md#mcp-channel-bridge) を参照。

読み取り系ツールだけを見せるための汎用プロキシ (`scripts/mcp_allowlist.py`) は
家庭情報リポジトリ側に用意してあり、単体では動作確認済み。
