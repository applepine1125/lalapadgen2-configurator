#!/usr/bin/env bash
# 下書きのリリースに署名を付けて公開する。
#
#   bash mac/release.sh            最新の下書きを署名して公開する
#   bash mac/release.sh --wait     CI のビルドが終わるのを待ってから公開する
#   bash mac/release.sh <タグ>     下書きを指定して公開する
#   bash mac/release.sh --yes ...  確認を省く
#
# CI はビルドして下書きを作るところまでで、公開はしない。署名の秘密鍵は手元にしか
# 無いので、公開はこのスクリプトを実行した人だけができる。
#
# 「下書きを見つけたら自動で署名する」仕組みを足さないこと。攻撃者が push した
# ビルドも同じ仕組みが署名してしまい、検証する意味が無くなる。
set -euo pipefail

REPO="applepine1125/lalapadgen2-configurator"
HERE="$(cd "$(dirname "$0")" && pwd)"
KEY="${LALA2CONF_SIGNING_KEY:-$HOME/.config/lala2conf/signing.key}"

TAG=""
WAIT=0
ASSUME_YES=0
for arg in "$@"; do
  case "$arg" in
    --wait) WAIT=1 ;;
    --yes|-y) ASSUME_YES=1 ;;
    -*) echo "知らないオプション: $arg" >&2; exit 1 ;;
    *) TAG="$arg" ;;
  esac
done

if [ ! -f "$KEY" ]; then
  echo "署名の鍵がありません: $KEY" >&2
  echo "先に  swift mac/tools/sign_release.swift keygen  を実行してください" >&2
  exit 1
fi

if [ "$WAIT" -eq 1 ]; then
  RUN="$(gh run list -R "$REPO" -L1 --json databaseId --jq '.[0].databaseId')"
  echo "CI の完了を待っています(run $RUN)..."
  gh run watch "$RUN" -R "$REPO" --exit-status >/dev/null
fi

if [ -z "$TAG" ]; then
  TAG="$(gh release list -R "$REPO" --json tagName,isDraft --jq '[.[] | select(.isDraft)] | .[0].tagName // empty')"
  if [ -z "$TAG" ]; then
    echo "下書きのリリースがありません(すでに公開済みか、CI がまだ作っていません)" >&2
    exit 1
  fi
fi

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

gh release download "$TAG" -R "$REPO" --pattern '*.zip' --dir "$WORK"
ZIP="$(find "$WORK" -maxdepth 1 -name '*.zip' | head -1)"
if [ -z "$ZIP" ]; then
  echo "リリース $TAG に zip がありません" >&2
  exit 1
fi

# 何に署名しようとしているかを見せてから署名する(自分のビルドかどうかは人が判断する)
echo
echo "タグ    : $TAG"
echo "資産    : $(basename "$ZIP") ($(wc -c < "$ZIP" | tr -d ' ') バイト)"
echo "sha256  : $(shasum -a 256 "$ZIP" | cut -d' ' -f1)"
echo "元コミット: $(gh release view "$TAG" -R "$REPO" --json body --jq '.body')"
echo

if [ "$ASSUME_YES" -eq 0 ]; then
  printf "この内容に署名して公開しますか? [y/N] "
  read -r answer
  case "$answer" in
    y|Y|yes) ;;
    *) echo "やめました"; exit 1 ;;
  esac
fi

swift "$HERE/tools/sign_release.swift" sign "$ZIP" >/dev/null
gh release upload "$TAG" -R "$REPO" "$ZIP.sig" --clobber
gh release edit "$TAG" -R "$REPO" --draft=false >/dev/null

echo "署名して公開しました: $TAG"
