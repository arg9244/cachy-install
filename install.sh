#!/bin/bash
# CachyOS Fresh Install Setup Script

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
print_status(){ echo -e "${GREEN}[INFO]${NC} $1"; }
print_warning(){ echo -e "${YELLOW}[WARN]${NC} $1"; }
print_error(){ echo -e "${RED}[ERROR]${NC} $1"; }

# -------------------
# PRECHECKS
# -------------------
[[ $EUID -eq 0 ]] && print_error "Do not run as root" && exit 1
ping -c1 archlinux.org &>/dev/null || { print_error "No internet"; exit 1; }

# Ensure sudo
command -v sudo &>/dev/null || { print_error "sudo required"; exit 1; }

# -------------------
# PACMAN CONFIG
# -------------------
sudo cp /etc/pacman.conf /etc/pacman.conf.backup 2>/dev/null || print_warning "Backup failed"
grep -q "^ParallelDownloads" /etc/pacman.conf && sudo sed -i 's/^ParallelDownloads.*/ParallelDownloads = 10/' /etc/pacman.conf || sudo sed -i '/^#ParallelDownloads/a ParallelDownloads = 10' /etc/pacman.conf
sudo sed -i 's/^#Color/Color/' /etc/pacman.conf
grep -q "^ILoveCandy" /etc/pacman.conf || sudo sed -i '/^Color/a ILoveCandy' /etc/pacman.conf

# -------------------
# REFLECTOR
# -------------------
print_status "✓ Installing reflector and optimizing mirrors..."
if ! command -v reflector &>/dev/null; then
    sudo pacman -S --needed --noconfirm reflector
    print_status "Reflector installed successfully"
else
    print_status "Reflector is already installed"
fi

sudo cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.backup 2>/dev/null
print_status "Finding fastest mirrors with reflector..."
print_warning "This may take a few minutes depending on your connection..."
sudo reflector \
    --latest 20 \
    --protocol https \
    --sort rate \
    --fastest 10 \
    --threads 4 \
    --connection-timeout 3 \
    --download-timeout 5 \
    --save /etc/pacman.d/mirrorlist

# Verify mirrorlist
if [ ! -s /etc/pacman.d/mirrorlist ]; then
    print_warning "Mirrorlist is empty! Restoring backup..."
    sudo cp /etc/pacman.d/mirrorlist.backup /etc/pacman.d/mirrorlist
else
    print_status "Updated mirrorlist saved to /etc/pacman.d/mirrorlist"
fi

print_status "Updating package database..."
sudo pacman -Sy --noconfirm

# -------------------
# HELPER FUNCTIONS
# -------------------
filter_installed_packages(){
    local packages=("$@"); FILTERED_PACKAGES=()
    for pkg in "${packages[@]}"; do pacman -Qi "$pkg" &>/dev/null || FILTERED_PACKAGES+=("$pkg"); done
}
install_packages(){
    local group_name="$1"; shift; filter_installed_packages "$@"
    [ ${#FILTERED_PACKAGES[@]} -gt 0 ] && sudo pacman -S --needed --noconfirm "${FILTERED_PACKAGES[@]}" && print_status "$group_name installed" || print_status "All $group_name already installed"
}
append_fstab_line(){ local line="$1"; grep -qxF "$line" /etc/fstab || echo "$line" | sudo tee -a /etc/fstab > /dev/null; }
prompt_yes_no(){
    local msg="$1" default="$2" reply
    while true; do
        read -rp "$msg " reply
        [[ -z "$reply" ]] && reply="$default"
        case $reply in [Yy]*) return 0;; [Nn]*) return 1;; *) print_warning "y/n only";; esac
    done
}
run_rice(){ local url="$1"; curl -fsSL "$url" | bash || print_warning "Rice failed: $url"; }

# -------------------
# ESSENTIAL PACKAGES
# -------------------
essential_packages=(git github-cli chezmoi nano micro fastfetch starship wget ntfs-3g baobab file-roller mpv transmission-cli transmission-remote-gtk neovim ripgrep gdu bottom nodejs lazygit python tree-sitter yazi kitty zen-browser-bin telegram-desktop ttf-jetbrains-mono-nerd qt5ct qt6ct kvantum kvantum-qt5)
install_packages "Essential packages" "${essential_packages[@]}"
pacman -Qi transmission-cli &>/dev/null && sudo systemctl enable transmission.service

# -------------------
# AUTOMOUNT
# -------------------
sudo cp /etc/fstab /etc/fstab.backup
sudo mkdir -p /mnt/C /mnt/D /mnt/E
[[ -b /dev/sda1 ]] && append_fstab_line "/dev/sda1 /mnt/D auto defaults,nofail 0 0"
[[ -b /dev/sdb3 ]] && append_fstab_line "/dev/sdb3 /mnt/E auto defaults,nofail 0 0"
[[ -b /dev/nvme0n1p3 ]] && append_fstab_line "/dev/nvme0n1p3 /mnt/C auto defaults,nofail 0 0"
pacman -Qi ntfs-3g &>/dev/null && sudo mount -a

# -------------------
# ENVIRONMENT VARIABLES
# -------------------
grep -q "^AMD_VULKAN_ICD=" /etc/environment || echo "AMD_VULKAN_ICD=RADV" | sudo tee -a /etc/environment
grep -q "^MESA_SHADER_CACHE_MAX_SIZE=" /etc/environment || echo "MESA_SHADER_CACHE_MAX_SIZE=12G" | sudo tee -a /etc/environment

# -------------------
# OPTIONAL PACKAGES
# -------------------
gaming_packages=(cachyos-gaming-meta gamescope goverlay lutris)
prompt_yes_no "Install gaming packages? [y/N]:" "n" && install_packages "Gaming packages" "${gaming_packages[@]}"

gnome_packages=(gdm gnome-control-center extension-manager loupe resources gnome-calendar gnome-weather ghostty)
gnome_choice="n"
if prompt_yes_no "Install minimal GNOME? [y/N]:" "n"; then
    gnome_choice="y"
    install_packages "GNOME packages" "${gnome_packages[@]}"
    pacman -Qi gdm &>/dev/null && sudo systemctl enable gdm.service
fi

[[ "$gnome_choice" != "y" ]] && prompt_yes_no "Install and enable SDDM? [y/N]:" "n" && { pacman -Qi sddm &>/dev/null || sudo pacman -S --needed --noconfirm sddm; pacman -Qi sddm &>/dev/null && sudo systemctl enable sddm.service; }

# -------------------
# DOTFILES
# -------------------
command -v chezmoi &>/dev/null && chezmoi init --apply https://github.com/arg9244/dotfiles.git || print_warning "chezmoi missing"

# -------------------
# RICE SCRIPTS
# -------------------
sudo mount -a
if prompt_yes_no "Do you rice?" "n"; then
    echo -e "1. caelestia\n2. end-4\n3. gh0stzk\n4. hypryou\n"
    read -rp "Enter choice [1-4]: " rice_choice
    case $rice_choice in
        1) run_rice https://github.com/arg9244/cachy-install/raw/main/rice/caelestia.sh ;;
        2) run_rice https://github.com/arg9244/cachy-install/raw/main/rice/end-4.sh ;;
        3) run_rice https://github.com/arg9244/cachy-install/raw/main/rice/gh0stzk.sh ;;
        4) run_rice https://github.com/arg9244/cachy-install/raw/main/rice/hypryou.sh ;;
        *) print_warning "Invalid rice choice" ;;
    esac
fi

print_status "CachyOS setup script completed successfully!"
print_status "Pacman configured with 10 parallel downloads, fastest mirrors, color, and ILoveCandy"
print_status "Automount configured for /mnt/C, /mnt/D, /mnt/E"
print_warning "Backups: /etc/pacman.conf.backup, /etc/pacman.d/mirrorlist.backup, /etc/fstab.backup"
