#!/usr/bin/env bash

# ====================================================================
# INSTALADOR MAESTRO: BSPWM, SXHKD, POLYBAR, KITTY Y POWERLEVEL10K
# ====================================================================

set -e

echo "[*] 1. Instalando paquetes base, servidor grafico y utilidades..."
sudo pacman -Syu --needed --noconfirm \
    xorg-server xorg-xinit xorg-xrandr \
    bspwm sxhkd picom kitty zsh \
    polybar rofi ttf-jetbrains-mono-nerd \
    open-vm-tools xf86-input-vmmouse \
    xclip alsa-utils wget curl git fzf

echo "[*] 2. Habilitando servicio de VMware..."
sudo systemctl enable --now vmtoolsd.service

echo "[*] 3. Detectando interfaz de red principal..."
IFACE=$(ip -4 route show default 2>/dev/null | awk '{print $5}' | head -n1)
if [ -z "$IFACE" ]; then
    IFACE=$(ip link | awk -F: '$0 !~ "lo|vir|wl|^[^0-9]"{print $2;getline}' | head -n 1 | tr -d ' ')
fi
[ -z "$IFACE" ] && IFACE="ens33"
echo "[+] Interfaz detectada para Polybar: $IFACE"

echo "[*] 4. Creando estructura de directorios..."
mkdir -p "$HOME"/.config/{bspwm,sxhkd,kitty,bin}
mkdir -p "$HOME"/.config/polybar/scripts

# --------------------------------------------------------------------
# A. ~/.xinitrc
# --------------------------------------------------------------------
echo "[*] Configurando ~/.xinitrc..."
cat << 'EOF' > "$HOME/.xinitrc"
#!/usr/bin/env bash

userresources=$HOME/.Xresources
sysresources=/etc/X11/xinit/.Xresources

[ -f "$sysresources" ] && xrdb -merge "$sysresources"
[ -f "$userresources" ] && xrdb -merge "$userresources"

if [ -d /etc/X11/xinit/xinitrc.d ] ; then
    for f in /etc/X11/xinit/xinitrc.d/?*.sh ; do
        [ -x "$f" ] && . "$f"
    done
    unset f
fi

command -v vmtoolsd >/dev/null 2>&1 && vmtoolsd -n vmusr &

exec dbus-launch --exit-with-session bspwm
EOF

# --------------------------------------------------------------------
# B. BSPWM (~/.config/bspwm/bspwmrc)
# --------------------------------------------------------------------
echo "[*] Configurando ~/.config/bspwm/bspwmrc..."
cat << 'EOF' > "$HOME/.config/bspwm/bspwmrc"
#!/usr/bin/env bash

bspc monitor -d 1 2 3 4 5 6 7 8 9 10

bspc config border_width         2
bspc config window_gap          10
bspc config split_ratio          0.50
bspc config borderless_monocle   true
bspc config gapless_monocle      true

bspc config normal_border_color  "#24283b"
bspc config focused_border_color "#7aa2f7"

killall -q sxhkd; sxhkd &
killall -q picom; picom --daemon &
"$HOME"/.config/polybar/launch.sh &
EOF
chmod +x "$HOME/.config/bspwm/bspwmrc"

# --------------------------------------------------------------------
# C. SXHKD (~/.config/sxhkd/sxhkdrc)
# --------------------------------------------------------------------
echo "[*] Configurando ~/.config/sxhkd/sxhkdrc..."
cat << 'EOF' > "$HOME/.config/sxhkd/sxhkdrc"
# Terminal
super + Return
    kitty

# Menu Rofi
super + d
    rofi -show drun

# Reiniciar / Cerrar sesion BSPWM
super + alt + {r,q}
    bspc {wm -r,quit}

# Cerrar ventana
super + {_,shift + }c
    bspc node -{k,c}

# Cambiar foco
super + {h,j,k,l}
    bspc node -f {west,south,north,east}

# Mover ventanas
super + shift + {h,j,k,l}
    bspc node -m {west,south,north,east}

# Cambiar de escritorio
super + {1-9,0}
    bspc desktop -f '^{1-9,10}'

# Mover ventana a escritorio
super + shift + {1-9,0}
    bspc node -d '^{1-9,10}'
EOF

# --------------------------------------------------------------------
# D. KITTY (~/.config/kitty/kitty.conf - Tokyo Night)
# --------------------------------------------------------------------
echo "[*] Configurando Kitty con Tokyo Night..."
cat << 'EOF' > "$HOME/.config/kitty/kitty.conf"
# Fuentes
font_family      JetBrainsMono Nerd Font
bold_font        auto
italic_font      auto
bold_italic_font auto
font_size        11.5

# Comportamiento de ventana
window_padding_width 10
background_opacity 0.95
confirm_os_window_close 0
enable_audio_bell no

# Paleta Tokyo Night
foreground           #c0caf5
background           #1a1b26
selection_foreground #c0caf5
selection_background #33467c
url_color            #73daca
cursor               #c0caf5
cursor_text_color    #1a1b26

# Colores ANSI
color0  #15161e
color8  #414868
color1  #f7768e
color9  #f7768e
color2  #9ece6a
color10 #9ece6a
color3  #e0af68
color11 #e0af68
color4  #7aa2f7
color12 #7aa2f7
color5  #bb9af7
color13 #bb9af7
color6  #7dcfff
color14 #7dcfff
color7  #a9b1d6
color15 #c0caf5
EOF

# --------------------------------------------------------------------
# E. POLYBAR: Colores, Módulos, Scripts y Lanzador
# --------------------------------------------------------------------
echo "[*] Configurando Polybar y scripts..."
cat << 'EOF' > "$HOME/.config/polybar/colors.ini"
[colors]
bg       = #1a1b26
bg-alt   = #24283b
fg       = #c0caf5
fg-alt   = #565f89

blue     = #7aa2f7
cyan     = #7dcfff
green    = #9ece6a
magenta  = #bb9af7
red      = #f7768e
yellow   = #e0af68
EOF

cat << 'EOF' > "$HOME/.config/polybar/scripts/target.sh"
#!/usr/bin/env bash
TARGET_FILE="$HOME/.config/bin/target"
if [ -f "$TARGET_FILE" ] && [ -s "$TARGET_FILE" ]; then
    ip_target=$(head -n 1 "$TARGET_FILE")
    echo "%{F#f7768e}󰓾 %{F#c0caf5}$ip_target"
else
    echo "%{F#565f89}󰓾 %{F#565f89}No target"
fi
EOF
chmod +x "$HOME/.config/polybar/scripts/target.sh"

cat << 'EOF' > "$HOME/.config/polybar/scripts/vpn.sh"
#!/usr/bin/env bash
VPN_IP=$(ip -4 addr show tun0 2>/dev/null | awk '/inet / {print $2}' | cut -d/ -f1)
if [ -n "$VPN_IP" ]; then
    echo "%{F#565f89}| %{F#7dcfff}󰒄 %{F#c0caf5}$VPN_IP"
else
    echo ""
fi
EOF
chmod +x "$HOME/.config/polybar/scripts/vpn.sh"

cat << EOF > "$HOME/.config/polybar/modules.ini"
[module/bspwm]
type = internal/bspwm
pin-workspaces = true
enable-click = true
enable-scroll = true

format = <label-state>

label-focused = 󰮯
label-focused-foreground = \${colors.yellow}
label-focused-padding = 1

label-occupied = 󰊠
label-occupied-foreground = \${colors.blue}
label-occupied-padding = 1

label-empty = ·
label-empty-foreground = \${colors.fg-alt}
label-empty-padding = 1

label-urgent = 󰊠
label-urgent-foreground = \${colors.red}
label-urgent-padding = 1

[module/date]
type = internal/date
interval = 1.0
date = %H:%M
date-alt = %Y-%m-%d %H:%M:%S
format = <label>
format-prefix = "󰥔 "
format-prefix-foreground = \${colors.cyan}
label = %date%
label-foreground = \${colors.fg}

[module/target]
type = custom/script
interval = 2
exec = ~/.config/polybar/scripts/target.sh

[module/cpu]
type = internal/cpu
interval = 1
format = <label>
format-prefix = "󰻠 "
format-prefix-foreground = \${colors.magenta}
label = "%percentage:2%%"

[module/memory]
type = internal/memory
interval = 2
format = <label>
format-prefix = "󰍛 "
format-prefix-foreground = \${colors.blue}
label = "%used%"

[module/ethernet]
type = internal/network
interface = $IFACE
interval = 3.0
format-connected = <label-connected>
format-connected-prefix = "󰈀 "
format-connected-prefix-foreground = \${colors.green}
label-connected = %local_ip%
label-connected-foreground = \${colors.fg}

format-disconnected = <label-disconnected>
format-disconnected-prefix = "󰈂 "
format-disconnected-prefix-foreground = \${colors.red}
label-disconnected = "Offline"
label-disconnected-foreground = \${colors.fg-alt}

[module/vpn]
type = custom/script
interval = 3
exec = ~/.config/polybar/scripts/vpn.sh

[module/sep]
type = custom/text
format = " | "
format-foreground = \${colors.fg-alt}
EOF

cat << 'EOF' > "$HOME/.config/polybar/config.ini"
[global/wm]
margin-bottom = 0
margin-top = 0

include-file = colors.ini
include-file = modules.ini

[bar/main]
monitor = ${env:MONITOR:}
monitor-strict = false
override-redirect = false

bottom = false
fixed-center = true

width = 98%
height = 34
offset-x = 1%
offset-y = 8
radius = 6

background = ${colors.bg}
foreground = ${colors.fg}

line-size = 2
border-size = 2
border-color = ${colors.bg-alt}

padding-left = 2
padding-right = 2
module-margin = 0

font-0 = "JetBrainsMono Nerd Font:style=Bold:size=10;3"
font-1 = "JetBrainsMono Nerd Font:size=13;3"

modules-left = bspwm
modules-center = date
modules-right = target sep cpu sep memory sep ethernet vpn

cursor-click = pointer
cursor-scroll = ns-resize
enable-ipc = true
wm-restack = bspwm
EOF

cat << 'EOF' > "$HOME/.config/polybar/launch.sh"
#!/usr/bin/env bash
killall -q polybar
while pgrep -u $UID -x polybar >/dev/null; do sleep 0.2; done

if type "xrandr" > /dev/null 2>&1; then
  for m in $(xrandr --query | grep " connected" | cut -d" " -f1); do
    MONITOR=$m polybar --reload main -c ~/.config/polybar/config.ini &
  done
else
  polybar --reload main -c ~/.config/polybar/config.ini &
fi
EOF
chmod +x "$HOME/.config/polybar/launch.sh"

# --------------------------------------------------------------------
# F. UTILIDADES: settarget
# --------------------------------------------------------------------
echo "[*] Generando utilidad settarget..."
cat << 'EOF' > "$HOME/.config/bin/settarget"
#!/usr/bin/env bash
TARGET_FILE="$HOME/.config/bin/target"
if [ -z "$1" ]; then
    rm -f "$TARGET_FILE"
    echo "[*] Target limpiado."
else
    echo "$1" > "$TARGET_FILE"
    echo "[+] Target fijado: $1"
fi
EOF
chmod +x "$HOME/.config/bin/settarget"

# --------------------------------------------------------------------
# G. INSTALACION DE OH MY ZSH + POWERLEVEL10K + PLUGINS
# --------------------------------------------------------------------
echo "[*] Configurando Oh My Zsh, Powerlevel10k y plugins..."

# Descarga desatendida de Oh My Zsh
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    RUNZSH=no CHSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi

ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

# Powerlevel10k
if [ ! -d "$ZSH_CUSTOM/themes/powerlevel10k" ]; then
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$ZSH_CUSTOM/themes/powerlevel10k"
fi

# Plugins zsh-autosuggestions y syntax-highlighting
if [ ! -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]; then
    git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
fi

if [ ! -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ]; then
    git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting.git "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
fi

# Escribir ~/.zshrc integrado
echo "[*] Escribiendo ~/.zshrc optimizado..."
cat << 'EOF' > "$HOME/.zshrc"
# Powerlevel10k instant prompt
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="powerlevel10k/powerlevel10k"

plugins=(git sudo zsh-autosuggestions zsh-syntax-highlighting)

source $ZSH/oh-my-zsh.sh

# User PATH
export PATH="$HOME/.config/bin:$PATH"

# Aliases practicos
alias ll='ls -la --color=auto'
alias grep='grep --color=auto'
alias r='bspc wm -r'

[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
EOF

# Cambiar shell de usuario a ZSH
sudo chsh -s /usr/bin/zsh "$USER"

echo "[✔] Instalacion y configuracion completada exitosamente."
echo "[i] Al iniciar 'startx' y abrir Kitty con Super + Enter, Powerlevel10k te guiara en su asistente de diseño (p10k configure)."
