#!/usr/bin/env bash
# =========================================
# Debian 13 (Trixie) Initial Setup Script
# Автор: GezzyDax
# =========================================
# Автоматическая базовая настройка Debian:
#  - Обновление системы
#  - Создание пользователя
#  - Настройка sudo
#  - Установка базовых утилит
#  - Настройка UFW, SSH, Fail2Ban
#  - Fish shell и PATH
# =========================================

set -e

# ---------- Цвета ----------
GREEN="\e[32m"; YELLOW="\e[33m"; RED="\e[31m"; BLUE="\e[34m"; RESET="\e[0m"
say() { echo -e "${GREEN}==>${RESET} $1"; }
warn() { echo -e "${YELLOW}⚠ ${RESET}$1"; }
error() { echo -e "${RED}❌ ${RESET}$1"; }

# ---------- Проверка root ----------
if [ "$EUID" -ne 0 ]; then
  error "Запусти этот скрипт от root: sudo bash debian13_setup.sh"
  exit 1
fi

clear
echo -e "${BLUE}=============================================${RESET}"
echo -e "${BLUE}🧰 Debian 13 (Trixie) — базовая настройка${RESET}"
echo -e "${BLUE}=============================================${RESET}"
echo

# ---------- Обновление apt ----------
say "🔄 Проверяю систему..."
apt update -y >/dev/null

# ---------- sudo ----------
if ! command -v sudo &>/dev/null; then
  say "🧰 Устанавливаю sudo..."
  apt install -y sudo
else
  say "✅ sudo уже установлен."
fi

# ---------- Создание пользователя ----------
read -rp "👤 Введите имя пользователя (например: user): " USERNAME
if id "$USERNAME" &>/dev/null; then
  say "✅ Пользователь ${USERNAME} уже существует."
else
  say "👤 Создаю пользователя ${USERNAME}..."
  adduser --gecos "" "$USERNAME"
fi

if groups "$USERNAME" | grep -qw sudo; then
  say "✅ ${USERNAME} уже в группе sudo."
else
  say "➕ Добавляю ${USERNAME} в группу sudo..."
  usermod -aG sudo "$USERNAME"
fi

# ---------- Настройка PATH ----------
say "🧩 Настраиваю PATH..."
PATH_LINE='export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games"'
if ! grep -q "$PATH_LINE" /root/.bashrc 2>/dev/null; then
  echo "$PATH_LINE" >> /root/.bashrc
fi
su - "$USERNAME" -c "grep -q '$PATH_LINE' ~/.bashrc || echo '$PATH_LINE' >> ~/.bashrc"

export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games"

# ---------- Обновление системы ----------
say "🔄 Обновление системы..."
apt update && apt full-upgrade -y
apt autoremove --purge -y
apt clean

# ---------- Базовые пакеты ----------
BASE_PACKAGES=(
  adduser passwd apt-utils man-db manpages bash-completion lsb-release
  procps psmisc net-tools iproute2 iputils-ping wget curl less vim nano tar
  gzip bzip2 xz-utils unzip coreutils findutils grep sed gawk file lsof gnu-which
)

say "⚙️ Установка базовых пакетов..."
apt install -y "${BASE_PACKAGES[@]}"

# ---------- Утилиты администратора ----------
ADMIN_PACKAGES=(
  htop btop ncdu rsync screen tmux cron ca-certificates gnupg locales tzdata
  neofetch git zip p7zip-full debconf debconf-utils software-properties-common
  apt-transport-https jq fzf ripgrep fd-find bat exa
)

say "🧱 Установка утилит администратора..."
apt install -y "${ADMIN_PACKAGES[@]}"

# ---------- Сеть ----------
NETWORK_PACKAGES=(network-manager dnsutils traceroute nmap netcat-openbsd openssh-client)
say "🌐 Настройка сети..."
apt install -y "${NETWORK_PACKAGES[@]}"
systemctl enable NetworkManager >/dev/null 2>&1 || true

# ---------- Безопасность ----------
SECURITY_PACKAGES=(ufw fail2ban openssh-server)
say "🔒 Установка и настройка безопасности..."
apt install -y "${SECURITY_PACKAGES[@]}"

# ---------- Настройка UFW ----------
say "🧩 Настройка правил брандмауэра..."
ufw --force reset >/dev/null
ufw default deny incoming >/dev/null
ufw default allow outgoing >/dev/null

# Проверяем, открыты ли порты, прежде чем добавлять
for PORT in 22 80 443; do
  if ! ufw status | grep -q "$PORT/tcp"; then
    ufw allow ${PORT}/tcp comment "Port ${PORT}"
  fi
done

# Разрешаем пинг (icmp)
if ! ufw status | grep -q "proto icmp"; then
  ufw allow in proto icmp comment 'Allow Ping (ICMP Echo Request)'
fi

ufw --force enable >/dev/null
say "✅ Брандмауэр активен:"
ufw status verbose

# ---------- SSH ----------
say "🔐 Настройка SSH..."
systemctl enable --now ssh >/dev/null
systemctl restart ssh >/dev/null

# ---------- Fail2Ban ----------
say "🧱 Настройка Fail2Ban..."
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

# Создаём auth.log, если его нет
if [ ! -f /var/log/auth.log ]; then
  touch /var/log/auth.log
  chown syslog:adm /var/log/auth.log || true
fi

systemctl enable fail2ban --now >/dev/null
systemctl restart fail2ban >/dev/null
systemctl is-active --quiet fail2ban && say "✅ Fail2Ban работает." || warn "⚠ Fail2Ban не запущен!"

# ---------- Fish shell ----------
say "🐚 Установка и настройка fish shell..."
if ! command -v fish &>/dev/null; then
  apt install -y fish
fi

CURRENT_SHELL=$(getent passwd "$USERNAME" | cut -d: -f7)
if [ "$CURRENT_SHELL" != "/usr/bin/fish" ]; then
  chsh -s /usr/bin/fish "$USERNAME" || true
fi

su - "$USERNAME" -c 'fish -c "set -U fish_user_paths /usr/local/sbin /usr/local/bin /usr/sbin /usr/bin /sbin /bin /usr/games /usr/local/games"' || true

# ---------- Финальный апгрейд ----------
say "🧩 Финальный апгрейд..."
apt update && apt full-upgrade -y

# ---------- Завершение ----------
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
echo -e "${BLUE}🎉 Debian 13 полностью готов к работе!${RESET}"
echo -e "${BLUE}=============================================${RESET}"
