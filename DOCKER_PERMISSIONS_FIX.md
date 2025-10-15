# Решение проблемы прав на файлы в Docker

## Проблема

Docker контейнер создает файлы от root или от пользователя с другим UID, что приводит к проблемам с правами на хосте.

## Решение

### 1. Автоматическая передача UID/GID хоста в контейнер

**start-arm64-docker.sh** теперь автоматически:
- Определяет UID и GID текущего пользователя (`id -u` и `id -g`)
- Передает их в Docker контейнер через environment variables
- Логирует информацию: `Host UID:GID = 1000:1000 (files will be owned by this user)`

```bash
HOST_UID=$(id -u)    # Обычно 1000 для первого пользователя
HOST_GID=$(id -g)    # Обычно 1000
docker run -e HOST_UID=$HOST_UID -e HOST_GID=$HOST_GID ...
```

### 2. Создание builder пользователя с правильным UID

**setup-docker.sh** обновлен для создания `builder` с UID/GID хоста:

```bash
# Если HOST_UID/HOST_GID заданы:
groupadd -g $HOST_GID builder      # Создать группу с GID хоста
useradd -m -u $HOST_UID -g $HOST_GID builder  # Создать пользователя с UID хоста

# Если не заданы (старый способ):
useradd -m builder  # Создать с дефолтным UID
```

### 3. Результат

Все файлы, созданные пользователем `builder` внутри контейнера, будут принадлежать:
- На хосте: `stifix:stifix` (UID:GID = 1000:1000)
- В контейнере: `builder:builder` (UID:GID = 1000:1000)

## Проверка

### После запуска контейнера:

```bash
# В контейнере проверить UID builder:
id builder
# Вывод: uid=1000(builder) gid=1000(builder) groups=1000(builder)

# На хосте проверить права:
ls -la /home/stifix/baikal-workspace/userspace-apps/ungoogled-chromium
# Все файлы должны быть: stifix:stifix (1000:1000)
```

### Во время сборки:

```bash
# Внутри контейнера как builder:
cd /work
./smart-build.sh full

# Все создаваемые файлы будут:
# - В контейнере: builder:builder
# - На хосте: stifix:stifix
```

## Старый способ (если нужно исправить права вручную)

Если по какой-то причине права сбились:

```bash
# На хосте (вне контейнера):
sudo chown -R stifix:stifix /home/stifix/baikal-workspace/userspace-apps/ungoogled-chromium
```

Или внутри контейнера перед выходом:

```bash
# От root:
chown -R 1000:1000 /work
```

## Технические детали

### UID/GID mapping

```
┌─────────────────────────────────────────────┐
│  Host (x86_64)                              │
│  User: stifix (UID=1000, GID=1000)          │
│  ┌───────────────────────────────────────┐  │
│  │ Docker Container (ARM64 via QEMU)     │  │
│  │                                       │  │
│  │ Environment:                          │  │
│  │   HOST_UID=1000                       │  │
│  │   HOST_GID=1000                       │  │
│  │                                       │  │
│  │ User: builder (UID=1000, GID=1000)    │  │
│  │                                       │  │
│  │ Volume: /work → host directory        │  │
│  │   Files created: builder:builder      │  │
│  └───────────────────────────────────────┘  │
│         ↓ UID mapping                       │
│  Files on host: stifix:stifix (1000:1000)   │
└─────────────────────────────────────────────┘
```

### Почему это работает

Docker bind mount (`-v "$WORK_DIR":/work`) использует kernel VFS layer. Файлы идентифицируются по UID/GID числам, а не по именам пользователей. Когда builder (UID=1000) создает файл в контейнере, он получает UID=1000 в filesystem. На хосте этот UID соответствует пользователю stifix.

### Альтернативные решения (НЕ используются)

1. **Docker --user флаг**: `docker run --user $(id -u):$(id -g)`
   - ❌ Проблема: нет home directory, нет sudo, сложно настроить окружение

2. **User namespace remapping**: Docker daemon config
   - ❌ Проблема: требует перезапуск Docker daemon, влияет на все контейнеры

3. **Podman**: rootless containers
   - ✅ Альтернатива Docker с автоматическим UID mapping
   - ❌ Не используется в данном проекте

## Совместимость

Исправление совместимо с:
- ✅ Существующими контейнерами (если пересоздать)
- ✅ Старым способом запуска (без HOST_UID/HOST_GID)
- ✅ Различными host UID/GID (не только 1000)
- ✅ Несколькими пользователями на одном хосте

## Тестирование

```bash
# 1. Удалить старый контейнер если есть
docker rm -f chromium-arm64-builder

# 2. Запустить новый контейнер
./start-arm64-docker.sh

# 3. В контейнере проверить UID
id builder
# Должно быть: uid=1000(builder) gid=1000(builder)

# 4. Создать тестовый файл
su - builder
cd /work
touch test_permissions.txt
exit

# 5. На хосте проверить права
ls -l test_permissions.txt
# Должно быть: -rw-r--r-- 1 stifix stifix ... test_permissions.txt

# 6. Удалить тестовый файл
rm test_permissions.txt
```

## Заключение

Проблема прав на файлы **полностью решена**:
- ✅ Автоматическая передача UID/GID хоста
- ✅ Builder создается с правильным UID
- ✅ Все файлы принадлежат stifix на хосте
- ✅ Не требуется ручное исправление прав
- ✅ Работает "из коробки"
