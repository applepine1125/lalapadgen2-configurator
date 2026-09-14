# LalaPadGen2 Configurator

LalaPad Gen2 のトラックパッドとキー設定を、つなぎながら調整するための道具です。macOS アプリ(LalaPadGen2 Configurator)と、その中身のページで構成しています。

- トラックパッドのパラメータを読み書きし、書き込んだ結果をその場で試せます
- パッドの接触と、検知したジェスチャをライブで表示します
- ZMK Studio の RPC でキーマップを読み書きします
- トラックパッドとキー設定をまとめてプリセットとして保存し、キーボードの設定が消えても戻せます
- `.conf` と `.keymap` を書き出して git で管理できます

ファームウェア側(GATT サービス・左手への転送・IQS9151 ドライバ)は
[zmk-config-LalaPadGen2](https://github.com/applepine1125/zmk-config-LalaPadGen2) にあります。

## 構成

| 場所 | 中身 |
| --- | --- |
| `web/` | 画面とロジック。依存なしの HTML + JavaScript。`node --test web/*.test.js` でテストできる |
| `mac/` | macOS アプリ。Swift + WKWebView で `web/` を表示し、BLE(CoreBluetooth)と USB シリアルへの橋渡しをする |

## 使う

```
bash mac/build.sh --install
```

`/Applications/Lala2Conf.app` に入ります。アプリを開いて「接続」を押すと、Bluetooth か USB でキーボードを探します。

ブラウザだけで使う場合は `web/index.html` を Chrome か Edge で開きます(USB のみ。Bluetooth は Mac アプリが必要です)。

## 更新

`main` に push すると GitHub Actions がアプリをビルドし、`lala2conf-b<ビルド番号>` というタグで **下書きの**リリースを作ります。下書きのままではアプリから見えません。手元で署名して公開すると、アプリがメニューの「更新を確認…」と起動から数秒後に見つけて入れ替え、再起動します。

```
bash mac/release.sh          # 最新の下書きを署名して公開する
bash mac/release.sh --wait   # CI のビルドを待ってから公開する
```

何に署名しようとしているか(タグ・サイズ・sha256・元のコミット)を表示してから確認を求めます。**下書きを見つけたら自動で署名する仕組みは入れません** — 攻撃者が push したビルドも同じ仕組みが署名してしまい、検証する意味が無くなるためです。

手元でビルドしたもの(ビルド番号 0)は、起動時の自動確認をしません。

### 更新の署名

自動更新は「自分のバンドルを丸ごと置き換えて再起動する」ので、置き換えるものが自分の作ったものかを確かめないと、GitHub のアカウントやリポジトリを取られた時点で、この Mac で任意のコードが動いてしまいます。そこでリリースの zip に ed25519 の署名を付け、アプリに埋め込んだ公開鍵で検証しています(合わなければ更新を中止します)。

**秘密鍵は手元にしか置きません。** CI に鍵を置くと、リポジトリを取れた相手がそのワークフローで署名できてしまい、検証する意味が無くなります。そのため「ビルドと下書きリリースまでは自動、公開だけ手元」という形にしています。

```
swift mac/tools/sign_release.swift keygen   # 初回だけ。~/.config/lala2conf/signing.key を作る
swift mac/tools/sign_release.swift pubkey   # 表示された公開鍵を mac/Sources/Updater.swift に貼る
```

鍵を作り直すと、古い公開鍵が入ったアプリは更新できなくなります(手元でビルドし直して入れ替えてください)。

なお、この Mac アプリは ad-hoc 署名(Apple Developer Program なし)です。アプリが自分でダウンロードしたファイルには `com.apple.quarantine` が付かないため、Gatekeeper はこの更新経路を検査していません。上の署名検証は、その代わりに自分で真正性を確かめるためのものです。

## 開発

```
node --test web/*.test.js   # ページのテスト
bash mac/build.sh --run   # ビルドして起動
```

実機がなくても `web/index.html?fakeNative=1` で画面を確認できます。模擬の機器に接続でき、`&fakeLive=1` を足すとダミーのフレームが流れます。
