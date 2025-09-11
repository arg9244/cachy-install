#!/usr/bin/env bash
set -euo pipefail

OWNER="koeqaife"
REPO="hyprland-material-you"
API_URL="https://api.github.com/repos/${OWNER}/${REPO}/releases/latest"
DEST_DIR="$HOME/HyprYou"
AUR_PACKAGES=(python-materialyoucolor-git libastal-bluetooth-git libastal-wireplumber-git ttf-material-symbols-variable-git)

# --- Functions ---
check_deps() {
    for cmd in curl jq paru; do
        command -v "$cmd" >/dev/null 2>&1 || { echo "❌ $cmd is required but not installed."; exit 1; }
    done
}

download_pkgs() {
    mkdir -p "$DEST_DIR"
    local urls
    urls=$(curl -sSL "$API_URL" | jq -r '.assets[] | select(.name | endswith("pkg.tar.zst")) | .browser_download_url')
    [ -z "$urls" ] && { echo "❌ No pkg.tar.zst assets found."; exit 1; }
    for url in $urls; do
        local filename="$DEST_DIR/$(basename "$url")"
        [ -f "$filename" ] || curl -L -o "$filename" "$url"
    done
}

install_aur_deps() {
    paru -S --needed --noconfirm "${AUR_PACKAGES[@]}"
}

install_main_pkgs() {
    sudo pacman -U --noconfirm "$DEST_DIR"/*.pkg.tar.zst
}

cleanup() {
    rm -rf "$DEST_DIR"
}

enable_greetd() {
    sudo systemctl enable greetd.service
}

ask_reboot() {
    read -rp "⚡ Reboot now? (y/N): " ans
    [[ "$ans" =~ ^[Yy] ]] && sudo reboot
}

# --- Main ---
check_deps
download_pkgs
install_aur_deps
install_main_pkgs
cleanup
enable_greetd
ask_reboot

echo "🎉 Setup complete!"
