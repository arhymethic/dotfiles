# 🪐 Modern Hyprland Dotfiles

A sleek, high-performance, and keyboard-driven desktop setup for **Arch Linux**, powered by **Hyprland**, **Ly Display Manager**, **Waybar**, **Rofi Control Center**, and **Snappy Switcher**.

Designed for effortless deployment onto any fresh **Arch Linux** installation (including `archinstall`).

---

## ⚡ Quick Install (Fresh Arch Linux)

Clone the repository and run the automated installer:

```bash
git clone https://github.com/arhymethic/dotfiles.git ~/dotfiles
cd ~/dotfiles
chmod +x install.sh
./install.sh
```

Once the installation finishes, reboot your system:

```bash
sudo reboot
```

---

## 🛡️ Sudo Commands & Permissions Breakdown

The installer executes the following standard `sudo` operations during setup:

| Command / Target | Purpose & Rationale |
| :--- | :--- |
| `sudo pacman -Syu` | Updates system package databases and core packages to ensure dependency compatibility |
| `sudo pacman -S --needed base-devel git` | Installs base developer compilation tools needed to build AUR packages (`yay`) |
| `sudo pacman -S --needed - < packages-pacman.txt` | Installs all official Arch Linux desktop, audio, font, and tool dependencies |
| `sudo usermod -aG video,audio,input $USER` | Adds your user account to the required hardware device access groups |
| `sudo chsh -s $(which zsh) $USER` | Sets Zsh as the default interactive login shell |
| `sudo systemctl enable ly.service` | Enables the lightweight Ly TUI display manager on system boot |
| `sudo systemctl enable --now bluetooth.service` | Enables and immediately starts the Bluetooth daemon (`bluez`) |
| `sudo systemctl enable --now NetworkManager.service` | Enables and immediately starts the NetworkManager daemon |
| `sudo systemctl enable --now power-profiles-daemon.service` | Enables the CPU power management profile daemon |
| `/etc/sudoers.d/hypr-turbo` | Configures passwordless sudo for CPU Turbo Boost toggling via `turbo-sync.sh` (`/usr/bin/tee /sys/devices/system/cpu/intel_pstate/no_turbo`) |

---

## 📦 Package Manifest

The setup separates packages cleanly between official Arch repositories and the AUR.

### Official Arch Linux Packages (`packages-pacman.txt`)
- **Compositor & Wayland**: `hyprland`, `hyprpaper`, `hypridle`, `hyprlock`, `hyprpolkitagent`, `hyprsunset`, `xdg-desktop-portal-hyprland`, `xdg-desktop-portal`, `xdg-utils`, `uwsm`, `qt5-wayland`, `qt6-wayland`, `wtype`, `wev`
- **Display Manager**: `ly`
- **UI & Notifications**: `waybar`, `rofi`, `rofi-emoji`, `dunst`, `libnotify`
- **Media & Hardware Controls**: `grim`, `slurp`, `wl-clipboard`, `cliphist`, `brightnessctl`, `pamixer`, `playerctl`, `power-profiles-daemon`, `pavucontrol`, `jq`, `bc`, `gawk`, `udisks2`
- **Network & Bluetooth**: `networkmanager`, `network-manager-applet`, `bluez`, `bluez-utils`, `blueman`
- **Audio Stack (PipeWire)**: `pipewire`, `pipewire-audio`, `pipewire-alsa`, `pipewire-pulse`, `pipewire-jack`, `wireplumber`, `gst-plugin-pipewire`
- **Terminal & Shell**: `alacritty`, `kitty`, `zsh`, `zsh-completions`, `bash-completion`, `fastfetch`, `btop`, `htop`, `cava`, `superfile`, `yazi`, `eza`, `cmatrix`, `tree`, `vim`, `wget`
- **File Management & Theming**: `nautilus`, `nautilus-image-converter`, `gvfs`, `gvfs-mtp`, `gvfs-gphoto2`, `gvfs-afc`, `usbmuxd`, `zathura`, `zathura-pdf-mupdf`
- **Typography & Icons**: `ttf-jetbrains-mono-nerd`, `ttf-firacode-nerd`, `noto-fonts`, `noto-fonts-cjk`, `noto-fonts-emoji`, `ttf-dejavu`, `ttf-liberation`

### AUR Packages (`packages-aur.txt`)
- `yay` (AUR Package Helper)
- `snappy-switcher` (Fast, animated Alt+Tab window switcher with MRU sorting)
- `monique` (Graphical monitor configurator for Hyprland)
- `hyprkcs-git` (Interactive Hyprland keybinding cheatsheet HUD)
- `grimblast-git` (Wayland screenshot helper)
- `pipes.sh` (Terminal screensaver)

---

## ⌨️ Keybindings Reference

### 🚀 Launchers & System Controls
| Keybinding | Action |
| :--- | :--- |
| <kbd>Super</kbd> + <kbd>Return</kbd> | Launch Terminal (`alacritty`) |
| <kbd>Super</kbd> + <kbd>E</kbd> | Launch File Manager (`nautilus`) |
| <kbd>Super</kbd> + <kbd>R</kbd> | App Launcher (`rofi`) |
| <kbd>Super</kbd> + <kbd>A</kbd> | **Android-Style Control Center** (Quick settings toggle) |
| <kbd>Super</kbd> + <kbd>B</kbd> | Bluetooth Menu |
| <kbd>Super</kbd> + <kbd>C</kbd> | Clipboard History Picker (`cliphist`) |
| <kbd>Super</kbd> + <kbd>N</kbd> | Emoji Picker (`rofi-emoji`) |
| <kbd>Super</kbd> + <kbd>L</kbd> | Lock Screen (`hyprlock`) |
| <kbd>Super</kbd> + <kbd>M</kbd> | Power / Session Menu |

### 🪟 Window Management
| Keybinding | Action |
| :--- | :--- |
| <kbd>Super</kbd> + <kbd>W</kbd> | Close active window |
| <kbd>Super</kbd> + <kbd>V</kbd> | Toggle Floating mode |
| <kbd>Super</kbd> + <kbd>F</kbd> | Toggle Fullscreen |
| <kbd>Super</kbd> + <kbd>Q</kbd> | Toggle Split direction |
| <kbd>Alt</kbd> + <kbd>Tab</kbd> | Global Window Switcher (`snappy-switcher`) |
| <kbd>Super</kbd> + <kbd>Tab</kbd> | Workspace Window Switcher |
| <kbd>Super</kbd> + <kbd>Arrow Keys</kbd> | Focus window in direction |
| <kbd>Super</kbd> + <kbd>Shift</kbd> + <kbd>Arrow Keys</kbd> | Resize window in direction |
| <kbd>Super</kbd> + <kbd>Left Mouse</kbd> | Drag floating window |
| <kbd>Super</kbd> + <kbd>Right Mouse</kbd> | Resize window |

### 🖼️ Wallpaper & HUD Controls
| Keybinding | Action |
| :--- | :--- |
| <kbd>Super</kbd> + <kbd>]</kbd> | Switch to Next Wallpaper (`~/Wallpapers`) |
| <kbd>Super</kbd> + <kbd>[</kbd> | Switch to Previous Wallpaper |
| <kbd>Super</kbd> + <kbd>Shift</kbd> + <kbd>S</kbd> | Area Screenshot to Clipboard (`grimblast`) |
| <kbd>F4</kbd> / <kbd>XF86AudioMicMute</kbd> | Toggle Microphone Mute (with HUD) |
| <kbd>F7</kbd> | Open Monitor Settings (`monique`) |
| <kbd>F8</kbd> | Toggle Wi-Fi ON / OFF |
| <kbd>F10</kbd> / <kbd>XF86Bluetooth</kbd> | Toggle Bluetooth ON / OFF |
| <kbd>F12</kbd> | Cycle CPU Power Profile (Performance / Balanced / Power Saver) |
| <kbd>Volume Up / Down / Mute</kbd> | Adjust Volume with Dunst HUD feedback |
| <kbd>Brightness Up / Down</kbd> | Adjust Screen Brightness with Dunst HUD feedback |

---

## 🎨 Wallpapers

The entire wallpaper collection is included in the [`Wallpapers/`](Wallpapers/) folder and automatically deployed to `~/Wallpapers`.

You can dynamically cycle through them anytime using <kbd>Super</kbd> + <kbd>]</kbd> (next) and <kbd>Super</kbd> + <kbd>[</kbd> (previous).

---

## 📁 Repository Structure

```
.
├── .config/
│   ├── alacritty/          # Terminal emulator config
│   ├── btop/               # System process monitor theme & config
│   ├── cava/               # Audio visualizer config
│   ├── dunst/              # High-contrast notification daemon
│   ├── fastfetch/          # Neofetch replacement system info
│   ├── gtk-4.0/            # Libadwaita monochrome glass styling
│   ├── hypr/               # Hyprland lua config, keybinds, scripts
│   ├── hyprkcs/            # Keybinding HUD configuration
│   ├── kitty/              # Kitty terminal configuration
│   ├── monique/            # Monique display manager settings
│   ├── pipewire/           # PipeWire custom clock settings
│   ├── rofi/               # Launchers, power menu, wifi, bluetooth, control center
│   ├── snappy-switcher/    # Snappy switcher config & glass theme
│   ├── superfile/          # Superfile terminal file manager
│   ├── swaylock/           # Screen locker fallback
│   ├── waybar/             # Top bar config & CSS styling
│   ├── wireplumber/        # Audio headroom & switch settings
│   └── zathura/            # PDF viewer theme & config
├── home/                   # Shell files (.bashrc, .zshrc, .dir_colors, .inputrc)
├── Wallpapers/             # Curated wallpaper collection
├── install.sh              # Master automated installation script
├── packages-pacman.txt     # Official repository package manifest
├── packages-aur.txt        # AUR package manifest
└── README.md               # Documentation
```
