#!/usr/bin/env bash
# 下書きのまま置かれているリリースに署名を付けて公開する。
#
#   bash mac/release.sh lala2conf-b12
#
# CI はビルドして下書きリリースを作るところまでで、公開はしない。
# 署名の秘密鍵は手元にしか無いので、公開はこのスクリプトを実行した人だけができる。
set -euo pipefail

TAG="${1:-}"
if [ -z "$TAG" ]; then
  echo "使い方: bash mac/release.sh <タグ>(例: lala2conf-b12)" >&2
  exit 1
fi

REPO="applepine1125/lalapadgen2-configurator"
HERE="$(cd "$(dirname "$0")" && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

gh release download "$TAG" -R "$REPO" --pattern '*.zip' --dir "$WORK"
ZIP="$(find "$WORK" -name '*.zip' -maxdepth 1 | head -1)"
if [ -z "$ZIP" ]; then
  echo "リリース $TAG に zip がありません" >&2
  exit 1
fi

swift "$HERE/tools/sign_release.swift" sign "$ZIP"
gh release upload "$TAG" -R "$REPO" "$ZIP.sig" --clobber
gh release edit "$TAG" -R "$REPO" --draft=false

echo "署名して公開しました: $TAG"
