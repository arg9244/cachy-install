#!/bin/bash

# Install end-4 Hyprland dotfiles
# This script runs the end-4 dots-hyprland setup script

set -e  # Exit on error

echo "Installing end-4 Hyprland dotfiles..."

# Run the setup script directly from the URL
echo "Downloading and running end-4 setup script..."
bash <(curl -s "https://end-4.github.io/dots-hyprland-wiki/setup.sh")

echo "end-4 installation completed!"
