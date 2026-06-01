#!/bin/bash
# Claude Code on the web 用のセッション開始フック。
# セッションが始まるたびに走り、Flutter をすぐ使える状態にする。
# （初回だけ Flutter をインストールし、2回目以降はキャッシュを使って高速に終わる）
set -euo pipefail

# 手元のPC（ローカル）では何もしない。クラウド（web）のときだけ動く。
if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

FLUTTER_DIR="/opt/flutter"
FLUTTER_VERSION="3.44.0"

# 1) Flutter 本体。未インストールのときだけ入れる（2回目以降はスキップ）。
if [ ! -x "$FLUTTER_DIR/bin/flutter" ]; then
  echo "Installing Flutter ${FLUTTER_VERSION} (first time only, may take a few minutes)..."
  curl -fsSL -o /tmp/flutter_linux.tar.xz \
    "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz"
  tar xf /tmp/flutter_linux.tar.xz -C /opt
  rm -f /tmp/flutter_linux.tar.xz
fi

# 2) flutter / dart をどのコマンドからも使えるように PATH へ。
ln -sf "$FLUTTER_DIR/bin/flutter" /usr/local/bin/flutter
ln -sf "$FLUTTER_DIR/bin/dart" /usr/local/bin/dart
export PATH="$FLUTTER_DIR/bin:$PATH"
if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
  echo "export PATH=\"$FLUTTER_DIR/bin:\$PATH\"" >> "$CLAUDE_ENV_FILE"
fi

# 3) root 実行時に Flutter 内部の git が警告を出さないようにする（重複追加は防ぐ）。
git config --global --get-all safe.directory 2>/dev/null | grep -qx "$FLUTTER_DIR" \
  || git config --global --add safe.directory "$FLUTTER_DIR"

# 4) 解析データ送信オフ＋Web有効化（任意。失敗しても続行）。
flutter --disable-analytics >/dev/null 2>&1 || true
flutter config --enable-web >/dev/null 2>&1 || true

# 5) 依存パッケージを取得。これで flutter analyze / test / build web が使える。
cd "$CLAUDE_PROJECT_DIR"
flutter pub get

echo "Flutter ready: $(flutter --version 2>/dev/null | grep -m1 -E '^Flutter ' || echo installed)"
