
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


# VSCode Extensions Installation for GitHub Codespaces --- 

echo "Installing VSCode extensions..."

# Wait for VSCode Server to be available
echo "Waiting for VSCode Server to initialize..."
max_attempts=30
attempt=0

while [ $attempt -lt $max_attempts ]; do
    if command -v code &> /dev/null; then
        echo "VSCode Server is ready!"
        break
    fi
    echo "Waiting... (attempt $((attempt + 1))/$max_attempts)"
    sleep 2
    ((attempt++))
done

if [ $attempt -eq $max_attempts ]; then
    echo "Error: VSCode Server did not become available"
    exit 1
fi

# Now install extensions
extensions=(
    "mhutchie.git-graph"
    "ritwickdey.LiveServer"
    "DavidAnson.vscode-markdownlint"
)

for extension in "${extensions[@]}"; do
    echo "Installing $extension..."
    code --install-extension "$extension" --force
done


echo "Setup complete!"
