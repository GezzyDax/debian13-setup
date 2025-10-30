# Debian 13 (Trixie) — базовая настройка

## Базовая установка системы
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/GezzyDax/debian13-setup/main/debian13_setup.sh)
````

-  Устанавливает и обновляет базовые пакеты
-  Настраивает `sudo`, `UFW`, `Fail2Ban`, `SSH`
-  Отключает root-вход и парольную авторизацию
-  Разрешает вход только по SSH-ключу

---

## Пользователь Ansible

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/GezzyDax/debian13-setup/main/ansible-user.sh)
```

-  Создаёт пользователя `ansible`
-  Добавляет в группу `sudo`
-  Разрешает `sudo` без пароля
-  Настраивает вход только по SSH-ключу 

---
