#!/usr/bin/env bash
# brainit CLI installer (macOS / Linux, no Homebrew required).
#
#   curl -fsSL https://raw.githubusercontent.com/conectomadev/homebrew-brainit/main/install.sh | bash
#
# Installs Bun if missing, downloads the brainit CLI package, fetches its
# runtime deps, and drops a `brainit` command on your PATH.
#
# Downloads come from the public GitHub release by default. Set BRAINIT_BASE_URL
# to front them behind your own domain (expects <base>/releases/<ver>/brainit-cli.tar.gz).
set -euo pipefail

REPO="conectomadev/homebrew-brainit"
BASE_URL="${BRAINIT_BASE_URL:-}"
VERSION="${BRAINIT_VERSION:-latest}"
PREFIX="${BRAINIT_PREFIX:-$HOME/.brainit}"
BIN_DIR="${BRAINIT_BIN_DIR:-$HOME/.local/bin}"

say() { printf '\033[1;35m▸\033[0m %s\n' "$1"; }
err() { printf '\033[1;31m✗\033[0m %s\n' "$1" >&2; exit 1; }

command -v curl >/dev/null 2>&1 || err "curl is required."
command -v tar  >/dev/null 2>&1 || err "tar is required."

# 1. Ensure Bun.
if ! command -v bun >/dev/null 2>&1 && [ ! -x "$HOME/.bun/bin/bun" ]; then
  say "Installing Bun (JavaScript runtime)…"
  curl -fsSL https://bun.sh/install | bash
fi
BUN="$(command -v bun || echo "$HOME/.bun/bin/bun")"
[ -x "$BUN" ] || err "Bun install failed; install it from https://bun.sh and re-run."

# 2. Resolve the package tarball URL.
if [ -n "$BASE_URL" ]; then
  # Self-hosted / domain-fronted.
  if [ "$VERSION" = "latest" ]; then
    URL="$BASE_URL/releases/latest/brainit-cli.tar.gz"
  else
    URL="$BASE_URL/releases/$VERSION/brainit-cli.tar.gz"
  fi
elif [ "$VERSION" = "latest" ]; then
  URL="https://github.com/$REPO/releases/latest/download/brainit-cli.tar.gz"
else
  URL="https://github.com/$REPO/releases/download/$VERSION/brainit-cli.tar.gz"
fi

# 3. Download + extract.
say "Downloading brainit ($VERSION)…"
rm -rf "$PREFIX"
mkdir -p "$PREFIX"
curl -fsSL "$URL" | tar -xzf - -C "$PREFIX"

# 4. Fetch runtime deps.
say "Installing runtime dependencies…"
( cd "$PREFIX" && "$BUN" install --production )

# 5. Drop the launcher.
mkdir -p "$BIN_DIR"
cat > "$BIN_DIR/brainit" <<SH
#!/usr/bin/env bash
exec "$BUN" "$PREFIX/cli/index.ts" "\$@"
SH
chmod 0755 "$BIN_DIR/brainit"

say "Installed: $BIN_DIR/brainit"
case ":$PATH:" in
  *":$BIN_DIR:"*) ;;
  *) printf '\033[1;33m!\033[0m Add %s to your PATH:\n    export PATH="%s:$PATH"\n' "$BIN_DIR" "$BIN_DIR" ;;
esac
say "Run it inside any repo:  brainit --yes"
