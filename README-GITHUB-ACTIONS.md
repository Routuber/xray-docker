# GitHub Actions Workflow для автоматической сборки Docker образа

## 📋 Обзор

Этот репозиторий настроен с GitHub Actions workflow, который автоматически собирает и публикует Docker образ в Docker Hub при создании git тега.

## 🚀 Как использовать

### 1. Настройка секретов в GitHub

Перед первым запуском необходимо добавить секреты в настройках репозитория:

1. Перейдите в **Settings** → **Secrets and variables** → **Actions**
2. Добавьте следующие секреты:
   - `DOCKERHUB_USERNAME` - ваш username в Docker Hub
   - `DOCKERHUB_TOKEN` - Personal Access Token из Docker Hub

### 2. Создание Personal Access Token в Docker Hub

1. Войдите в [Docker Hub](https://hub.docker.com/)
2. Перейдите в **Account Settings** → **Security** → **Access Tokens**
3. Создайте новый токен с правами **Read, Write, Delete**
4. Скопируйте токен и добавьте его как секрет `DOCKERHUB_TOKEN`

### 3. Создание тега и запуск workflow

```bash
# Создайте новый тег (например, v1.0.0)
git tag v1.0.0

# Запушьте тег в репозиторий
git push origin v1.0.0
```

### 4. Мониторинг выполнения

1. Перейдите на вкладку **Actions** в вашем GitHub репозитории
2. Выберите workflow **Build and Push Docker Image**
3. Следите за выполнением шагов

## ⚙️ Конфигурация workflow

### Триггеры
Workflow запускается только при создании тегов, начинающихся с `v*`:
- `v1.0.0`
- `v2.1.0`
- `v1.0.0-rc1`

### Теги Docker образа
Каждый образ получает два тега:
1. **latest** - всегда указывает на последний собранный образ
2. **git tag** - например, `v1.0.0`

### Платформы
Собираются образы для двух архитектур:
- `linux/amd64` - для стандартных серверов
- `linux/arm64` - для Raspberry Pi и ARM-серверов

### Аргументы сборки
- `XRAY_VERSION=26.2.6` - фиксированная версия Xray Core
- `SUB_URL=""` - пустая строка (настраивается при запуске контейнера)

## 📁 Структура файлов

```
.github/
└── workflows/
    └── docker-build-push.yml    # Основной workflow файл
```

## 🔧 Ручной запуск workflow

Workflow можно запустить вручную через GitHub UI:
1. Перейдите в **Actions** → **Build and Push Docker Image**
2. Нажмите **Run workflow**
3. Выберите ветку и введите тег вручную

## 🛠️ Расширенные настройки

### Изменение версии Xray
Чтобы изменить версию Xray Core, отредактируйте файл `.github/workflows/docker-build-push.yml`:

```yaml
build-args: |
  XRAY_VERSION=27.0.0  # Новая версия
  SUB_URL=""
```

### Добавление новых платформ
Для поддержки дополнительных архитектур добавьте их в секцию `platforms`:

```yaml
platforms: linux/amd64,linux/arm64,linux/arm/v7
```

### Изменение триггеров
Чтобы workflow запускался при push в main ветку, измените секцию `on`:

```yaml
on:
  push:
    branches:
      - main
    tags:
      - 'v*'
```

## 🐛 Устранение неполадок

### Ошибка авторизации
```
Error: Cannot perform an interactive login from a non TTY device
```
**Решение:** Проверьте правильность `DOCKERHUB_USERNAME` и `DOCKERHUB_TOKEN`

### Ошибка сборки
```
failed to solve: alpine:3.20: not found
```
**Решение:** Проверьте доступность базового образа в Docker Hub

### Ошибка тегирования
```
invalid reference format
```
**Решение:** Убедитесь, что git тег соответствует формату `v*`

## 📊 Мониторинг

После успешного выполнения workflow:
1. Образ будет доступен в [Docker Hub](https://hub.docker.com/r/routuber/xray-docker)
2. В логах workflow будут показаны все теги образа
3. Можно проверить образ командой:
   ```bash
   docker pull routuber/xray-docker:latest
   docker pull routuber/xray-docker:v1.0.0
   ```

## 🔄 Обновление workflow

Для обновления версий Actions используемых в workflow:

```yaml
# Текущие версии (рекомендуется обновлять до последних):
# actions/checkout@v4
# docker/setup-qemu-action@v3
# docker/setup-buildx-action@v3
# docker/login-action@v3
# docker/metadata-action@v5
# docker/build-push-action@v5
```

## 📞 Поддержка

При возникновении проблем:
1. Проверьте логи выполнения workflow в GitHub Actions
2. Убедитесь в правильности секретов
3. Проверьте формат git тега
4. Убедитесь, что у вас есть права на запись в Docker Hub репозиторий