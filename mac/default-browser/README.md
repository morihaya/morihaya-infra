# macOS デフォルトブラウザ切り替え

仕事では Edge、個人作業では Comet や Chrome、というようにリンクの開き先を
ワンアクションで切り替えるための仕組み。Raycast のコマンドかシェルから叩く。

- 構築: 2026-08-14
- 検証環境: macOS 15.7.7 (Sequoia, Apple Silicon) / Finicky 4.2.2 / Raycast 1.104.24

## 構成

```
mac/default-browser/
├── bin/set-default-browser   # 本体
├── raycast/                  # Raycast スクリプトコマンド 5 個
├── finicky.js.example        # Finicky 設定の雛形
└── install.sh                # 新しいマシンへの導入
```

実際に使うファイルの配置先は次のとおり。`install.sh` がこのリポジトリへの
シンボリックリンクを張るので、編集は Git で追跡される。

| 配置先 | 内容 |
|---|---|
| `~/.local/bin/set-default-browser` | 本体へのシンボリックリンク |
| `~/.config/raycast/scripts/` | Raycast コマンドへのシンボリックリンク |
| `~/.finicky.js` | 雛形からコピー。**追跡しない** |

`~/.finicky.js` を追跡しないのは、社内ドメインの振り分けルールを書いたときに
公開リポジトリへ流れないようにするため。

## 仕組み

macOS のデフォルトブラウザは **Finicky に固定**する。Finicky が全リンクを受け取り、
`~/.finicky.js` の `DEFAULT_BROWSER` に書かれたブラウザへ転送する。切り替えとは
この 1 行の書き換えのことで、OS の設定自体は一度も変更しない。

```
リンククリック → Finicky → DEFAULT_BROWSER のブラウザ
```

この構成にした理由は「なぜ OS の設定を直接変えないか」の節を参照。

## 導入

```sh
./install.sh
```

そのあと手動で 3 つ。スクリプト化できない。

1. Finicky のメニューバーアイコン → Set as default browser → macOS の確認ダイアログを承認
2. Finicky の設定で **Start at login** を有効化（起動していないと転送されない）
3. Raycast → Settings → Extensions → Script Commands → Add Script Directory で
   `~/.config/raycast/scripts` を追加

確認:

```sh
set-default-browser --check
```

## 使い方

```sh
set-default-browser            # 今どれか表示
set-default-browser comet      # Comet に切り替え
set-default-browser toggle     # 仕事用 ⇄ 個人用
set-default-browser --check    # 導入状態の検証
```

対応: `edge` / `comet` / `chrome` / `safari` / `firefox` / `brave` / `toggle`

`toggle` の対象は環境変数 `WORK_BROWSER` と `PERSONAL_BROWSER` で変えられる。
既定は `edge` と `comet`。

Raycast 側は 5 コマンド。トグルにホットキーを割り当てるのが一番速い。

| コマンド | 動作 |
|---|---|
| Default Browser: Toggle Work/Personal | Edge ⇄ Comet |
| Default Browser: Edge / Comet / Chrome | 直接指定 |
| Default Browser: Show | 現在の設定を表示 |

## ドメイン単位のルール

`~/.finicky.js` の `handlers` に書く。個人モード中でも仕事のリンクだけ Edge に
固定する、といった使い方ができる。`handlers` は `DEFAULT_BROWSER` より優先される。

```js
handlers: [
  {
    match: ["teams.microsoft.com/*", "*.sharepoint.com/*"],
    browser: "Microsoft Edge",
  },
],
```

手で編集した場合は Finicky の再起動が必要（後述）。

## なぜ OS の設定を直接変えないか

最初は [defaultbrowser](https://github.com/kerma/defaultbrowser) で OS のデフォルトを
直接切り替える実装にしたが、実用にならなかった。以下は実機で確認した内容で、
どれも既存のドキュメントには書かれていない。

### 1. macOS 15 は切り替えのたびに確認ダイアログを出す

Apple の仕様で、`defaultbrowser` でも `duti` でも回避できない。自動で押すには
System Events による UI スクリプティングが必要で、呼び出し元アプリに
**アクセシビリティとオートメーションの両方**の権限が要る。

ターミナルにアクセシビリティ権限を与えるのは「そのアプリが他のあらゆるアプリを
操作できる」ということなので、業務用マシンでは割に合わない。加えて
`CoreServicesUIAgent` がダイアログを出すまでの時間が不定で、ポーリングが
空振りすることもあった。

### 2. `defaultbrowser` は現在値を誤って報告する

書き込み時に Bundle ID を小文字化するのに、現在値の照合では大文字小文字を
区別する。LaunchServices 自体は区別しないので**切り替えは成功するが、
ツールは自分が書いた値を認識できず `*` を表示しない**。

影響を受けるのは Bundle ID に大文字を含むブラウザだけ。

| ブラウザ | Bundle ID | 症状 |
|---|---|---|
| Microsoft Edge | `com.microsoft.edgemac` | 正常 |
| Comet | `ai.perplexity.comet` | 正常 |
| Firefox | `org.mozilla.firefox` | 正常 |
| Google Chrome | `com.google.Chrome` | **報告できない** |
| Safari | `com.apple.Safari` | **報告できない** |
| Brave | `com.brave.Browser` | **報告できない** |

このため「切り替えは成功しているのに失敗と報告される」という紛らわしい状態になる。
現在値を知りたいなら LaunchServices の plist を直接読むほうが確実。

```sh
python3 -c 'import plistlib,os
d=plistlib.load(open(os.path.expanduser("~/Library/Preferences/com.apple.LaunchServices/com.apple.launchservices.secure.plist"),"rb"))
print([h.get("LSHandlerRoleAll") for h in d["LSHandlers"] if h.get("LSHandlerURLScheme")=="https"])'
```

### 3. Finicky 4.2.2 は設定をホットリロードしない

README には設定変更で自動的にリロードされるとあるが、実際にはされない。
未起動のブラウザを指定して「実際に起動するか」で判定したところ、

- `sed -i` による書き換え（inode が変わる）→ リロードされない
- inode を保つ書き換え → **やはりリロードされない**
- Finicky を再起動 → 反映される

このため `set-default-browser` は書き換え後に Finicky を再起動する。
バックグラウンドエージェント（`LSUIElement`）なので画面上は何も起きず、
切り替え全体で 0.7 秒ほど。

**手で `~/.finicky.js` を編集したときも再起動が必要。**

```sh
pkill -x Finicky && open -gj -a Finicky
```

## 権限について

この構成ではアクセシビリティもオートメーションも**不要**。確認ダイアログが出るのは
Finicky を既定に設定する最初の 1 回だけ。
