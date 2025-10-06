# Оптимизация Ungoogled Chromium для Baikal-M + AMD RX550

## Аппаратная конфигурация
- **Процессор**: Baikal-M (8 ядер ARM Cortex-A57, 1.5 ГГц)
- **Архитектура**: ARMv8-A
- **Видеокарта**: AMD Radeon RX550 4GB
- **Память**: 8GB RAM
- **Накопитель**: 256GB SSD

## Оптимизации в данной сборке

### 1. Определение GPU (chromium-rx550-device-names.patch)
Исправлена проблема с определением RX550 в Chromium. Патч добавляет правильное определение для:
- **0x699F**: AMD Radeon RX 550 (512SP) - Lexa Pro архитектура
- **0x67FF**: AMD Radeon RX 550 (640SP) - Polaris11 архитектура

### 2. Флаги рантайма (baikal-chromium-flags.conf)
```
--ignore-gpu-blocklist                     # Игнорировать блокировку GPU
--enable-gpu-rasterization                 # Аппаратная растеризация
--enable-oop-rasterization                 # Out-of-process растеризация
--enable-accelerated-video-decode          # Аппаратное декодирование видео
--enable-features=VaapiVideoDecoder,VaapiVideoEncoder  # VA-API поддержка
--use-angle=vulkan                         # Использовать Vulkan через ANGLE
--enable-vulkan                            # Поддержка Vulkan
```

### 3. Переменные окружения (baikal-chromium-launcher.py)
```bash
LIBVA_DRIVER_NAME=radeonsi       # VA-API драйвер для AMD
MESA_LOADER_DRIVER_OVERRIDE=radeonsi
AMD_VULKAN_ICD=RADV              # Использовать RADV драйвер
RADV_PERFTEST=aco,llvm,gpl       # Экспериментальные оптимизации
MESA_GLTHREAD=true               # Многопоточный OpenGL
```

### 4. Флаги компиляции для ARM64
```bash
CFLAGS="-march=armv8-a+crc+crypto -mtune=cortex-a57 -O3 -ffast-math"
RUSTFLAGS="-C target-cpu=cortex-a57 -C target-feature=+neon,+crc,+crypto"
```

## Проверка работы аппаратного ускорения

### 1. Проверить статус GPU в браузере
Откройте `chrome://gpu` и убедитесь, что:
- **Graphics Feature Status** показывает "Hardware accelerated" для:
  - Canvas
  - Compositing
  - Multiple Raster Threads
  - Out-of-process Rasterization
  - Video Decode
  - Vulkan
  - WebGL

### 2. Проверить VA-API
```bash
# Установить vainfo для проверки
sudo pacman -S libva-utils

# Проверить доступные профили VA-API
vainfo

# Должны быть видны профили для H.264, H.265 decode/encode
```

### 3. Тест видео декодирования
```bash
# Запустить chromium с логированием VA-API
LIBVA_MESSAGING_LEVEL=2 chromium

# В логах должны быть сообщения об использовании VA-API для декодирования
```

## Решение проблем

### Если GpuMemoryBuffers показывает "Software only"
1. Убедитесь, что установлены драйверы Mesa для RX550:
   ```bash
   sudo pacman -S mesa vulkan-radeon libva-mesa-driver
   ```

2. Проверьте права доступа к GPU:
   ```bash
   ls -l /dev/dri/
   # Пользователь должен быть в группе video
   sudo usermod -a -G video $USER
   ```

3. Перезапустите с дополнительными флагами:
   ```bash
   chromium --disable-gpu-sandbox --enable-logging --vmodule=vaapi*=4
   ```

### Если видео тормозит
1. Проверьте, что используется правильный VA-API драйвер:
   ```bash
   vainfo | grep -i driver
   # Должно быть: libva info: Driver version: Mesa Gallium driver
   ```

2. Отключите аппаратное ускорение композитинга, если есть артефакты:
   ```bash
   chromium --disable-gpu-compositing
   ```

3. Для 4K видео добавьте флаги:
   ```bash
   chromium --max_old_space_size=4096 --memory-pressure-off
   ```

## Производительность

### Ожидаемые результаты
- **1080p видео**: плавное воспроизведение без загрузки CPU
- **4K видео**: воспроизведение с минимальной загрузкой CPU (5-15%)
- **WebGL**: аппаратное ускорение через Vulkan
- **Общая отзывчивость**: значительно улучшена благодаря GPU ускорению

### Мониторинг производительности
```bash
# Мониторинг загрузки GPU
watch -n1 cat /sys/class/drm/card0/device/gpu_busy_percent

# Мониторинг температуры
sensors

# Проверка использования VA-API в реальном времени
journalctl -f | grep vaapi
```

## Кросскомпиляция

### Автоматизированная сборка в Docker
```bash
# Запустить Arch Linux контейнер
sudo docker run -it --rm -v "$PWD":/work archlinux bash

# Автоматическая настройка (внутри контейнера как root)
/work/setup-docker.sh

# Переключиться на пользователя builder и начать сборку
su - builder
./smart-build.sh auto           # Умная инкрементальная сборка
./smart-build.sh full           # Полная пересборка
./smart-build.sh status         # Показать статус
```

### Ручное управление сборкой
```bash
# Детальное управление процессом
./smart-build.sh status         # Показать что уже собрано
./smart-build.sh auto           # Умная инкрементальная сборка
./smart-build.sh full           # Полная пересборка
./smart-build.sh clean          # Очистить артефакты

# Отдельные этапы
./smart-build.sh prepare        # Подготовка исходников
./smart-build.sh sysroot        # Исправление ARM64 sysroot
./smart-build.sh configure      # Конфигурация сборки
./smart-build.sh compile        # Компиляция
./smart-build.sh package        # Создание пакета

# Быстрые пересборки
./smart-build.sh ninja chrome   # Только перекомпилировать (5-15 мин)
```

### Решение проблем сборки

#### Ошибка "libudev not found" или отсутствие sysroot зависимостей
```bash
./smart-build.sh sysroot        # Автоматическое исправление зависимостей sysroot
```

#### Ошибка нехватки памяти
Система автоматически определяет доступную память и снижает параллельность сборки.
Для ручного управления:
```bash
export MAKEFLAGS="-j4"          # Для 8GB RAM
./smart-build.sh compile        # Компиляция с ограничениями
```

#### Патчи не применяются или конфликты
```bash
./smart-build.sh clean          # Полная очистка
./smart-build.sh full           # Пересборка с нуля
```

#### Быстрая отладка ошибок компиляции
```bash
./smart-build.sh ninja chrome   # Быстрая пересборка для отладки
```

### Экономия времени при разработке

#### Сценарии инкрементальной сборки:
- **Изменили код**: `./smart-build.sh ninja chrome` (5-15 мин)
- **Изменили патчи**: `./smart-build.sh prepare && ./smart-build.sh compile` (30-60 мин)
- **Изменили флаги**: `./smart-build.sh configure && ./smart-build.sh compile` (30-60 мин)
- **Полная пересборка**: `./smart-build.sh full` (2-4 часа)

#### Проверка статуса:
```bash
./smart-build.sh status
# ✅ Done - этапы которые не нужно пересобирать
# ❌ Not done - этапы которые нужно выполнить
```

Пакет будет создан как `ungoogled-chromium-baikal` и не будет конфликтовать с официальным chromium из pacman.
