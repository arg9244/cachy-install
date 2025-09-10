#!/bin/bash

# Install caelestia dotfiles with zen browser
# This script clones the caelestia repository and runs the install script

set -e  # Exit on error

echo "Installing caelestia dotfiles..."

# Clone the repository to the recommended location
echo "Cloning caelestia repository..."
git clone https://github.com/caelestia-dots/caelestia.git ~/.local/share/caelestia

# Run the install script with noconfirm and zen options
echo "Running caelestia install script..."
~/.local/share/caelestia/install.fish --noconfirm --zen

echo "Caelestia installation completed!"
