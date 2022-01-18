#!/bin/sh

echo "Setting up your WSL..."

# Configure Git
ln -s ~/.dotfiles/.gitconfig ~/.gitconfig
ln -s ~/.dotfiles/.zshrc ~/.zshrc

# Copy SSH folder from Windows Installation
cp -r /mnt/c/Users/liam/.ssh ~/.ssh

# Add SSH Private Key to SSH-Agent
ssh-add ~/.ssh/id_ed25519

sudo apt update
sudo apt upgrade -y
sudo apt install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg-agent \
    software-properties-common \
    git \
    make \
    tig \
    tree \
    zip unzip \
    zsh


echo "Installing Microsoft GPG Keys..."
wget -q https://packages.microsoft.com/config/ubuntu/20.04/packages-microsoft-prod.deb
sudo dpkg -i packages-microsoft-prod.deb
sudo apt-get update
sudo apt-get install -y powershell

echo "Installing the Azure CLI..."
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

echo "Installing DotNet..."
sudo apt-get install -y dotnet-sdk-6.0
sudo apt-get install -y nuget

# TODO This bicep script is kinda dumb - the install isn't idempotent
echo "Installing Azure Bicep..."
# Fetch the latest Bicep CLI binary
curl -Lo bicep https://github.com/Azure/bicep/releases/latest/download/bicep-linux-x64
# Mark it as executable
chmod +x ./bicep
# Add bicep to your PATH (requires admin)
sudo mv ./bicep /usr/local/bin/bicep

rm -f packages-microsoft-prod.deb

echo "Installing Terraform..."
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
sudo apt-add-repository "deb [arch=$(dpkg --print-architecture)] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
sudo apt install terraform

echo "Installing NodeJS and NPM..."
sudo apt install -y nodejs
sudo apt install -y npm

#Rust installer and WASM are currently interactive installers so not suitable until I find an alternative
# echo "Installing Rust and Web Assembly..."
# curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
# curl https://rustwasm.github.io/wasm-pack/installer/init.sh -sSf | sh

echo "Installing Ruby..."
sudo apt-get install -y ruby-full

echo "Installing Go Programming Language..."
sudo apt install -y golang-go

echo "Installing Typescript via NPM..."
sudo npm install -g typescript

echo "Installing Vue.JS"
sudo npm install -g vue@next

echo "Installing ZSH..."
sudo apt install -y zsh
chsh -s $(which zsh)

echo "Installing oh-my-zsh..."
sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

echo "Installing Keybase..."
curl --remote-name https://prerelease.keybase.io/keybase_amd64.deb
sudo apt install -y ./keybase_amd64.deb
rm -f keybase_amd64.deb
run_keybase