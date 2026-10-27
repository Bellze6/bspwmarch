#!/usr/bin/env bash

# ====================================================================
# SCRIPT DE DESPLIEGUE: BSPWM, SXHKD Y POLYBAR (TOKYO NIGHT)
# ====================================================================

set -e

echo "[*] Instalando paquetes graficos y dependencias..."
sudo pacman -Syu --needed --noconfirm \
    xorg-server xorg-xinit xorg-xrandr \
    bspwm sxhkd picom kitty zsh \
    polybar rofi ttf-jetbrains-mono-nerd \
    open-vm-tools xf86-input-vmmouse \
    xclip alsa-utils wget curl git

echo "[*] Habilitando servicio vmtoolsd..."
sudo systemctl enable --now vmtoolsd.service

echo "[*] Generando directorios de configuracion..."
mkdir -p "$HOME"/.config/{bspwm,sxhkd,kitty,bin}
mkdir -p "$HOME"/.config/polybar/scripts

# --------------------------------------------------------------------
# 1. ~/.xinitrc
# --------------------------------------------------------------------
echo "[*] Escribiendo ~/.xinitrc..."
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
# 2. BSPWM: ~/.config/bspwm/bspwmrc
# --------------------------------------------------------------------
echo "[*] Escribiendo ~/.config/bspwm/bspwmrc..."
cat << 'EOF' > "$HOME/.config/bspwm/bspwmrc"
#!/usr/bin/env bash

# Modos de pantalla VMware (Virtual-1)
xrandr --newmode "1920x1080_60.00" 173.00 1920 2048 2248 2576 1080 1083 1088 1120 -hsync +vsync 2>/dev/null
xrandr --addmode Virtual-1 "1920x1080_60.00" 2>/dev/null

xrandr --newmode "1600x900_60.00"  118.25 1600 1696 1856 2112 900 903 908 934 -hsync +vsync 2>/dev/null
xrandr --addmode Virtual-1 "1600x900_60.00" 2>/dev/null

# Aplicar 1080p por defecto
xrandr --output Virtual-1 --mode "1920x1080_60.00" 2>/dev/null

# Espacios de trabajo
bspc monitor Virtual-1 -d 1 2 3 4 5 6 7 8 9 10 2>/dev/null || bspc monitor -d 1 2 3 4 5 6 7 8 9 10

# Reglas de ventanas y estilo
bspc config border_width         2
bspc config window_gap          10
bspc config split_ratio          0.50
bspc config borderless_monocle   true
bspc config gapless_monocle      true

bspc config normal_border_color  "#24283b"
bspc config focused_border_color "#7aa2f7"

# Autostart
killall -q sxhkd; sxhkd &
killall -q picom; picom --daemon &
"$HOME"/.config/polybar/launch.sh &
EOF
chmod +x "$HOME/.config/bspwm/bspwmrc"

# --------------------------------------------------------------------
# 3. SXHKD: ~/.config/sxhkd/sxhkdrc
# --------------------------------------------------------------------
echo "[*] Escribiendo ~/.config/sxhkd/sxhkdrc..."
cat << 'EOF' > "$HOME/.config/sxhkd/sxhkdrc"
# Terminal
super + Return
    kitty

# Lanzador de aplicaciones
super + d
    rofi -show drun

# Reiniciar / Salir de BSPWM
super + alt + {r,q}
    bspc {wm -r,quit}

# Cerrar ventana
super + {_,shift + }c
    bspc node -{k,c}

# Foco de ventanas
super + {h,j,k,l}
    bspc node -f {west,south,north,east}

# Mover ventanas
super + shift + {h,j,k,l}
    bspc node -m {west,south,north,east}

# Cambiar de escritorio
super + {1-9,0}
    bspc desktop -f '^{1-9,10}'

# Enviar ventana a escritorio
super + shift + {1-9,0}
    bspc node -d '^{1-9,10}'

# Modos de pantalla VMware: Super + F (1080p) / Super + Shift + F (1600x900)
super + f
    xrandr --output Virtual-1 --mode "1920x1080_60.00" && ~/.config/polybar/launch.sh

super + shift + f
    xrandr --output Virtual-1 --mode "1600x900_60.00" && ~/.config/polybar/launch.sh
EOF

# --------------------------------------------------------------------
# 4. POLYBAR: colors.ini
# --------------------------------------------------------------------
echo "[*] Escribiendo ~/.config/polybar/colors.ini..."
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

# --------------------------------------------------------------------
# 5. POLYBAR: scripts (target.sh & vpn.sh)
# --------------------------------------------------------------------
echo "[*] Escribiendo scripts de Polybar..."
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

# --------------------------------------------------------------------
# 6. POLYBAR: modules.ini
# --------------------------------------------------------------------
echo "[*] Escribiendo ~/.config/polybar/modules.ini..."
cat << 'EOF' > "$HOME/.config/polybar/modules.ini"
[module/bspwm]
type = internal/bspwm
pin-workspaces = true
enable-click = true
enable-scroll = true

format = <label-state>

label-focused = 󰮯
label-focused-foreground = ${colors.yellow}
label-focused-padding = 1

label-occupied = 󰊠
label-occupied-foreground = ${colors.blue}
label-occupied-padding = 1

label-empty = ·
label-empty-foreground = ${colors.fg-alt}
label-empty-padding = 1

label-urgent = 󰊠
label-urgent-foreground = ${colors.red}
label-urgent-padding = 1

[module/date]
type = internal/date
interval = 1.0
date = %H:%M
date-alt = %Y-%m-%d %H:%M:%S
format = <label>
format-prefix = "󰥔 "
format-prefix-foreground = ${colors.cyan}
label = %date%
label-foreground = ${colors.fg}

[module/target]
type = custom/script
interval = 2
exec = ~/.config/polybar/scripts/target.sh

[module/cpu]
type = internal/cpu
interval = 1
format = <label>
format-prefix = "󰻠 "
format-prefix-foreground = ${colors.magenta}
label = "%percentage:2%%"

[module/memory]
type = internal/memory
interval = 2
format = <label>
format-prefix = "󰍛 "
format-prefix-foreground = ${colors.blue}
label = "%used%"

[module/ethernet]
type = internal/network
interface = ens33
interval = 3.0
format-connected = <label-connected>
format-connected-prefix = "󰈀 "
format-connected-prefix-foreground = ${colors.green}
label-connected = %local_ip%
label-connected-foreground = ${colors.fg}

format-disconnected = <label-disconnected>
format-disconnected-prefix = "󰈂 "
format-disconnected-prefix-foreground = ${colors.red}
label-disconnected = "Offline"
label-disconnected-foreground = ${colors.fg-alt}

[module/vpn]
type = custom/script
interval = 3
exec = ~/.config/polybar/scripts/vpn.sh

[module/sep]
type = custom/text
format = " | "
format-foreground = ${colors.fg-alt}
EOF

# --------------------------------------------------------------------
# 7. POLYBAR: config.ini & launch.sh
# --------------------------------------------------------------------
echo "[*] Escribiendo ~/.config/polybar/config.ini..."
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

echo "[*] Escribiendo ~/.config/polybar/launch.sh..."
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
# 8. HERRAMIENTA: settarget
# --------------------------------------------------------------------
echo "[*] Escribiendo ~/.config/bin/settarget..."
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
# 9. INTEGRACION DE PATH EN SHELL
# --------------------------------------------------------------------
for rc in "$HOME/.zshrc" "$HOME/.bashrc"; do
    if [ -f "$rc" ] && ! grep -q 'PATH="$HOME/.config/bin:$PATH"' "$rc"; then
        echo 'export PATH="$HOME/.config/bin:$PATH"' >> "$rc"
    fi
done

echo "[✔] Despliegue completado. Puedes iniciar tu entorno con: startx"
