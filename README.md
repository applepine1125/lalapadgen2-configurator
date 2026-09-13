# Lala2Conf

LalaPad Gen2 のトラックパッドとキー設定を、つなぎながら調整するための道具です。macOS アプリ(Lala2Conf)と、その中身のページで構成しています。

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

`main` に push すると GitHub Actions がアプリをビルドし、`lala2conf-b<ビルド番号>` というタグでリリースを作ります。アプリはメニューの「更新を確認…」と起動から数秒後に新しいビルドを探し、見つかれば入れ替えて再起動します。

手元でビルドしたもの(ビルド番号 0)は、起動時の自動確認をしません。

## 開発

```
node --test web/*.test.js   # ページのテスト
bash mac/build.sh --run   # ビルドして起動
```

実機がなくても `web/index.html?fakeNative=1` で画面を確認できます。模擬の機器に接続でき、`&fakeLive=1` を足すとダミーのフレームが流れます。
