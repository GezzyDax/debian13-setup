#!/usr/bin/env bash
# =========================================
# Debian 13 (Trixie) — настройка пользователя Ansible
# Автор: gezzy
# =========================================
# Что делает:
#   - Создаёт пользователя ansible
#   - Добавляет его в sudo
#   - Настраивает SSH-доступ только по ключу
#   - Отключает парольный вход
#   - Настраивает sudo без пароля
# =========================================

set -e

GREEN="\e[32m"; YELLOW="\e[33m"; RED="\e[31m"; BLUE="\e[34m"; RESET="\e[0m"
say() { echo -e "${GREEN}==>${RESET} $1"; }
warn() { echo -e "${YELLOW}⚠ ${RESET}$1"; }
error() { echo -e "${RED}❌ ${RESET}$1"; }

if [ "$EUID" -ne 0 ]; then
  error "Запусти этот скрипт от root: sudo bash setup-ansible-user.sh"
  exit 1
fi

clear
echo -e "${BLUE}=============================================${RESET}"
echo -e "${BLUE}🤖 Настройка пользователя Ansible${RESET}"
echo -e "${BLUE}=============================================${RESET}"
echo

USERNAME="ansible"

# ---------- Проверка, есть ли пользователь ----------
if id "$USERNAME" &>/dev/null; then
  say "✅ Пользователь ${USERNAME} уже существует."
else
  say "👤 Создаю пользователя ${USERNAME}..."
  adduser --disabled-password --gecos "" "$USERNAME"
fi

# ---------- Добавляем в sudo ----------
if groups "$USERNAME" | grep -qw sudo; then
  say "✅ ${USERNAME} уже в группе sudo."
else
  say "➕ Добавляю ${USERNAME} в группу sudo..."
  usermod -aG sudo "$USERNAME"
fi

# ---------- Настройка sudo без пароля ----------
SUDO_FILE="/etc/sudoers.d/99-ansible-nopasswd"
if [ ! -f "$SUDO_FILE" ]; then
  say "⚙️ Разрешаю ansible выполнять sudo без пароля..."
  echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" > "$SUDO_FILE"
  chmod 440 "$SUDO_FILE"
else
  say "✅ Права sudo уже настроены."
fi

# ---------- Настройка SSH ----------
say "🔑 Настройка SSH-доступа..."
read -rp "Вставь SSH public key для ansible: " PUBKEY

if [[ -n "$PUBKEY" ]]; then
  su - "$USERNAME" -c "mkdir -p ~/.ssh && chmod 700 ~/.ssh"
  echo "$PUBKEY" > "/home/$USERNAME/.ssh/authorized_keys"
  chmod 600 "/home/$USERNAME/.ssh/authorized_keys"
  chown -R "$USERNAME":"$USERNAME" "/home/$USERNAME/.ssh"
  say "✅ Ключ добавлен в /home/$USERNAME/.ssh/authorized_keys"
else
  warn "⚠ SSH ключ не указан. Пользователь не сможет войти по ключу."
fi

# ---------- Удаляем пароль ----------
say "🧹 Удаляю пароль для ansible..."
passwd -d "$USERNAME" >/dev/null 2>&1 || true
passwd -l "$USERNAME" >/dev/null 2>&1 || true

# ---------- Настройка ограничений SSH ----------
SSHD_CONFIG="/etc/ssh/sshd_config"
BACKUP="/etc/ssh/sshd_config.bak_$(date +%F_%T)"
cp "$SSHD_CONFIG" "$BACKUP"

if ! grep -q "AllowUsers" "$SSHD_CONFIG"; then
  echo "AllowUsers ansible" >> "$SSHD_CONFIG"
else
  sed -i "s/^AllowUsers.*/AllowUsers ansible/" "$SSHD_CONFIG"
fi

sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication no/' "$SSHD_CONFIG"
sed -i 's/^#*PermitRootLogin.*/PermitRootLogin no/' "$SSHD_CONFIG"
sed -i 's/^#*PubkeyAuthentication.*/PubkeyAuthentication yes/' "$SSHD_CONFIG"

systemctl restart ssh >/dev/null

say "✅ SSH настроен: только ключи, root-вход запрещён, доступ только ansible."
say "🎉 Пользователь ansible готов к работе."

echo
echo -e "${BLUE}=============================================${RESET}"
echo -e "${GREEN}✅ Готово!${RESET}"
echo
echo -e "Проверка подключения:"
echo -e "  ssh ansible@<IP> -i ~/.ssh/<private_key>"
echo
echo -e "Для Ansible в inventory:"
echo -e "  ansible_user=ansible"
echo -e "  ansible_ssh_private_key_file=~/.ssh/<private_key>"
echo
echo -e "${BLUE}=============================================${RESET}"
