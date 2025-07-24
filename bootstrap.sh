
#!/bin/bash

echo "Running thomascwells/bootstrap script..."

# Git autocompletion ----- 

# Create directory for bash completions if it doesn't exist
mkdir -p "$HOME/.bash_completion.d"

# Get installed git version
GIT_VERSION=$(git --version | awk '{print $3}')

# Download git completion script for the installed version
echo "Setting up git completion for git version $GIT_VERSION..."
curl -s -o "$HOME/.bash_completion.d/git-completion.bash" \
  "https://raw.githubusercontent.com/git/git/v$GIT_VERSION/contrib/completion/git-completion.bash"

# Check if download was successful
if [ ! -s "$HOME/.bash_completion.d/git-completion.bash" ]; then
  echo "Warning: Failed to download git-completion.bash. Trying master branch..."
  curl -s -o "$HOME/.bash_completion.d/git-completion.bash" \
    "https://raw.githubusercontent.com/git/git/master/contrib/completion/git-completion.bash"
fi

# Add git-complete sourcing to .bashrc
if ! grep -q "source.*git-completion.bash" "$HOME/.bashrc"; then
  echo "Adding git completion to .bashrc..."
  echo "" >> "$HOME/.bashrc"
  echo "# Git autocompletion" >> "$HOME/.bashrc"
  echo "if [ -f \$HOME/.bash_completion.d/git-completion.bash ]; then" >> "$HOME/.bashrc"
  echo "  source \$HOME/.bash_completion.d/git-completion.bash" >> "$HOME/.bashrc"
  echo "fi" >> "$HOME/.bashrc"
fi

# Source the git completion script  
source "$HOME/.bash_completion.d/git-completion.bash"

# Ensure ~/.local/bin exists
mkdir -p "$HOME/.local/bin"

# Add ~/.local/bin to PATH if not already there
if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
  echo "Adding ~/.local/bin to PATH in .bashrc..."
  echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
  export PATH="$HOME/.local/bin:$PATH"
fi

# Install lazy git ---- 

# Check if lazygit is already installed
if command -v lazygit &> /dev/null; then
  echo "lazygit is already installed at $(which lazygit), version $(lazygit --version 2>&1 | grep -o 'version=.*' | cut -d= -f2)"
else
  # Install lazygit
  echo "lazygit not found. Installing..."
  LAZYGIT_VERSION=$(curl -s "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" | grep '"tag_name":' | sed -E 's/.*"v([^"]+)".*/\1/')

  if [ -z "$LAZYGIT_VERSION" ]; then
    echo "Error: Failed to get latest lazygit version. Check your internet connection."
    exit 1
  fi

  echo "Downloading lazygit version ${LAZYGIT_VERSION}..."
  curl -Lo lazygit.tar.gz "https://github.com/jesseduffield/lazygit/releases/latest/download/lazygit_${LAZYGIT_VERSION}_Linux_x86_64.tar.gz"

  if [ $? -ne 0 ] || [ ! -s lazygit.tar.gz ]; then
    echo "Error: Failed to download lazygit."
    exit 1
  fi

  tar xf lazygit.tar.gz lazygit
  echo "Installing lazygit to $HOME/.local/bin/"
  mv lazygit "$HOME/.local/bin/"
  chmod +x "$HOME/.local/bin/lazygit"
  rm lazygit.tar.gz

  # Verify installation
  if command -v lazygit &> /dev/null; then
    echo "lazygit installed successfully!"
  else
    echo "Installation failed. Please check if $HOME/.local/bin is in your PATH."
  fi
fi

# GPG Configuration for Git Signing ----

# Ensure GPG directory exists with proper permissions
mkdir -p "$HOME/.gnupg"
chmod 700 "$HOME/.gnupg"

# Configure GPG agent for better passphrase caching
GPG_AGENT_CONF="$HOME/.gnupg/gpg-agent.conf"
if [ ! -f "$GPG_AGENT_CONF" ]; then
    echo "Configuring GPG agent for better passphrase handling..."
    cat > "$GPG_AGENT_CONF" << 'EOF'
# GPG Agent configuration for better passphrase handling

# Cache passphrases for 8 hours (28800 seconds)
default-cache-ttl 28800
# Maximum cache time is 24 hours (86400 seconds)  
max-cache-ttl 86400

# Use curses-based pinentry for terminal compatibility
pinentry-program /usr/bin/pinentry-curses

# Allow loopback pinentry for programmatic access
allow-loopback-pinentry
EOF
    
    # Reload GPG agent with new configuration
    gpgconf --reload gpg-agent 2>/dev/null || true
    echo "GPG agent configured for better passphrase caching"
fi

# Set up GPG_TTY for terminal signing
if ! grep -q "export GPG_TTY" "$HOME/.bashrc"; then
    echo "Adding GPG_TTY configuration to .bashrc..."
    echo "" >> "$HOME/.bashrc"
    echo "# GPG configuration for signing" >> "$HOME/.bashrc"
    echo "export GPG_TTY=\$(tty)" >> "$HOME/.bashrc"
fi

# Export GPG_TTY for current session
export GPG_TTY=$(tty)

# VSCode Extensions Installation for GitHub Codespaces --- 

# Check if we're in a Codespace or have VSCode available
if ! command -v code &> /dev/null; then
    echo "VSCode CLI not available, skipping extension installation"
else
    # Create a marker file to prevent repeated extension installations
    VSCODE_SETUP_MARKER="$HOME/.vscode_extensions_installed"
    
    if [ -f "$VSCODE_SETUP_MARKER" ]; then
        echo "VSCode extensions already installed (marker file exists)"
    else
        echo "Installing VSCode extensions..."
        
        # Define extensions to install
        extensions=(
            "mhutchie.git-graph"
            "ritwickdey.LiveServer"
            "DavidAnson.vscode-markdownlint"
        )
        
        installed_count=0
        failed_count=0
        
        for extension in "${extensions[@]}"; do
            # Check if extension is already installed
            if code --list-extensions | grep -q "^$extension$"; then
                echo "$extension is already installed"
                ((installed_count++))
            else
                echo "Installing $extension..."
                if code --install-extension "$extension" --force; then
                    echo "Successfully installed $extension"
                    ((installed_count++))
                else
                    echo "Failed to install $extension"
                    ((failed_count++))
                fi
            fi
        done
        
        echo "Extension installation complete: $installed_count installed, $failed_count failed"
        
        # Create marker file to prevent future installations
        touch "$VSCODE_SETUP_MARKER"
        echo "Created marker file to prevent repeated extension installations"
        
        # Only suggest reload if we actually installed new extensions
        if [ $failed_count -eq 0 ] && [ $installed_count -gt 0 ]; then
            echo "Extensions installed successfully. You may need to reload VSCode window to activate new extensions."
            echo "You can reload by pressing F1 and typing 'Reload Window'"
        fi
    fi
fi


echo "Setup complete!"
