# 🚀 xray-docker - Transparent Xray Gateway for Docker

[![Docker](https://img.shields.io/badge/Docker-✓-blue?logo=docker)](https://hub.docker.com/r/routuber/xray-docker)
[![Xray](https://img.shields.io/badge/Xray-✓-green?logo=x)](https://xtls.github.io/)
[![License](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![GitHub](https://img.shields.io/badge/GitHub-Repository-black?logo=github)](https://github.com/routuber/xray-docker)

**Прозрачный шлюз для Docker, который автоматически направляет весь исходящий трафик через Xray без модификации кода ваших контейнеров.**

---

## ✨ Что это такое?

`xray-docker` — это Docker-образ, который решает проблему "как заставить мои контейнеры использовать Xray без изменения их кода". Вместо того чтобы настраивать каждый контейнер отдельно, вы просто добавляете этот шлюз в вашу Docker Compose конфигурацию, и весь исходящий TCP-трафик автоматически перенаправляется через Xray с балансировкой по наименьшей задержке.

### 🎯 Ключевые преимущества:
- ✅ **Без модификации кода** — ваши контейнеры работают как обычно
- ✅ **Автоматическая балансировка** — выбирает лучший сервер из подписки
- ✅ **Поддержка Routuber** — идеально работает с сервисом Routuber
- ✅ **Любые Xray подписки** — совместим со всеми провайдерами
- ✅ **Автообновление** — периодически обновляет конфигурацию
- ✅ **Простота использования** — одна строка в docker-compose.yml

---

## 🏗️ Как это работает?

### Архитектурная схема:
```
┌─────────────────────────────────────────────────────────────┐
│                    Docker Host                              │
│  ┌──────────────────────────────────────────────────────┐  │
│  │                 Docker Network                        │  │
│  │  ┌─────────────┐    ┌─────────────┐    ┌──────────┐  │  │
│  │  │   Ваш       │    │   xray-gw   │    │  Другие  │  │  │
│  │  │   Контейнер │────│   (шлюз)    │────│ Контейнеры│  │  │
│  │  │             │    │             │    │          │  │  │
│  │  └─────────────┘    └─────────────┘    └──────────┘  │  │
│  │          │                    │                       │  │
│  └──────────┼────────────────────┼───────────────────────┘  │
│             │                    │                          │
│             ▼                    ▼                          │
│      ┌──────────────┐    ┌─────────────────┐                │
│      │  Локальный   │    │   iptables      │                │
│      │   Трафик     │    │   REDIRECT      │                │
│      │              │    │   Правила       │                │
│      └──────────────┘    └─────────────────┘                │
│             │                    │                          │
│             └────────────────────┘                          │
│                             │                               │
│                             ▼                               │
│                    ┌─────────────────┐                      │
│                    │    Xray Core    │                      │
│                    │  (балансировщик)│                      │
│                    └─────────────────┘                      │
│                             │                               │
│                             ▼                               │
│               ┌─────────────────────────┐                  │
│               │  Серверы из подписки    │                  │
│               │  (Routuber/другие)      │                  │
│               └─────────────────────────┘                  │
└─────────────────────────────────────────────────────────────┘
```

### Технические детали:
1. **iptables REDIRECT** — автоматически настраивает правила для перенаправления TCP-трафика на порт 12345
2. **Xray dokodemo-door** — принимает перенаправленный трафик через inbound
3. **Балансировка leastPing** — автоматически выбирает сервер с наименьшей задержкой
4. **Автообновление подписки** — периодически загружает и применяет обновления
5. **Обход локальных адресов** — не перенаправляет трафик к localhost и приватным сетям

---

## 🚀 Быстрый старт

### ⚠️ Важное примечание о портах

**Критически важно:** Если вашему приложению нужны публичные порты (например, веб-сервер на порту 80/443 или API на порту 8080), вы должны открывать их **не в вашем контейнере, а в xray-gw контейнере**. Это потому, что все контейнеры используют `network_mode: "service:xray-gw"` и работают в одном сетевом пространстве имен.

**Пример правильной настройки портов:**
```yaml
services:
  xray-gw:
    build: .
    container_name: xray-gw
    cap_add:
      - NET_ADMIN
      - NET_RAW
    sysctls:
      - net.ipv4.ip_forward=1
      - net.ipv4.conf.all.route_localnet=1
    environment:
      SUB_URL: "https://rtbr.top/indocker"  # Ваша подписка Routuber (Купить в Telegram: @routuber_bot)
      UPDATE_INTERVAL: "1800"  # Обновлять каждые 30 минут
    ports:
      - "80:80"    # Веб-сервер
      - "443:443"  # HTTPS
      - "8080:8080" # API
    restart: unless-stopped

  your-app:
    image: your-app:latest
    network_mode: "service:xray-gw"  # Ключевая настройка!
    depends_on:
      - xray-gw
    # НЕ указывайте ports здесь! Все порты открываются в xray-gw
```

### 1. Базовый пример с Routuber

```yaml
# docker-compose.yml
services:
  xray-gw:
    build: .
    container_name: xray-gw
    cap_add:
      - NET_ADMIN
      - NET_RAW
    sysctls:
      - net.ipv4.ip_forward=1
      - net.ipv4.conf.all.route_localnet=1
    environment:
      SUB_URL: "https://rtbr.top/indocker"  # Ваша подписка Routuber (Купить в Telegram: @routuber_bot)
      UPDATE_INTERVAL: "1800"  # Обновлять каждые 30 минут
    restart: unless-stopped

  your-app:
    image: your-app:latest
    network_mode: "service:xray-gw"  # Ключевая настройка!
    depends_on:
      - xray-gw
```

### 2. Сборка и запуск

```bash
# Клонируйте репозиторий
git clone https://github.com/routuber/xray-docker.git
cd xray-docker

# Соберите образ
docker build -t xray-docker .

# Или используйте готовый образ
docker pull routuber/xray-docker

# Запустите с Docker Compose
docker-compose up -d
```

### 3. Проверка работы

```bash
# Проверьте, что xray запущен
docker logs xray-gw

# Проверьте iptables правила внутри контейнера
docker exec xray-gw iptables-legacy -t nat -L -n -v

# Протестируйте подключение из тестового контейнера
docker run --rm --network container:xray-gw curlimages/curl curl -s https://api.ipify.org
```

---

## ⚙️ Конфигурация

### Переменные окружения:

| Переменная | По умолчанию | Описание |
|------------|--------------|----------|
| `SUB_URL` | (обязательно) | URL подписки Xray (JSON формат) |
| `UPDATE_INTERVAL` | `1800` | Интервал обновления подписки в секундах |
| `XRAY_VERSION` | `26.2.6` | Версия Xray Core |

### Параметры сборки (build args):

```dockerfile
# В Dockerfile или docker-compose.yml
args:
  SUB_URL: "https://your-subscription-url"
  XRAY_VERSION: "26.2.6"
```

---

## 🔗 Интеграция с Routuber

### Почему Routuber идеально подходит?

[Routuber](https://rtbr.top/indocker) предоставляет:
- **Стабильные серверы** с высокой доступностью
- **Автоматическое обновление** списка серверов
- **Поддержку актуальных протоколов** Xray (VLESS, XHTTP)
- **Удобный формат подписки** JSON, который идеально парсится xray-docker

### Пример конфигурации для Routuber:

```yaml
services:
  xray-gw:
    build:
      context: .
      args:
        SUB_URL: "https://rtbr.top/indocker"
    # ... остальная конфигурация
```

---

## 🌐 Поддержка любых Xray подписок

### Совместимые форматы подписок:

1. **Стандартный JSON** (Routuber, большинство провайдеров):
```json
[
  {
    "remarks": "Server 1",
    "address": "server1.example.com",
    "port": 443,
    "protocol": "vless",
    "settings": { ... }
  }
]
```

2. **Base64-encoded подписки** (автоматически декодируются):
```bash
# Укажите URL, который возвращает base64-encoded JSON
SUB_URL="https://provider.com/sub?token=xxx&format=base64"
```

3. **Мульти-подписки** (несколько серверов в одном JSON):
```json
{
  "servers": [
    { "name": "US-1", ... },
    { "name": "EU-1", ... },
    { "name": "ASIA-1", ... }
  ]
}
```

### Популярные провайдеры:
- ✅ **Routuber** (рекомендуется) — https://rtbr.top/indocker
- ✅ **AnyXrayProvider** — любой провайдер с JSON-подпиской
- ✅ **Самодельные подписки** — ваш собственный сервер

---

## 🏗️ Расширенные примеры

### 1. Мульти-сервисная архитектура

```yaml
services:
  xray-gw:
    build: .
    container_name: xray-gw
    cap_add: [NET_ADMIN, NET_RAW]
    sysctls:
      - net.ipv4.ip_forward=1
    environment:
      SUB_URL: ${SUB_URL}
    restart: unless-stopped

  web-app:
    image: nginx:alpine
    network_mode: "service:xray-gw"
    depends_on: [xray-gw]

  api-service:
    image: your-api:latest
    network_mode: "service:xray-gw"
    depends_on: [xray-gw]

  database:
    image: postgres:15
    network_mode: "service:xray-gw"
    environment:
      POSTGRES_PASSWORD: ${DB_PASSWORD}
    depends_on: [xray-gw]
```

### 2. Kubernetes Deployment

```yaml
# xray-gw-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: xray-gw
spec:
  replicas: 1
  selector:
    matchLabels:
      app: xray-gw
  template:
    metadata:
      labels:
        app: xray-gw
    spec:
      containers:
      - name: xray-gw
        image: routuber/xray-docker:latest
        env:
        - name: SUB_URL
          value: "https://rtbr.top/indocker"
        securityContext:
          capabilities:
            add: ["NET_ADMIN", "NET_RAW"]
        volumeMounts:
        - name: sysctl
          mountPath: /proc/sys
      volumes:
      - name: sysctl
        hostPath:
          path: /proc/sys
```

### 3. Кастомная конфигурация Xray

```bash
# Если нужно изменить базовый шаблон
cp base.template.json custom.template.json
# Отредактируйте custom.template.json
# Затем соберите образ с кастомным шаблоном
```

---

## ❓ Частые вопросы (FAQ)

### ❔ Как проверить, что трафик идет через Xray?

```bash
# 1. Проверьте логи xray
docker logs xray-gw

# 2. Проверьте активные подключения
docker exec xray-gw ss -tunp

# 3. Проверьте внешний IP
docker run --rm --network container:xray-gw curlimages/curl curl -s https://api.ipify.org
```

### ❔ Можно ли использовать без Docker Compose?

Да, можно запускать напрямую:

```bash
docker run -d \
  --name xray-gw \
  --cap-add=NET_ADMIN \
  --cap-add=NET_RAW \
  --sysctl net.ipv4.ip_forward=1 \
  -e SUB_URL="https://rtbr.top/indocker" \
  routuber/xray-docker
```

### ❔ Как добавить исключения для некоторых доменов?

Отредактируйте `base.template.json` и добавьте правила в секцию `routing.rules`:

```json
{
  "type": "field",
  "domain": ["google.com", "github.com"],
  "outboundTag": "direct"
}
```

### ❔ Поддерживается ли UDP трафик?

Да, контейнер настраивает TPROXY для UDP на порту 12346. Для активации требуется `privileged: true` в docker-compose.yml.

### ❔ Как обновить подписку вручную?

```bash
docker exec xray-gw /usr/local/bin/update-sub.sh
```

---

## 🛠️ Разработка и сборка

### Локальная разработка:

```bash
# 1. Клонируйте репозиторий
git clone https://github.com/routuber/xray-docker.git
cd xray-docker

# 2. Соберите образ
docker build -t xray-docker .

# 3. Протестируйте с локальной подпиской
echo '[
  {
    "remarks": "Local Test",
    "address": "test.server",
    "port": 443,
    "protocol": "vless",
    "settings": {}
  }
]' > test-sub.json

# 4. Запустите с тестовой подпиской
docker run -d \
  --name xray-test \
  --cap-add=NET_ADMIN \
  -v $(pwd)/test-sub.json:/etc/xray/runtime/sub.json \
  xray-docker
```

### Структура проекта:

```
xray-docker/
├── Dockerfile              # Основной Dockerfile
├── docker-compose.yml      # Пример Docker Compose
├── entrypoint.sh          # Точка входа
├── update-sub.sh          # Скрипт обновления подписки
├── build_config.py        # Генератор конфигурации
├── base.template.json     # Базовый шаблон Xray
└── README.md              # Этот файл
```

---

## 📝 Лицензия

Этот проект распространяется под лицензией MIT. См. файл [LICENSE](LICENSE) для подробностей.

---

## 🤝 Вклад в проект

Мы приветствуем вклады! Пожалуйста:

1. Форкните репозиторий
2. Создайте ветку для вашей функции (`git checkout -b feature/amazing-feature`)
3. Закоммитьте изменения (`git commit -m 'Add amazing feature'`)
4. Запушьте в ветку (`git push origin feature/amazing-feature`)
5. Откройте Pull Request

---

## ⭐ Поддержка проекта

Если этот проект был полезен для вас, пожалуйста:

1. Поставьте звезду на GitHub ⭐
2. Расскажите о нем коллегам
3. Создайте issue для предложений улучшений
4. Рассмотрите возможность [поддержать Routuber](https://rtbr.top/indocker)

---

**Счастливого использования! 🚀**

*Создано с ❤️ для сообщества Docker и Xray*