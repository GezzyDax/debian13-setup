#!/usr/bin/env bash
# =========================================
# Debian 13 (Trixie) Initial Setup Script
# =========================================
# Запускать от root!
# Скрипт готовит систему к нормальной работе.

set -e

echo "🧭 Обновление системы..."
apt update && apt full-upgrade -y
apt autoremove --purge -y
apt clean

echo "⚙️  Установка базовых системных пакетов..."
apt install -y \
sudo \
adduser \
passwd \
apt-utils \
man-db manpages \
bash-completion \
lsb-release \
procps \
psmisc \
net-tools \
iproute2 \
iputils-ping \
wget \
curl \
less \
vim \
nano \
tar \
gzip \
bzip2 \
xz-utils \
unzip \
coreutils \
findutils \
grep \
sed \
gawk \
file \
lsof \
which

echo "🧱 Установка утилит и инструментов администратора..."
apt install -y \
htop \
btop \
ncdu \
rsync \
screen \
tmux \
cron \
ca-certificates \
gnupg \
locales \
tzdata \
neofetch \
lsb-release \
git \
zip \
p7zip-full \
debconf \
debconf-utils \
software-properties-common \
apt-transport-https

echo "🌐 Настройка сети..."
apt install -y \
network-manager \
net-tools \
iproute2 \
dnsutils \
traceroute \
nmap \
netcat-openbsd \
openssh-client

systemctl enable NetworkManager || true

echo "🔒 Настройка безопасности..."
apt install -y ufw fail2ban
ufw --force enable
systemctl enable fail2ban --now

echo "💡 Установка дополнительных инструментов..."
apt install -y jq fzf ripgrep fd-find bat exa

echo "📦 Проверка обновлений и финальный апгрейд..."
apt update && apt full-upgrade -y

echo "🐚 Установка и настройка fish shell..."
apt install -y fish
useradd -m -s /usr/bin/fish gezzy 2>/dev/null || true
usermod -aG sudo gezzy || true
chsh -s /usr/bin/fish gezzy || true

echo "🔧 Настройка PATH..."
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games"
echo 'export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games"' >> /root/.bashrc
su - gezzy -c "echo 'export PATH=\"/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games\"' >> ~/.bashrc"

# Для fish (если активен)
su - gezzy -c 'fish -c "set -U fish_user_paths /usr/local/sbin /usr/local/bin /usr/sbin /usr/bin /sbin /bin /usr/games /usr/local/games"'

echo "✅ Установка завершена!"
echo
echo "Теперь можно войти как обычный пользователь:"
echo "  su - gezzy"
echo
echo "Проверь PATH и sudo доступ:"
echo "  echo \$PATH"
echo "  sudo whoami"
echo
echo "🎉 Debian 13 готов к работе!"
