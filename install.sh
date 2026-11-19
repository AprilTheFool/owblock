#!/bin/sh

set -eu

REPO="AprilTheFool/owblock"
BRANCH="main"
RAW_URL="${OWBLOCK_URL:-https://raw.githubusercontent.com/$REPO/$BRANCH}"

# ── output ──────────────────────────────────────────────────────────────────

if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
    O=$(printf '\033[38;2;249;158;26m') G=$(printf '\033[38;2;95;211;141m')
    R=$(printf '\033[38;2;255;92;92m')  D=$(printf '\033[38;2;107;122;137m')
    B=$(printf '\033[1m') N=$(printf '\033[0m')
else
    O= G= R= D= B= N=
fi
ok()   { printf ' %s●%s %s\n' "$G" "$N" "$*"; }
info() { printf ' %s·%s %s\n' "$D" "$N" "$*"; }
warn() { printf ' %s!%s %s\n' "$O" "$N" "$*"; }
die()  { printf ' %s✕%s %s\n' "$R" "$N" "$*" >&2; exit 1; }

# Ask a yes/no question. Reads from the terminal so it works under `curl | sh`.
ask() {
    [ "$YES" = 1 ] && return 0
    [ -r /dev/tty ] || return 1
    printf ' %s?%s %s [Y/n] ' "$O" "$N" "$1"
    read -r reply </dev/tty || return 1
    case "$reply" in [nN]*) return 1 ;; *) return 0 ;; esac
}

have() { command -v "$1" >/dev/null 2>&1; }

# ── arguments ───────────────────────────────────────────────────────────────

YES=0 SYSTEM=0 UNINSTALL=0
for arg in "$@"; do
    case "$arg" in
        -y|--yes) YES=1 ;;
        --system) SYSTEM=1 ;;
        --uninstall) UNINSTALL=1 ;;
        -h|--help)
            cat <<'EOF'
usage: install.sh [--system] [--uninstall] [--yes]

  (no options)   install for the current user (~/.local/bin)
  --system       install for all users (/usr/local/bin)
  --uninstall    remove owblock (add --system if installed that way)
  --yes          don't ask, assume yes

  BIN_DIR=/some/dir ./install.sh   install somewhere else
EOF
            exit 0 ;;
        *) die "unknown option: $arg" ;;
    esac
done

if [ "$(id -u)" = 0 ]; then
    SUDO=
elif have sudo; then
    SUDO=sudo
elif have doas; then
    SUDO=doas
else
    SUDO=
fi

if [ -n "${BIN_DIR:-}" ]; then
    :
elif [ "$SYSTEM" = 1 ]; then
    BIN_DIR=/usr/local/bin
else
    BIN_DIR="$HOME/.local/bin"
fi
TARGET="$BIN_DIR/owblock"

# Run a command as root when the target directory isn't writable by us.
as_needed() {
    if [ -w "$BIN_DIR" ] || { [ ! -e "$BIN_DIR" ] && [ "$SYSTEM" = 0 ]; }; then
        "$@"
    elif [ -n "$SUDO" ]; then
        $SUDO "$@"
    else
        die "no permission to write to $BIN_DIR (and no sudo/doas found)"
    fi
}

printf '\n %sowblock%s %sinstaller%s\n\n' "$B$O" "$N" "$D" "$N"

# ── uninstall ───────────────────────────────────────────────────────────────

if [ "$UNINSTALL" = 1 ]; then
    if [ -e "$TARGET" ] || [ -L "$TARGET" ]; then
        as_needed rm -f "$TARGET"
        ok "removed $TARGET"
    else
        info "$TARGET not found"
    fi
    if have nft && [ -n "$SUDO$(id -u | grep -x 0 || true)" ]; then
        if printf 'table inet owblock {}\ndelete table inet owblock\n' | $SUDO nft -f - 2>/dev/null; then
            ok "removed firewall rules"
        else
            warn "couldn't remove firewall rules; run: sudo nft delete table inet owblock"
        fi
    fi
    rm -rf "${XDG_CACHE_HOME:-$HOME/.cache}/owblock" && ok "removed cached server list"
    printf '\n'
    exit 0
fi

# ── dependencies ────────────────────────────────────────────────────────────

missing=""
if ! have python3 || ! python3 -c 'import sys; sys.exit(sys.version_info < (3, 6))' 2>/dev/null; then
    missing="$missing python"
fi
have nft  || [ -x /usr/sbin/nft ] || [ -x /sbin/nft ] || missing="$missing nftables"
have ping || missing="$missing ping"

if [ -n "$missing" ]; then
    warn "missing:$missing"

    # Map each missing piece to this distro's package name.
    pm="" pkgs=""
    if have pacman; then pm="pacman -S --needed";   py=python  pg=iputils
    elif have apt-get; then pm="apt-get install";   py=python3 pg=iputils-ping
    elif have dnf; then pm="dnf install";           py=python3 pg=iputils
    elif have zypper; then pm="zypper install";     py=python3 pg=iputils
    elif have apk; then pm="apk add";               py=python3 pg=iputils
    elif have xbps-install; then pm="xbps-install"; py=python3 pg=iputils
    fi
    for m in $missing; do
        case "$m" in
            python) pkgs="$pkgs $py" ;;
            nftables) pkgs="$pkgs nftables" ;;
            ping) pkgs="$pkgs $pg" ;;
        esac
    done

    if [ -z "$pm" ]; then
        die "install these with your package manager, then run this again:$missing"
    elif [ -z "$SUDO" ] && [ "$(id -u)" != 0 ]; then
        die "install them with: $pm$pkgs (as root), then run this again"
    elif ask "install them now with \`$pm$pkgs\`?"; then
        # shellcheck disable=SC2086
        $SUDO $pm $pkgs </dev/tty || die "package install failed"
        ok "installed$pkgs"
    else
        die "install them with: $SUDO $pm$pkgs, then run this again"
    fi
else
    ok "python3, nftables and ping found"
fi

if [ -z "$SUDO" ] && [ "$(id -u)" != 0 ]; then
    warn "no sudo or doas found: you'll need to run owblock as root"
fi

# ── install ─────────────────────────────────────────────────────────────────

# Use the script next to this installer if there is one (running from a
# clone), otherwise download it.
here=$(cd "$(dirname "$0")" 2>/dev/null && pwd || true)
tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT

case "$0" in
    *install.sh) src="$here/owblock" ;;
    *) src="" ;;
esac

if [ -n "$src" ] && [ -f "$src" ]; then
    cp "$src" "$tmp"
    info "using $src"
else
    url="$RAW_URL/owblock"
    if have curl; then
        curl -fsSL "$url" -o "$tmp" || die "download failed: $url"
    elif have wget; then
        wget -qO "$tmp" "$url" || die "download failed: $url"
    else
        die "need curl or wget to download owblock"
    fi
    info "downloaded $url"
fi
head -n 1 "$tmp" | grep -q python3 || die "that doesn't look like the owblock script"

as_needed mkdir -p "$BIN_DIR"
as_needed install -m 755 "$tmp" "$TARGET"
ok "installed to $TARGET"

# Fetch the server list now so the first run is instant.
"$TARGET" update >/dev/null 2>&1 && ok "downloaded server list" \
    || warn "couldn't download the server list yet; owblock will retry when you run it"

# ── PATH ────────────────────────────────────────────────────────────────────

case ":$PATH:" in
    *":$BIN_DIR:"*) ;;
    *)
        warn "$BIN_DIR isn't on your PATH"
        case "${SHELL:-}" in
            */fish) info "add it with:  fish_add_path $BIN_DIR" ;;
            */zsh)  info "add it with:  echo 'export PATH=\"$BIN_DIR:\$PATH\"' >> ~/.zshrc" ;;
            *)      info "add it with:  echo 'export PATH=\"$BIN_DIR:\$PATH\"' >> ~/.bashrc" ;;
        esac
        info "then open a new terminal"
        ;;
esac

printf '\n %sdone!%s run %sowblock list%s to get started\n\n' "$G" "$N" "$B" "$N"
