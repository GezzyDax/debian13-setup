#!/usr/bin/env bash
# =========================================
# Debian 13 (Trixie) Initial Setup Script
# Автор: <твой ник>
# =========================================
# Скрипт подготавливает чистую систему Debian 13
# к нормальной повседневной работе.
# =========================================

set -e

# Цвета для вывода
GREEN="\e[32m"
YELLOW="\e[33m"
RED="\e[31m"
BLUE="\e[34m"
RESET="\e[0m"

say() { echo -e "${GREEN}==>${RESET} $1"; }
warn() { echo -e "${YELLOW}⚠ ${RESET}$1"; }
error() { echo -e "${RED}❌ ${RESET}$1"; }

# Проверка root
if [ "$EUID" -ne 0 ]; then
  error "Запусти этот скрипт от root (sudo bash debian13_setup.sh)"
  exit 1
fi

clear
echo -e "${BLUE}=============================================${RESET}"
echo -e "${BLUE}🧰 Debian 13 (Trixie) — базовая настройка${RESET}"
echo -e "${BLUE}=============================================${RESET}"
echo

# ---------------------------------------------
# Установка sudo до создания пользователя
# ---------------------------------------------
say "🧰 Устанавливаю sudo..."
apt update -y
apt install -y sudo

# ---------------------------------------------
# Создание пользователя
# ---------------------------------------------
read -rp "👤 Введите имя пользователя (например: user): " USERNAME

if id "$USERNAME" &>/dev/null; then
  say "Пользователь ${USERNAME} уже существует."
else
  say "Создаю пользователя ${USERNAME}..."
  adduser --gecos "" "$USERNAME"
fi

say "Добавляю ${USERNAME} в группу sudo..."
usermod -aG sudo "$USERNAME"

# ---------------------------------------------
# Настройка PATH
# ---------------------------------------------
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games"
echo 'export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games"' >> /root/.bashrc
su - "$USERNAME" -c "echo 'export PATH=\"/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games\"' >> ~/.bashrc"

# ---------------------------------------------
# Обновление системы
# ---------------------------------------------
say "🔄 Обновление системы..."
apt update && apt full-upgrade -y
apt autoremove --purge -y
apt clean

# ---------------------------------------------
# Базовые системные пакеты
# ---------------------------------------------
say "⚙️  Установка базовых системных пакетов..."
apt install -y \
adduser passwd apt-utils man-db manpages bash-completion lsb-release \
procps psmisc net-tools iproute2 iputils-ping wget curl less vim nano tar \
gzip bzip2 xz-utils unzip coreutils findutils grep sed gawk file lsof which

# ---------------------------------------------
# Утилиты и инструменты администратора
# ---------------------------------------------
say "🧱 Установка утилит и инструментов администратора..."
apt install -y \
htop btop ncdu rsync screen tmux cron ca-certificates gnupg locales tzdata \
neofetch git zip p7zip-full debconf debconf-utils software-properties-common \
apt-transport-https jq fzf ripgrep fd-find bat exa

# ---------------------------------------------
# Сеть
# ---------------------------------------------
say "🌐 Настройка сети..."
apt install -y network-manager dnsutils traceroute nmap netcat-openbsd openssh-client
systemctl enable NetworkManager || true

# ---------------------------------------------
# Безопасность
# ---------------------------------------------
say "🔒 Установка и настройка безопасности..."
apt install -y ufw fail2ban openssh-server

# Настройка UFW
say "🧩 Настройка правил брандмауэра..."
ufw --force reset
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp comment 'SSH'
ufw allow 80/tcp comment 'HTTP'
ufw allow 443/tcp comment 'HTTPS'
ufw allow proto icmp comment 'Ping'
ufw --force enable
ufw status verbose

# Настройка SSH и Fail2Ban
say "🔐 Настройка SSH и Fail2Ban..."
systemctl enable --now ssh
systemctl restart ssh

# Проверка, есть ли файл лога для fail2ban (auth.log)
if [ ! -f /var/log/auth.log ]; then
  touch /var/log/auth.log
  chown syslog:adm /var/log/auth.log || true
fi

# Создание корректного jail.local, если отсутствует
if [ ! -f /etc/fail2ban/jail.local ]; then
  cat <<EOF >/etc/fail2ban/jail.local
[DEFAULT]
banaction = ufw
backend = systemd
ignoreip = 127.0.0.1/8 ::1

[sshd]
enabled = true
port = 22
logpath = /var/log/auth.log
EOF
fi

systemctl enable fail2ban --now
systemctl restart fail2ban

# ---------------------------------------------
# Fish shell
# ---------------------------------------------
say "🐚 Установка и настройка fish shell..."
apt install -y fish
chsh -s /usr/bin/fish "$USERNAME" || true
su - "$USERNAME" -c 'fish -c "set -U fish_user_paths /usr/local/sbin /usr/local/bin /usr/sbin /usr/bin /sbin /bin /usr/games /usr/local/games"'

# ---------------------------------------------
# Финальный апгрейд
# ---------------------------------------------
say "🧩 Финальный апгрейд..."
apt update && apt full-upgrade -y

# ---------------------------------------------
# Завершение
# ---------------------------------------------
echo
echo -e "${BLUE}=============================================${RESET}"
echo -e "${GREEN}✅ Установка и настройка завершена!${RESET}"
echo
echo -e "Теперь можно войти как пользователь: ${YELLOW}$USERNAME${RESET}"
echo
echo "Команды для проверки:"
echo "  su - $USERNAME"
echo "  echo \$PATH"
echo "  sudo whoami"
echo "  sudo ufw status verbose"
echo "  sudo systemctl status fail2ban"
echo
echo -e "${BLUE}🎉 Debian 13 готов к работе!${RESET}"
echo -e "${BLUE}=============================================${RESET}"
