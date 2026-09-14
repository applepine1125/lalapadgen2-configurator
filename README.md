# LalaPadGen2 Configurator

LalaPad Gen2 のトラックパッドとキー設定を、つなぎながら調整する macOS アプリです。
ファームウェア側は [zmk-config-LalaPadGen2](https://github.com/applepine1125/zmk-config-LalaPadGen2)。

## 使う

### 1. 対応ファームウェアを入れる

このアプリは、ファームウェア側の調整用 GATT サービス経由でキーボードとやり取りします。**`v0.0.20` 以降**のファームウェアが要ります(それ以前だと「調整用の GATT サービスがありません(ファームが古い)」と出ます)。

[zmk-config-LalaPadGen2 の Releases](https://github.com/applepine1125/zmk-config-LalaPadGen2/releases) から `firmware-v*.zip` を落とすと、UF2 が 3 つ入っています。

| ファイル | 書き込み先 |
| --- | --- |
| `lalapadgen2_left rgbled_adapter-seeeduino_xiao_ble-zmk.uf2` | 左手 |
| `lalapadgen2_right rgbled_adapter-seeeduino_xiao_ble-zmk.uf2` | 右手 |
| `settings_reset-seeeduino_xiao_ble-zmk.uf2` | 設定を消したいときだけ |

**左右の両方に入れてください。** リセットボタンを素早く 2 回押すとブートローダのドライブが現れるので、そこへ UF2 をコピーします。

### 2. アプリを入れる

[Releases](https://github.com/applepine1125/lalapadgen2-configurator/releases/latest) から `LalaPadGen2Configurator-b*.zip` を落として展開し、`LalaPadGen2 Configurator.app` を `/Applications` に置きます。

このアプリは ad-hoc 署名(Apple Developer Program なし)なので、ブラウザで落とした zip から入れると初回だけ Gatekeeper に止められます。「システム設定 > プライバシーとセキュリティ」を開き、下の方に出る「このまま開く」を押してください(macOS 15 以降、右クリック →「開く」では回避できません)。

一度入れてしまえば、以降はアプリ自身が更新を見つけて入れ替えます。

### 3. つなぐ

アプリを開いて「接続」を押すと、Bluetooth か USB でキーボードを探します。

- **Bluetooth**: 先に Mac と右手キーボードをペアリングしておいてください(キーボードとして普通に使える状態)。左手の設定も右手経由で変えられるので、左手をつなぐ必要はありません
- **USB**: 調整したい側にケーブルを挿します。右手はポートが 2 つ見えるので、応答するほうを選びます

初回は Bluetooth の使用許可を聞かれるので許可してください。拒否すると USB でしか使えません。

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
