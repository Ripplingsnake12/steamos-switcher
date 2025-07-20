# KDE Plasma ↔ Gamescope Session Switcher

## Overview

This installation script creates a seamless session switching system between KDE Plasma desktop environment and Gamescope (SteamOS-like) gaming mode on Arch Linux systems.

## Key Benefits

### 🎮 **Dual-Mode Gaming Experience**
- **Desktop Mode**: Full KDE Plasma desktop with all productivity applications
- **Gaming Mode**: Steam Big Picture in a dedicated Gamescope session optimized for gaming
- Switch between modes without losing session state

### ⚡ **Performance Optimization** 
- **Dedicated Resources**: Each session runs independently, maximizing performance
- **Gaming Focus**: Gamescope mode eliminates desktop overhead for better gaming performance
- **Parallel Installation**: Dependencies install simultaneously for faster setup

### 🔧 **Seamless Integration**
- **GUI Session Switcher**: Easy-to-use KDialog interface for mode selection
- **Desktop Launcher**: Accessible from KDE application menu
- **Auto-Session Detection**: Intelligent session management and cleanup
- **Optional Autologin**: Boot directly into preferred session

### 🛡️ **Robust System Management**
- **Clean Session Transitions**: Proper cleanup of running processes
- **Error Handling**: Fallback mechanisms prevent system lockup
- **Systemd Integration**: Uses modern Linux service management
- **Non-Root Installation**: Secure setup without elevated privileges

### 📱 **User Experience Features**
- **Visual Notifications**: KDE-integrated popup messages for status updates
- **Fast Switching**: Optimized session transitions with minimal downtime
- **Session Persistence**: Remembers last session choice
- **Wayland Support**: Modern display server compatibility

### 🔄 **Flexibility & Control**
- **Manual Override**: Command-line access to switching functionality
- **Configurable Autologin**: Choose whether to enable automatic login
- **Steam Integration**: Direct integration with Steam gaming platform
- **MangoHUD Support**: Gaming performance overlay included

## Technical Advantages

- **Wayland Native**: Uses modern display protocols for better security and performance
- **SystemD Services**: Proper process lifecycle management
- **Environment Isolation**: Clean separation between desktop and gaming environments
- **Resource Efficiency**: Only runs necessary components for each mode

## Installation Requirements

- Arch Linux system
- AUR helper (yay or paru)
- User account with sudo privileges

The script automatically handles all dependencies and configurations, making it ready to use after a single reboot.