#!/bin/bash

# Install gh0stzk dotfiles
# This script downloads and runs the gh0stzk rice installer

set -e  # Exit on error

echo "Installing gh0stzk dotfiles..."

# Change to HOME directory to download the installer
cd "$HOME"

# Download the installer
echo "Downloading RiceInstaller..."
curl -LO http://gh0stzk.github.io/dotfiles/RiceInstaller

# Give it execution permission
echo "Setting execution permissions..."
chmod +x RiceInstaller

# Run the installer
echo "Running RiceInstaller..."
./RiceInstaller

echo "gh0stzk installation completed!"
