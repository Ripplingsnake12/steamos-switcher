#!/bin/bash
#
# Seamless KDE Plasma <-> Gamescope Session Switcher for Arch Linux
#

set -e

# --- Pre-flight Checks and Setup ---
C_GREEN='\033[0;32m'
C_YELLOW='\033[1;33m'
C_RED='\033[0;31m'
C_BLUE='\033[0;34m'
C_NC='\033[0m' # No Color

if [ "$EUID" -eq 0 ]; then
  echo -e "${C_RED}Error: Do not run this script as root! It will use 'sudo' as needed.${C_NC}"
  exit 1
fi

USER_NAME=$(whoami)
USER_HOME=$(eval echo "~$USER_NAME")

# --- Banner ---
echo -e "${C_BLUE}===================================================================${C_NC}"
echo -e "${C_BLUE} KDE Plasma <-> Gamescope Session Switcher Setup for: ${C_YELLOW}$USER_NAME${C_NC}"
echo -e "${C_BLUE}===================================================================${C_NC}\n"

# --- USER CHOICE FOR AUTOLOGIN ---
echo -e "${C_YELLOW}Configuration Choice:${C_NC}"
echo "Do you want to enable automatic login? [y/N]: "
read AUTOLOGIN_CHOICE

# --- Script Variables ---
SWITCH_SCRIPT_PATH="$USER_HOME/.local/bin/switch-session.sh"
DESKTOP_FILE_PATH="$USER_HOME/.local/share/applications/session-switcher.desktop"
XSESSION_PATH="$USER_HOME/.xsession"
SERVICE_OVERRIDE_DIR="/etc/systemd/user/gamescope-session-plus@.service.d"
SERVICE_OVERRIDE_FILE="$SERVICE_OVERRIDE_DIR/override.conf"

PACKAGES_OFFICIAL=( "plasma-desktop" "sddm" "kdialog" )
PACKAGES_AUR=( "gamescope-git" "gamescope-session-git" "steam" "gamescope-session-steam-git" "mangohud" )

#=======================================================
# STEP 1: DEPENDENCY INSTALLATION
#=======================================================
# Dependency installation
install_packages() {
    echo -e "${C_BLUE}==> Installing Dependencies...${C_NC}"
    
    # Find AUR helper
    for helper in yay paru; do
        if command -v $helper &> /dev/null; then
            AUR_HELPER=$helper
            break
        fi
    done
    
    [ -z "$AUR_HELPER" ] && { echo -e "${C_RED}Error: No AUR helper found${C_NC}"; exit 1; }
    echo -e "${C_GREEN}Using AUR helper: ${AUR_HELPER}${C_NC}"
    
    # Install packages in parallel
    sudo pacman -Syudd --needed "${PACKAGES_OFFICIAL[@]}" --noconfirm &
    $AUR_HELPER -Sdd --needed "${PACKAGES_AUR[@]}" --noconfirm &
    wait
}

install_packages

# Cleanup and systemd configuration
setup_system() {
    echo -e "${C_BLUE}==> Cleaning Up Old Configurations...${C_NC}"
    sudo rm -rf "$SERVICE_OVERRIDE_DIR" &
    rm -f "$XSESSION_PATH" "$SWITCH_SCRIPT_PATH" &
    wait
    
    echo -e "${C_BLUE}==> Applying Systemd Fixes...${C_NC}"
    sudo mkdir -p "$SERVICE_OVERRIDE_DIR"
    sudo tee "$SERVICE_OVERRIDE_FILE" > /dev/null <<'EOF'
[Service]
ExecStart=
ExecStart=/usr/bin/env -u WAYLAND_DISPLAY /usr/share/gamescope-session-plus/gamescope-session-plus %i
EOF
    systemctl --user daemon-reload
}

setup_system

#=======================================================
# STEP 4: INSTALL SESSION SWITCHING LOGIC
#=======================================================
echo -e "${C_BLUE}==> Installing Session Switching Workflow...${C_NC}"

# --- SDDM AUTOLOGIN (CONDITIONAL) ---
if [[ "$AUTOLOGIN_CHOICE" =~ ^[Yy]$ ]]; then
    echo "--> Configuring SDDM for autologin..."
    sudo tee /etc/sddm.conf > /dev/null <<EOF
[Autologin]
User=${USER_NAME}
Session=switcher.desktop
Relogin=true
EOF
    AUTOLOGIN_ENABLED=true
else
    AUTOLOGIN_ENABLED=false
fi

# --- WAYLAND SESSION DESKTOP ENTRY ---
sudo tee /usr/share/wayland-sessions/switcher.desktop > /dev/null <<EOF
[Desktop Entry]
Name=Auto Session Switcher
Exec=${XSESSION_PATH}
Type=Application
EOF

#=======================================================
# STEP 5: CREATE XSESSION LAUNCH SCRIPT WITH UWSM
#=======================================================
echo -e "${C_BLUE}==> Creating Session Launch Script (with UWSM)...${C_NC}"

cat > "$XSESSION_PATH" <<'EOS'
#!/bin/bash
SESSION=$(cat "$HOME/.next-session" 2>/dev/null)
rm -f "$HOME/.next-session"

# Ensure environment is updated
dbus-update-activation-environment --systemd DISPLAY WAYLAND_DISPLAY

# Fast Wayland socket check
wait_for_wayland() {
    local socket_path="$XDG_RUNTIME_DIR/wayland-1"
    local max_attempts=20
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        [ -S "$socket_path" ] && return 0
        sleep 0.1
        ((attempt++))
    done
    
    return 1
}

if [[ "$SESSION" == *"gamescope-session-steam"* ]]; then
    echo "Starting Gamescope session..."
    # Ensure gamescope dependencies are available
    if ! command -v gamescope-session-plus &> /dev/null; then
        echo "Error: gamescope-session-plus not found, falling back to KDE Plasma"
        exec startplasma-wayland
    fi
    
    # Clear any existing Wayland display to prevent conflicts
    unset WAYLAND_DISPLAY
    
    # Start gamescope session with proper environment
    exec systemd-run --user --scope --setenv=XDG_SESSION_TYPE=wayland gamescope-session-plus steam
else
    echo "Starting KDE Plasma session..."
    # Start KDE Plasma
    exec startplasma-wayland
fi
EOS
chmod +x "$XSESSION_PATH"

#=======================================================
# STEP 6: CREATE SWITCHING SCRIPT
#=======================================================
echo -e "${C_BLUE}==> Creating Session Switching Helper...${C_NC}"

mkdir -p "$(dirname "$SWITCH_SCRIPT_PATH")"
cat > "$SWITCH_SCRIPT_PATH" <<'EOSWITCH'
#!/bin/bash

# Show session switcher with KDialog
choice=$(kdialog --menu "Choose Session Mode:" \
    "steamos" "🎮 SteamOS Mode" \
    "desktop" "🖥️ Desktop Mode" \
    --title "Session Switcher")

case "$choice" in
    "desktop")
        # Validate we can write the session file
        if echo "plasma.desktop" > "$HOME/.next-session" 2>/dev/null; then
            kdialog --passivepopup "Switching to Desktop..." 2
            echo "Session file written successfully"
        else
            kdialog --error "Error: Failed to write session file"
            echo "Error: Cannot write to $HOME/.next-session"
            exit 1
        fi
        ;;
    "steamos")
        # Validate we can write the session file
        if echo "gamescope-session-steam.desktop" > "$HOME/.next-session" 2>/dev/null; then
            kdialog --passivepopup "Switching to SteamOS..." 2
            echo "Session file written successfully"
        else
            kdialog --error "Error: Failed to write session file"
            echo "Error: Cannot write to $HOME/.next-session"
            exit 1
        fi
        ;;
    *)
        echo "No valid choice made"
        exit 1
        ;;
esac


# Fast session cleanup
cleanup_session() {
    # Get current session processes  
    local gamescope_pids=$(pgrep -x "gamescope" 2>/dev/null)
    local plasma_pids=$(pgrep -x "plasmashell\|kwin_wayland" 2>/dev/null || pgrep -x "plasmashell" 2>/dev/null || pgrep -x "kwin_wayland" 2>/dev/null)
    
    if [[ -n "$gamescope_pids" ]]; then
        echo "Stopping Gamescope session..."
        systemctl --user stop gamescope-session-plus@steam 2>/dev/null &
        pkill -TERM gamescope 2>/dev/null
        sleep 0.5
        pkill -KILL gamescope 2>/dev/null || true
        
    elif [[ -n "$plasma_pids" ]]; then
        echo "Stopping KDE Plasma session..."
        if command -v qdbus &> /dev/null; then
            qdbus org.kde.ksmserver /KSMServer logout 0 0 0 2>/dev/null &
        fi
        pkill -TERM plasmashell 2>/dev/null || true
        pkill -TERM kwin_wayland 2>/dev/null || true
        sleep 0.5
        pkill -KILL plasmashell 2>/dev/null || true
        pkill -KILL kwin_wayland 2>/dev/null || true
    fi
    
    # Parallel cleanup of remaining processes
    pkill -KILL -f "gamescope-session\|steam" 2>/dev/null || true &
    wait
}

# Execute cleanup
cleanup_session
EOSWITCH
chmod +x "$SWITCH_SCRIPT_PATH"

#=======================================================
# STEP 7: CREATE DESKTOP APPLICATION LAUNCHER
#=======================================================
echo -e "${C_BLUE}==> Creating Desktop Application Launcher...${C_NC}"

# Create applications directory if it doesn't exist
mkdir -p "$(dirname "$DESKTOP_FILE_PATH")"

# Create the desktop file for the session switcher
cat > "$DESKTOP_FILE_PATH" <<EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=Session Switcher
Comment=Switch between KDE Plasma and SteamOS modes
Exec=$SWITCH_SCRIPT_PATH
Icon=preferences-desktop-display
Terminal=false
Categories=System;Settings;
Keywords=session;switcher;plasma;steamos;gamescope;
EOF

echo -e "${C_GREEN}Created desktop launcher at $DESKTOP_FILE_PATH${C_NC}"

#=======================================================
# STEP 8: ENSURE NOTIFICATION SUPPORT
#=======================================================
echo -e "${C_BLUE}==> Ensuring notification support...${C_NC}"

# KDE Plasma has built-in notification support via knotify
echo -e "${C_GREEN}KDE Plasma includes built-in notification support${C_NC}"

#=======================================================
# FINALIZATION
#=======================================================
echo -e "${C_GREEN}✅ Setup Complete! ✅${C_NC}\n"

echo -e "${C_YELLOW}What was implemented:${C_NC}"
echo "1. Converted script to work with KDE Plasma instead of Hyprland"
echo "2. Replaced Wofi with kdialog for session selection"
echo "3. Created desktop application launcher for easy access"
echo "4. Updated session detection and cleanup for KDE Plasma"
echo "5. Integrated KDE notification system"
echo "6. Removed Hyprland-specific dependencies and configurations"

echo -e "\n${C_YELLOW}Reboot is required for changes to take effect.${C_NC}\n"

if [ "$AUTOLOGIN_ENABLED" = true ]; then
    echo -e "-> Autologin is enabled. System will boot directly into KDE Plasma."
    echo "   Launch 'Session Switcher' from application menu to switch sessions."
else
    echo -e "-> Autologin is disabled. Choose 'Auto Session Switcher' at login."
fi

echo -e "\n${C_BLUE}Post-reboot testing:${C_NC}"
echo "1. Launch 'Session Switcher' from KDE application menu"
echo "2. You can also run the switcher manually: $SWITCH_SCRIPT_PATH"
echo "3. Desktop file location: $DESKTOP_FILE_PATH"
