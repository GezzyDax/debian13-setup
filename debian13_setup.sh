#!/usr/bin/env bash
# =========================================
# Debian 13 (Trixie) Initial Setup Script (secure)
# Автор: gezzy
# =========================================
# Безопасная и повторно запускаемая установка:
#  - Создание пользователя и sudo
#  - Обновление системы
#  - Настройка UFW, SSH (только по ключу)
#  - Fail2Ban, Fish shell, PATH и базовые пакеты
# =========================================

set -e

GREEN="\e[32m"; YELLOW="\e[33m"; RED="\e[31m"; BLUE="\e[34m"; RESET="\e[0m"
say() { echo -e "${GREEN}==>${RESET} $1"; }
warn() { echo -e "${YELLOW}⚠ ${RESET}$1"; }
error() { echo -e "${RED}❌ ${RESET}$1"; }

# Проверка прав root
if [ "$EUID" -ne 0 ]; then
  error "Запусти этот скрипт от root: sudo bash debian13_setup.sh"
  exit 1
fi

clear
echo -e "${BLUE}=============================================${RESET}"
echo -e "${BLUE}🧰 Debian 13 (Trixie) — базовая настройка (secure)${RESET}"
echo -e "${BLUE}=============================================${RESET}"
echo

# ---------- Проверка apt ----------
say "🔄 Проверяю систему..."
apt update -y >/dev/null

# ---------- Установка sudo и adduser ----------
say "🧰 Устанавливаю необходимые пакеты (sudo, adduser)..."
apt install -y sudo adduser

# ---------- Создание пользователя ----------
read -rp "👤 Введите имя пользователя (например: user): " USERNAME
USERNAME=$(echo "$USERNAME" | tr -cd '[:alnum:]_.@-')

if [[ -z "$USERNAME" ]]; then
  error "Некорректное имя пользователя. Допустимы только буквы, цифры, -, _, ., @"
  exit 1
fi

if id "$USERNAME" &>/dev/null; then
  say "✅ Пользователь ${USERNAME} уже существует."
else
  say "👤 Создаю пользователя ${USERNAME}..."
  adduser --gecos "" "$USERNAME"
fi

# ---------- Добавляем пользователя в sudo ----------
if groups "$USERNAME" | grep -qw sudo; then
  say "✅ ${USERNAME} уже в группе sudo."
else
  say "➕ Добавляю ${USERNAME} в группу sudo..."
  usermod -aG sudo "$USERNAME"
fi

# ---------- Настройка PATH ----------
PATH_LINE='export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games"'
say "🧩 Настраиваю PATH..."
grep -qxF "$PATH_LINE" /root/.bashrc || echo "$PATH_LINE" >> /root/.bashrc
su - "$USERNAME" -c "grep -qxF '$PATH_LINE' ~/.bashrc || echo '$PATH_LINE' >> ~/.bashrc"
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games"

# ---------- Обновление системы ----------
say "🔄 Обновление системы..."
apt update && apt full-upgrade -y
apt autoremove --purge -y
apt clean

# ---------- Базовые пакеты ----------
BASE_PKGS=(
  adduser passwd apt-utils man-db manpages bash-completion lsb-release
  procps psmisc net-tools iproute2 iputils-ping wget curl less vim nano tar
  gzip bzip2 xz-utils unzip coreutils findutils grep sed gawk file lsof gnu-which
)
say "⚙️ Установка базовых пакетов..."
apt install -y "${BASE_PKGS[@]}"

# ---------- Утилиты ----------
ADMIN_PKGS=(
  htop btop ncdu rsync screen tmux cron ca-certificates gnupg locales tzdata
  neofetch git zip p7zip-full debconf debconf-utils software-properties-common
  apt-transport-https jq fzf ripgrep fd-find bat exa
)
say "🧱 Установка утилит администратора..."
apt install -y "${ADMIN_PKGS[@]}"

# ---------- Сеть ----------
NET_PKGS=(network-manager dnsutils traceroute nmap netcat-openbsd openssh-client)
say "🌐 Настройка сети..."
apt install -y "${NET_PKGS[@]}"
systemctl enable NetworkManager >/dev/null 2>&1 || true

# ---------- Безопасность ----------
SEC_PKGS=(ufw fail2ban openssh-server)
say "🔒 Установка и настройка безопасности..."
apt install -y "${SEC_PKGS[@]}"

# ---------- UFW ----------
say "🧩 Настройка правил брандмауэра..."
ufw --force reset >/dev/null
ufw default deny incoming >/dev/null
ufw default allow outgoing >/dev/null

for PORT in 22 80 443; do
  if ! ufw status | grep -q "$PORT/tcp"; then
    ufw allow "$PORT"/tcp comment "Allow port $PORT"
  fi
done

ufw --force enable >/dev/null
say "✅ Брандмауэр активен."
ufw status verbose

# ---------- SSH ----------
say "🔐 Настройка SSH (только ключи, root-запрет)..."
systemctl enable --now ssh >/dev/null

# Запрос SSH-ключа
echo
read -rp "🔑 Вставь SSH public key для пользователя ${USERNAME}: " PUBKEY

if [[ -n "$PUBKEY" ]]; then
  su - "$USERNAME" -c "mkdir -p ~/.ssh && chmod 700 ~/.ssh"
  echo "$PUBKEY" > "/home/$USERNAME/.ssh/authorized_keys"
  chmod 600 "/home/$USERNAME/.ssh/authorized_keys"
  chown -R "$USERNAME":"$USERNAME" "/home/$USERNAME/.ssh"
  say "✅ Ключ добавлен в /home/$USERNAME/.ssh/authorized_keys"
else
  warn "⚠ Ключ не указан. SSH-доступ может быть невозможен."
fi

# Настройка sshd_config
SSHD_CONFIG="/etc/ssh/sshd_config"
cp "$SSHD_CONFIG" "${SSHD_CONFIG}.bak_$(date +%F_%T)"

sed -i 's/^#*PermitRootLogin.*/PermitRootLogin no/' "$SSHD_CONFIG"
sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication no/' "$SSHD_CONFIG"
sed -i 's/^#*PubkeyAuthentication.*/PubkeyAuthentication yes/' "$SSHD_CONFIG"

systemctl restart ssh >/dev/null
say "✅ SSH настроен: вход только по ключу, root-доступ запрещён."

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

touch /var/log/auth.log
chown --silent syslog:adm /var/log/auth.log 2>/dev/null || true

systemctl enable fail2ban --now >/dev/null
systemctl restart fail2ban >/dev/null
systemctl is-active --quiet fail2ban && say "✅ Fail2Ban работает." || warn "⚠ Fail2Ban не запущен!"

# ---------- Fish ----------
say "🐚 Установка и настройка Fish..."
if ! command -v fish &>/dev/null; then
  apt install -y fish
fi
USER_SHELL=$(getent passwd "$USERNAME" | cut -d: -f7)
if [ "$USER_SHELL" != "/usr/bin/fish" ]; then
  chsh -s /usr/bin/fish "$USERNAME" || true
fi
su - "$USERNAME" -c 'fish -c "set -U fish_user_paths /usr/local/sbin /usr/local/bin /usr/sbin /usr/bin /sbin /bin /usr/games /usr/local/games"' || true

# ---------- Финал ----------
say "🧩 Финальный апгрейд..."
apt update && apt full-upgrade -y

echo
echo -e "${BLUE}=============================================${RESET}"
echo -e "${GREEN}✅ Установка и настройка завершена!${RESET}"
echo
echo -e "Теперь можно входить только по ключу как: ${YELLOW}$USERNAME${RESET}"
echo
echo "Команды для проверки:"
echo "  su - $USERNAME"
echo "  sudo whoami"
echo "  sudo ufw status verbose"
echo "  sudo systemctl status ssh"
echo "  sudo systemctl status fail2ban"
echo
echo -e "${RED}⚠ Важно:${RESET} root-доступ по SSH отключён, парольный вход запрещён."
echo
echo -e "${BLUE}🎉 Debian 13 защищён и готов к работе!${RESET}"
echo -e "${BLUE}=============================================${RESET}"
