# LalaPadGen2 Configurator

LalaPad Gen2 のトラックパッドとキーマップを、キーボードを接続したまま調整できる macOS アプリケーションです。
ファームウェアは [zmk-config-LalaPadGen2](https://github.com/applepine1125/zmk-config-LalaPadGen2) にあります。

## 動作環境

| 項目 | 要件 |
| --- | --- |
| OS | macOS 13 以降 |
| ファームウェア | v0.0.20 以降 |
| 接続方式 | Bluetooth または USB |

本アプリケーションは、ファームウェアが提供する調整用の GATT サービスを介して通信します。v0.0.20 より前のファームウェアでは「調整用の GATT サービスがありません(ファームが古い)」と表示され、接続できません。

## インストール

### 1. ファームウェアを書き込む

[zmk-config-LalaPadGen2 の Releases](https://github.com/applepine1125/zmk-config-LalaPadGen2/releases) から `firmware-v*.zip` をダウンロードしてください。UF2 ファイルが 3 つ含まれています。

| ファイル | 対象 |
| --- | --- |
| `lalapadgen2_left rgbled_adapter-seeeduino_xiao_ble-zmk.uf2` | 左手側 |
| `lalapadgen2_right rgbled_adapter-seeeduino_xiao_ble-zmk.uf2` | 右手側 |
| `settings_reset-seeeduino_xiao_ble-zmk.uf2` | 設定を初期化する場合のみ使用 |

左右の両方に書き込む必要があります。リセットボタンを素早く 2 回押すとブートローダのドライブがマウントされるので、対応する UF2 ファイルをコピーしてください。

### 2. アプリケーションをインストールする

[Releases](https://github.com/applepine1125/lalapadgen2-configurator/releases/latest) から `LalaPadGen2Configurator-b*.zip` をダウンロードして展開し、`LalaPadGen2 Configurator.app` を `/Applications` に配置します。

本アプリケーションは ad-hoc 署名(Apple Developer Program 未加入)のため、ブラウザ経由で取得した zip から導入した場合、初回起動時に Gatekeeper によってブロックされます。「システム設定 > プライバシーとセキュリティ」を開き、下部に表示される「このまま開く」を選択してください(macOS 15 以降、右クリックからの「開く」では回避できません)。

インストール後は、アプリケーション自身が新しいリリースを検出して更新します。

## 使い方

アプリケーションを起動し、「接続」をクリックするとキーボードを検索します。初回起動時には Bluetooth の使用許可を求められます。許可しない場合は USB 接続のみ利用できます。

**Bluetooth で接続する場合**

あらかじめ Mac と右手側キーボードをペアリングしておいてください(キーボードとして通常どおり使用できる状態)。左手側の設定は右手側を経由して変更できるため、左手側を個別に接続する必要はありません。

**USB で接続する場合**

調整対象の側にケーブルを接続します。右手側はシリアルポートが 2 つ列挙されるため、応答する方を選択してください。

## リポジトリ構成

| ディレクトリ | 内容 |
| --- | --- |
| `web/` | 画面と調整ロジック。依存関係を持たない HTML + JavaScript |
| `mac/` | macOS アプリケーション。Swift + WKWebView で `web/` を表示し、BLE と USB シリアルへの橋渡しを担う |

macOS では HID 接続中の BLE デバイスに対してブラウザ(Web Bluetooth)から GATT アクセスできないため、Bluetooth 経由の調整には本アプリケーションが必要です。USB のみで利用する場合は、`web/index.html` を Chrome または Edge で直接開いても動作します。

## 開発

```sh
node --test web/*.test.js     # ページのテスト(ディレクトリ指定は CI の Node で失敗する)
bash mac/build.sh --run       # ビルドして起動する
bash mac/build.sh --install   # /Applications/LalaPadGen2 Configurator.app にインストールする
```

実機がなくても `web/index.html?fakeNative=1` で画面を確認できます(`&fakeLive=1` を付与するとダミーのフレームが流れます)。

ページとネイティブ間のやり取りは `mac/Sources/WebBridge.swift` を参照してください(JS → ネイティブは `handlePageMessage` の switch、ネイティブ → JS は `send(type:)` の呼び出し箇所)。

## リリース

`main` への push により CI がビルドし、**下書きの**リリースを作成します。下書きのままではアプリケーションから参照できないため、手元で署名して公開します。

```sh
bash mac/release.sh --wait   # CI の完了を待って署名し、公開する
```

手順および遵守事項(署名鍵を CI に置かない、人手の確認を経ずに署名しない)は [CLAUDE.md](CLAUDE.md) を参照してください。
