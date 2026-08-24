#!/usr/bin/env bash
# =============================================================================
# HYPRLAND + ARCH LINUX + LY DISPLAY MANAGER AUTOMATED INSTALLER
# Repository: https://github.com/arhymethic/dotfiles
# =============================================================================

set -e

# --- Colors for Output ---
BOLD='\033[1m'
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# --- Helper Logging Functions ---
log_info() {
    echo -e "${BLUE}${BOLD}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}${BOLD}[OK]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}${BOLD}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}${BOLD}[ERROR]${NC} $1"
}

# --- Cleanup Trap ---
cleanup() {
    if [ -n "${SUDO_PID:-}" ]; then
        kill "$SUDO_PID" 2>/dev/null || true
    fi
}
trap cleanup EXIT INT TERM

# --- Banner ---
clear
echo -e "${CYAN}${BOLD}"
cat << "BANNER"
  ____       _    __ _ _           
 |  _ \  ___| |_ / _(_) | ___  ___ 
 | | | |/ _ \ __| |_| | |/ _ \/ __|
 | |_| | (_) | |_|  _| | |  __/\__ \
 |____/ \___/ \__|_| |_|_|\___||___/
  Hyprland + Arch Linux + Ly Manager
BANNER
echo -e "${NC}"
echo -e "${BOLD}Target Environment:${NC} Arch Linux (Fresh install / archinstall)"
echo -e "${BOLD}Repository:${NC} https://github.com/arhymethic/dotfiles"
echo "------------------------------------------------------------------"

# --- 1. Pre-flight Checks ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ "$EUID" -eq 0 ]; then
    log_error "Please do NOT run this script directly as root or with sudo."
    log_error "Run it as your normal user: ./install.sh"
    exit 1
fi

if [ ! -f /etc/arch-release ]; then
    log_error "This script is designed specifically for Arch Linux."
    exit 1
fi

log_info "Verifying sudo permissions..."
sudo -v
# Keep sudo alive in background during installation
(while true; do sudo -n true; sleep 50; kill -0 "$$" || exit; done 2>/dev/null) &
SUDO_PID=$!

# --- 2. System Update ---
log_info "Step 1/8: Synchronizing databases and updating system packages..."
sudo pacman -Syu --noconfirm

# --- 3. Base Developer Tools ---
log_info "Step 2/8: Ensuring base-devel and git are installed..."
sudo pacman -S --needed --noconfirm base-devel git wget curl

# --- 4. AUR Helper (yay) Installation ---
log_info "Step 3/8: Checking AUR helper (yay)..."
if ! command -v yay &>/dev/null; then
    log_info "Installing yay-bin from AUR..."
    TEMP_DIR=$(mktemp -d)
    git clone https://aur.archlinux.org/yay-bin.git "$TEMP_DIR/yay-bin"
    (
        cd "$TEMP_DIR/yay-bin"
        makepkg -si --noconfirm
    )
    rm -rf "$TEMP_DIR"
    log_success "yay installed successfully."
else
    log_success "yay is already installed."
fi

# --- 5. Install Pacman & AUR Packages ---
log_info "Step 4/8: Installing official repository packages..."
if [ -f "$SCRIPT_DIR/packages-pacman.txt" ]; then
    grep -v '^#' "$SCRIPT_DIR/packages-pacman.txt" | grep -v '^[[:space:]]*$' | xargs -r sudo pacman -S --needed --noconfirm
    log_success "Official packages installed."
else
    log_warn "packages-pacman.txt not found, skipping official package batch install."
fi

log_info "Step 5/8: Installing AUR packages..."
if [ -f "$SCRIPT_DIR/packages-aur.txt" ]; then
    grep -v '^#' "$SCRIPT_DIR/packages-aur.txt" | grep -v '^[[:space:]]*$' | xargs -r yay -S --needed --noconfirm
    log_success "AUR packages installed."
else
    log_warn "packages-aur.txt not found, skipping AUR package batch install."
fi

# --- 6. Oh-My-Zsh & Shell Initialization ---
log_info "Step 6/8: Preparing Zsh & Oh-My-Zsh environment..."
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    log_info "Installing Oh-My-Zsh (unattended)..."
    RUNZSH=no CHSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi

ZSH_SUGG_DIR="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-autosuggestions"
if [ ! -d "$ZSH_SUGG_DIR" ]; then
    log_info "Installing zsh-autosuggestions plugin..."
    git clone https://github.com/zsh-users/zsh-autosuggestions "$ZSH_SUGG_DIR"
fi

# --- 7. Backup & Deploy Configurations ---
log_info "Step 7/8: Deploying dotfiles and wallpapers with safe backups..."
BACKUP_TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="$HOME/.config_backup_$BACKUP_TIMESTAMP"

mkdir -p "$HOME/.config"

# Deploy .config folders
if [ -d "$SCRIPT_DIR/.config" ]; then
    for cfg in "$SCRIPT_DIR/.config"/*; do
        [ -e "$cfg" ] || continue
        cfg_name=$(basename "$cfg")
        target_path="$HOME/.config/$cfg_name"
        
        if [ -e "$target_path" ]; then
            mkdir -p "$BACKUP_DIR"
            log_info "Backing up existing ~/.config/$cfg_name to $BACKUP_DIR/"
            mv "$target_path" "$BACKUP_DIR/"
        fi
        
        cp -r "$cfg" "$target_path"
    done
    log_success "All .config directories deployed."
fi

# Deploy home dotfiles (deployed AFTER Oh-My-Zsh to preserve custom .zshrc)
if [ -d "$SCRIPT_DIR/home" ]; then
    for hf in "$SCRIPT_DIR/home"/.??* "$SCRIPT_DIR/home"/*; do
        [ -e "$hf" ] || continue
        hf_name=$(basename "$hf")
        [ "$hf_name" = "*" ] && continue
        target_file="$HOME/$hf_name"
        
        if [ -e "$target_file" ]; then
            mkdir -p "$BACKUP_DIR/home"
            mv "$target_file" "$BACKUP_DIR/home/"
        fi
        
        cp -r "$hf" "$target_file"
    done
    log_success "Home configuration files (.bashrc, .zshrc, .dir_colors, .inputrc) deployed."
fi

# Deploy Wallpapers
log_info "Deploying wallpapers to $HOME/Wallpapers..."
mkdir -p "$HOME/Wallpapers"
if [ -d "$SCRIPT_DIR/Wallpapers" ]; then
    cp -rn "$SCRIPT_DIR/Wallpapers"/* "$HOME/Wallpapers/" 2>/dev/null || cp -r "$SCRIPT_DIR/Wallpapers"/* "$HOME/Wallpapers/"
    log_success "Wallpapers deployed successfully."
fi

# Set permissions on helper scripts
log_info "Setting executable permissions on all helper scripts..."
if [ -d "$HOME/.config/hypr/scripts" ]; then
    chmod +x "$HOME/.config/hypr/scripts"/*.sh 2>/dev/null || true
fi
if [ -d "$HOME/.config/rofi" ]; then
    find "$HOME/.config/rofi" -type f -name "*.sh" -exec chmod +x {} + 2>/dev/null || true
    if [ -f "$HOME/.config/rofi/clipboard/cliphist-rofi" ]; then
        chmod +x "$HOME/.config/rofi/clipboard/cliphist-rofi"
    fi
fi

# Symlink snappy-switcher to ~/.local/bin for Hyprland binding compatibility
mkdir -p "$HOME/.local/bin"
if command -v snappy-switcher &>/dev/null; then
    ln -sf "$(which snappy-switcher)" "$HOME/.local/bin/snappy-switcher"
fi

# Add user to hardware groups
log_info "Configuring hardware user permissions..."
sudo usermod -aG video,audio,input "$USER" 2>/dev/null || true

# Safe Sudoers Configuration for CPU Turbo Sync
TURBO_SYS_PATH="/sys/devices/system/cpu/intel_pstate/no_turbo"
if [ -f "$TURBO_SYS_PATH" ]; then
    log_info "Configuring passwordless CPU turbo toggle sudoers rule..."
    SUDOERS_TMP=$(mktemp)
    echo "$USER ALL=(ALL) NOPASSWD: /usr/bin/tee $TURBO_SYS_PATH" > "$SUDOERS_TMP"
    if sudo visudo -cf "$SUDOERS_TMP" >/dev/null 2>&1; then
        sudo cp "$SUDOERS_TMP" /etc/sudoers.d/hypr-turbo
        sudo chmod 0440 /etc/sudoers.d/hypr-turbo
        log_success "Sudoers rule validated and installed."
    else
        log_warn "Sudoers syntax check failed, skipping sudoers modification."
    fi
    rm -f "$SUDOERS_TMP"
fi

# Set default login shell
if [ "$SHELL" != "$(which zsh)" ]; then
    log_info "Setting default shell to Zsh for $USER..."
    sudo chsh -s "$(which zsh)" "$USER" 2>/dev/null || chsh -s "$(which zsh)" 2>/dev/null || true
fi

# --- 8. Display Manager (Ly) & System Services ---
log_info "Step 8/8: Enabling system services..."

# Disable conflicting display managers if present
sudo systemctl disable sddm.service gdm.service lightdm.service 2>/dev/null || true

# Enable Ly display manager
if systemctl list-unit-files | grep -q "ly.service"; then
    sudo systemctl enable ly.service
elif systemctl list-unit-files | grep -q "ly@.service"; then
    sudo systemctl enable ly@tty2.service
else
    log_warn "Ly service unit not found directly, attempting standard enable..."
    sudo systemctl enable ly 2>/dev/null || true
fi

# Enable System Services
sudo systemctl enable --now bluetooth.service 2>/dev/null || true
sudo systemctl enable --now NetworkManager.service 2>/dev/null || true
sudo systemctl enable --now power-profiles-daemon.service 2>/dev/null || true

# User PipeWire Services
systemctl --user enable --now pipewire pipewire-pulse wireplumber 2>/dev/null || true

# Rebuild font cache
log_info "Updating system font cache..."
fc-cache -f >/dev/null 2>&1 || true

# --- Finished ---
echo ""
echo -e "${GREEN}${BOLD}===================================================================${NC}"
echo -e "${GREEN}${BOLD}           INSTALLATION & SETUP COMPLETED SUCCESSFULLY!            ${NC}"
echo -e "${GREEN}${BOLD}===================================================================${NC}"
echo ""
echo -e "Your Arch Linux system is now fully configured with:"
echo -e "  • ${CYAN}Hyprland${NC} dynamic tiling Wayland compositor"
echo -e "  • ${CYAN}Ly${NC} TUI display manager (starts automatically on next boot)"
echo -e "  • ${CYAN}Waybar${NC} high-contrast top bar with workspaces & hardware monitors"
echo -e "  • ${CYAN}Rofi Control Center${NC} (Super + A for Android-style quick toggles)"
echo -e "  • ${CYAN}Snappy Switcher${NC} (Alt + Tab / Super + Tab animated app switcher)"
echo -e "  • ${CYAN}Wallpapers${NC} deployed to ~/Wallpapers (Super + ] to cycle next)"
echo -e "  • ${CYAN}Alacritty & Kitty${NC} GPU terminals with JetBrains Mono Nerd Font"
echo -e "  • ${CYAN}Zsh + Oh-My-Zsh${NC} with autosuggestions"
echo ""
if [ -d "$BACKUP_DIR" ]; then
    echo -e "${YELLOW}Old configurations were safely backed up to: $BACKUP_DIR${NC}"
    echo ""
fi
echo -e "${BOLD}To start using your new environment, reboot your computer:${NC}"
echo -e "  ${CYAN}sudo reboot${NC}"
echo ""
