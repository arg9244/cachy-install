#!/bin/bash

# CachyOS Fresh Install Setup Script
# Configures a minimal CachyOS installation that boots to TTY

set -e

echo "Starting CachyOS TTY setup script..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   print_error "This script must be run as root (use sudo)"
   exit 1
fi

print_status "Configuring pacman for optimal performance..."

# Backup original pacman.conf
cp /etc/pacman.conf /etc/pacman.conf.backup
print_status "Backed up original pacman.conf to /etc/pacman.conf.backup"

# Enable 16 parallel downloads in pacman.conf
if grep -q "^ParallelDownloads" /etc/pacman.conf; then
    sed -i 's/^ParallelDownloads.*/ParallelDownloads = 16/' /etc/pacman.conf
    print_status "Updated ParallelDownloads to 16"
else
    # Add ParallelDownloads if it doesn't exist
    sed -i '/^#ParallelDownloads/a ParallelDownloads = 16' /etc/pacman.conf
    print_status "Added ParallelDownloads = 16 to pacman.conf"
fi

# Enable Color if not already enabled
if ! grep -q "^Color" /etc/pacman.conf; then
    sed -i 's/^#Color/Color/' /etc/pacman.conf
    print_status "Enabled colored output in pacman"
fi

# Enable ILoveCandy if not already enabled
if ! grep -q "^ILoveCandy" /etc/pacman.conf; then
    sed -i '/^Color/a ILoveCandy' /etc/pacman.conf
    print_status "Enabled progress bar candy in pacman"
fi

print_status "Installing reflector for mirror optimization..."

# Install reflector if not already installed
if ! command -v reflector &> /dev/null; then
    pacman -S --noconfirm reflector
    print_status "Reflector installed successfully"
else
    print_status "Reflector is already installed"
fi

print_status "Backing up current mirrorlist..."
cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.backup

print_status "Finding fastest mirrors with reflector..."
print_warning "This may take up to 30 seconds..."

# Run reflector with specified parameters:
# --latest 20: Use the 20 most recently synchronized mirrors
# --protocol https: Only use HTTPS mirrors
# --sort rate: Sort by download rate
# --save: Save to mirrorlist
# --connection-timeout 3: 3 second timeout for connections
# --download-timeout 30: 30 second total timeout
reflector --latest 20 \
          --protocol https \
          --sort rate \
          --save /etc/pacman.d/mirrorlist \
          --connection-timeout 3 \
          --download-timeout 30

if [ $? -eq 0 ]; then
    print_status "Mirror optimization completed successfully"
    print_status "Updated mirrorlist saved to /etc/pacman.d/mirrorlist"
else
    print_error "Mirror optimization failed, restoring backup"
    cp /etc/pacman.d/mirrorlist.backup /etc/pacman.d/mirrorlist
    exit 1
fi

print_status "Updating package database with new mirrors..."
pacman -Sy

print_status "Configuring fstab to automount specified drives..."

# Backup /etc/fstab
cp /etc/fstab /etc/fstab.backup
print_status "Backed up /etc/fstab to /etc/fstab.backup"

# Ensure mount points exist
mkdir -p /mnt/C /mnt/D /mnt/E
print_status "Ensured mount points exist: /mnt/C /mnt/D /mnt/E"

# Helper to append a line to fstab if it doesn't already exist
append_fstab_line() {
    local line="$1"
    local escaped=$(printf '%s\n' "$line" | sed 's/[\&/]/\\&/g')
    if grep -qxF "$line" /etc/fstab; then
        print_warning "Entry already present in /etc/fstab: $line"
    else
        echo "$line" >> /etc/fstab
        print_status "Added to /etc/fstab: $line"
    fi
}

append_fstab_line "/dev/sda1    /mnt/D    auto    defaults,nofail    0 0"
append_fstab_line "/dev/sdb3    /mnt/E    auto    defaults,nofail    0 0"
append_fstab_line "/dev/nvme0n1p3    /mnt/C    auto    defaults,nofail    0 0"

print_status "Testing fstab by mounting all entries..."
if mount -a; then
    print_status "fstab entries mounted successfully"
else
    print_error "mount -a failed. Restoring /etc/fstab from backup."
    cp /etc/fstab.backup /etc/fstab
    exit 1
fi

print_status "Configuring environment variables for AMD GPU optimization..."

# Edit /etc/environment to add AMD optimization variables
if ! grep -q "^AMD_VULKAN_ICD=" /etc/environment; then
    echo "AMD_VULKAN_ICD=RADV" | tee -a /etc/environment > /dev/null
    print_status "Added AMD_VULKAN_ICD=RADV to /etc/environment"
fi

if ! grep -q "^MESA_SHADER_CACHE_MAX_SIZE=" /etc/environment; then
    echo "MESA_SHADER_CACHE_MAX_SIZE=12G" | tee -a /etc/environment > /dev/null
    print_status "Added MESA_SHADER_CACHE_MAX_SIZE=12G to /etc/environment"
fi

print_status "Installing essential packages..."

# Define essential packages array
essential_packages=(
    git
    github-cli
    chezmoi
    nano
    fastfetch
    wget
    ntfs-3g
    baobab
    file-roller
    mpv
    transmission-cli
    transmission-remote-gtk
    neovim
    ripgrep
    gdu
    bottom
    nodejs
    lazygit
    python
    tree-sitter
    yazi
    kitty
    zen-browser-bin
    ttf-jetbrains-mono-nerd
    ttf-meslo-nerd
)

print_status "Installing ${#essential_packages[@]} essential packages..."
print_warning "This may take several minutes depending on your internet connection..."

# Install essential packages
if pacman -S --noconfirm "${essential_packages[@]}"; then
    print_status "Essential packages installed successfully"
else
    print_error "Failed to install some essential packages"
    print_error "You may need to install them manually later"
fi

# Optional package groups
print_status "Optional package installation..."

# Gaming packages
gaming_packages=(
    cachyos-gaming-meta
    gamescope
    goverlay
    lutris
)

echo -e "\n${YELLOW}[OPTIONAL]${NC} Install gaming packages?"
echo "Packages: ${gaming_packages[*]}"
read -p "Install gaming packages? [y/N]: " -r gaming_choice

if [[ $gaming_choice =~ ^[Yy]$ ]]; then
    print_status "Installing gaming packages..."
    if pacman -S --noconfirm "${gaming_packages[@]}"; then
        print_status "Gaming packages installed successfully"
    else
        print_error "Failed to install some gaming packages"
    fi
else
    print_status "Skipped gaming packages installation"
fi

# Minimal GNOME Desktop Environment (optional)
gnome_packages=(
    gdm
    gnome-control-center
    extension-manager
    loupe
    resources
    gnome-calendar
    gnome-weather
)

echo -e "\n${YELLOW}[OPTIONAL]${NC} Install minimal GNOME desktop environment?"
echo "Packages: ${gnome_packages[*]}"
read -p "Install minimal GNOME? [y/N]: " -r gnome_choice

if [[ $gnome_choice =~ ^[Yy]$ ]]; then
    print_status "Installing minimal GNOME desktop environment packages..."
    if pacman -S --noconfirm "${gnome_packages[@]}"; then
        print_status "Minimal GNOME packages installed successfully"
        # Per user rule: only enable gdm when GNOME is selected
        if systemctl enable gdm.service; then
            print_status "Enabled gdm.service to start at boot"
        else
            print_warning "Could not enable gdm.service. You may need to enable it manually."
        fi
    else
        print_error "Failed to install some GNOME packages"
    fi
else
    print_status "Skipped GNOME installation"
fi

# SDDM Display Manager (optional) - only offer if GNOME wasn't selected
if [[ ! $gnome_choice =~ ^[Yy]$ ]]; then
    echo -e "\n${YELLOW}[OPTIONAL]${NC} Install and enable SDDM display manager?"
    echo "Package: sddm"
    print_warning "Note: SDDM themes may not apply correctly on some systems"
    read -p "Install and enable SDDM? [y/N]: " -r sddm_choice
    
    if [[ $sddm_choice =~ ^[Yy]$ ]]; then
        print_status "Installing SDDM display manager..."
        if pacman -S --noconfirm sddm; then
            print_status "SDDM installed successfully"
            if systemctl enable sddm.service; then
                print_status "Enabled sddm.service to start at boot"
            else
                print_warning "Could not enable sddm.service. You may need to enable it manually."
            fi
        else
            print_error "Failed to install SDDM"
        fi
    else
        print_status "Skipped SDDM installation"
    fi
else
    print_status "Skipped SDDM (GNOME with GDM was selected)"
fi

# Apply dotfiles with chezmoi
print_status "Setting up dotfiles with chezmoi..."
print_warning "This will apply dotfiles from https://github.com/arg9244/dotfiles.git to your home directory"

# Get the actual user (not root) to apply dotfiles to their home
if [ "$SUDO_USER" ]; then
    ACTUAL_USER="$SUDO_USER"
    USER_HOME="$(eval echo ~$SUDO_USER)"
else
    print_error "Could not determine the actual user. Dotfiles setup skipped."
    print_error "Run 'chezmoi init --apply https://github.com/arg9244/dotfiles.git' manually as your user later."
    ACTUAL_USER=""
fi

if [ "$ACTUAL_USER" ]; then
    print_status "Applying dotfiles for user: $ACTUAL_USER to $USER_HOME"
    if sudo -u "$ACTUAL_USER" chezmoi init --apply https://github.com/arg9244/dotfiles.git; then
        print_status "Dotfiles applied successfully with chezmoi"
    else
        print_error "Failed to apply dotfiles with chezmoi"
        print_warning "You can manually run: chezmoi init --apply https://github.com/arg9244/dotfiles.git"
    fi
fi

print_status "CachyOS setup script completed successfully!"
print_status "Pacman is now configured with:"
print_status "  - 16 parallel downloads"
print_status "  - Fastest available mirrors"
print_status "  - Colored output and progress bars"
print_status "System is now configured to automount:"
print_status "  - /dev/sda1 -> /mnt/D"
print_status "  - /dev/sdb3 -> /mnt/E"
print_status "  - /dev/nvme0n1p3 -> /mnt/C"
print_warning "Original files backed up as:"
print_warning "  - /etc/pacman.conf.backup"
print_warning "  - /etc/pacman.d/mirrorlist.backup"
print_warning "  - /etc/fstab.backup"
