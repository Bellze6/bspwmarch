#!/bin/bash

# Evitar ejecución como root
if [ "$(whoami)" == "root" ]; then
    echo "❌ No ejecutes este script como root. Usa tu usuario normal."
    exit 1
fi

echo "🔄 Actualizando el sistema e instalando dependencias base..."
sudo pacman -Syu --noconfirm
sudo pacman -S --needed --noconfirm base-devel git vim curl wget

echo "📦 Instalando un Helper de AUR (yay)..."
if ! command -v yay &> /dev/null; then
    git clone https://aur.archlinux.org/yay.git ~/yay
    cd ~/yay
    makepkg -si --noconfirm
    cd ~
    rm -rf ~/yay
fi

echo "🧰 Instalando Xorg, Entorno, Gestor de Ventanas y Utilidades..."
sudo pacman -S --needed --noconfirm xorg-server xorg-xinit bspwm sxhkd polybar picom kitty rofi \
    feh scrot scrub xclip bat plocate ranger fastfetch wmname acpi \
    imagemagick cmatrix zsh fzf neovim

echo "📦 Instalando complementos de ZSH desde pacman..."
sudo pacman -S --needed --noconfirm zsh-autosuggestions zsh-syntax-highlighting

echo "🔍 Instalando paquetes de AUR (i3lock-fancy y dependencias extra)..."
yay -S --needed --noconfirm i3lock-fancy-git zsh-autocomplete-git

echo "📁 Creando carpetas de configuración..."
mkdir -p ~/.config/{bspwm,sxhkd,kitty,polybar,picom,rofi}

echo "📋 Copiando archivos de configuración por defecto..."
install -Dm755 /usr/share/doc/bspwm/examples/bspwmrc ~/.config/bspwm/bspwmrc
install -Dm644 /usr/share/doc/bspwm/examples/sxhkdrc ~/.config/sxhkd/sxhkdrc
install -Dm644 /etc/polybar/config.ini ~/.config/polybar/config.ini
install -Dm644 /etc/xdg/picom.conf ~/.config/picom/picom.conf

echo "⚙️ Configurando ZSH y Powerlevel10k (Base pura)..."
git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ~/powerlevel10k
echo 'source ~/powerlevel10k/powerlevel10k.zsh-theme' > ~/.zshrc
echo 'source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh' >> ~/.zshrc
echo 'source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh' >> ~/.zshrc

sudo chsh -s /usr/bin/zsh root
sudo chsh -s /usr/bin/zsh "$USER"

echo "🔧 Instalando NvChad para Neovim (Entorno limpio)..."
rm -rf ~/.config/nvim ~/.local/share/nvim ~/.local/state/nvim ~/.cache/nvim
git clone https://github.com/NvChad/starter ~/.config/nvim

echo "🖥️ Configurando arranque de Xorg para BSPWM..."
echo "exec bspwm" > ~/.xinitrc

echo "🔍 Actualizando base de datos de plocate..."
sudo updatedb

echo "✅ Instalación completada. Escribe 'startx' para iniciar BSPWM."
