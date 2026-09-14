# LalaPadGen2 Configurator

LalaPad Gen2 のトラックパッドとキー設定を、つなぎながら調整する macOS アプリです。
ファームウェア側は [zmk-config-LalaPadGen2](https://github.com/applepine1125/zmk-config-LalaPadGen2)。

## 構成

| 場所 | 中身 |
| --- | --- |
| `web/` | 画面とロジック。依存なしの HTML + JavaScript |
| `mac/` | macOS アプリ。Swift + WKWebView で `web/` を表示し、BLE と USB シリアルへの橋渡しをする |

macOS では HID 接続中の BLE デバイスにブラウザから GATT アクセスできないため、BT 接続にはこのアプリが要ります。
USB だけでよければ `web/index.html` を Chrome か Edge で直接開いても動きます。

## 開発

```sh
node --test web/*.test.js     # ページのテスト(ディレクトリ指定は CI の Node で失敗する)
bash mac/build.sh --run       # ビルドして起動
bash mac/build.sh --install   # /Applications/LalaPadGen2 Configurator.app に入れる
```

実機がなくても `web/index.html?fakeNative=1` で画面を確認できます(`&fakeLive=1` でダミーのフレームが流れる)。

ページとネイティブのやり取りは `mac/Sources/WebBridge.swift` を見てください(JS → ネイティブは `handlePageMessage` の switch、ネイティブ → JS は `send(type:)` の呼び出し箇所)。

## リリース

`main` に push すると CI が**下書きの**リリースを作ります。下書きのままではアプリから見えないので、手元で署名して公開します。

```sh
bash mac/release.sh --wait   # CI の完了を待ってから署名して公開する
```

手順と守るべき不変条件(鍵を CI に置かない、人の確認を挟まずに署名しない)は [CLAUDE.md](CLAUDE.md) を参照してください。
