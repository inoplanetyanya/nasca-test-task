#!/usr/bin/env bash

# Строгий режим Bash для отлова ошибок
set -euo pipefail

# Путь к лог-файлу
LOG_FILE="/tmp/server-info.log"

# Функция для вывода справки
show_help() {
    cat << EOF
Использование: $0 [URL1] [URL2] ...

Скрипт собирает информацию о системе и проверяет доступность сервисов по HTTP.

Параметры:
  --help    Показать эту справку и выйти

Примеры:
  $0                                                 # Только системная диагностика
  $0 http://localhost:5000/health                    # Проверка одного сервиса
  $0 http://localhost:5000/health https://google.com # Проверка нескольких сервисов

Выходной код (Exit Code):
  0 - Все сервисы доступны (или запуск без проверки URL)
  1 - Хотя бы один сервис вернул ошибку или недоступен
EOF
}

# Функция для логирования на экран и в файл одновременно
log_message() {
    echo "$1" | tee -a "$LOG_FILE"
}

# Проверка флага --help
if [ "${1:-}" = "--help" ]; then
    show_help
    exit 0
fi

# Инициализация лог-файла заголовком с датой
TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")
{
    echo "========================================"
    echo "Log Session Started at $TIMESTAMP"
    echo "========================================"
} >> "$LOG_FILE"

# 1. Системная информация
log_message "=== Server Diagnostics ==="
log_message "Date:     $TIMESTAMP"
log_message "Hostname: $(hostname)"
if [ -f /etc/os-release ]; then
    # Получаем красивое имя ОС из системного файла
    OS_NAME=$(grep -oP '(?<=^PRETTY_NAME=")[^"]+' /etc/os-release || grep -oP '(?<=^NAME=")[^"]+' /etc/os-release)
    log_message "OS:       $OS_NAME"
else
    log_message "OS:       $(uname -s)"
fi
log_message "Kernel:   $(uname -r)"
log_message "Uptime:   $(uptime -p | sed 's/up //')"
log_message ""

# 2. Ресурсы
log_message "=== Resources ==="
CPU_CORES=$(nproc)
LOAD_AVG=$(uptime | awk -F'load average:' '{print $2}' | sed 's/^ //')
log_message "CPU:      $CPU_CORES cores, load average: $LOAD_AVG"

# Получение данных RAM в удобном формате
if command -v free >/dev/null 2>&1; then
    RAM_INFO=$(free -h | awk '/^Mem:/ {print $3 " / " $2 " (" int($3/$2*100) "%)"}')
    log_message "RAM:      $RAM_INFO"
else
    log_message "RAM:      free command not available"
fi

# Получение данных корневого диска
DISK_INFO=$(df -h / | awk 'NR==2 {print $3 " / " $2 " (" $5 ")"}')
log_message "Disk /:   $DISK_INFO"
log_message ""

# 3. Docker контейнеры
log_message "=== Docker ==="
if command -v docker >/dev/null 2>&1; then
    # Проверяем, запущен ли демона Docker, чтобы скрипт не упал при ошибке подключения
    if docker ps >/dev/null 2>&1; then
        DOCKER_CONTAINERS=$(docker ps --format "table {{.ID}}\t{{.Image}}\t{{.Status}}")
        log_message "$DOCKER_CONTAINERS"
    else
        log_message "Docker daemon is not running."
    fi
else
    log_message "Docker is not installed."
fi
log_message ""

# 4. Проверка здоровья сервисов
EXIT_CODE=0

if [ $# -gt 0 ]; then
    log_message "=== Service Health Checks ==="
    
    # Проверка обязательной зависимости для сетевых запросов
    if ! command -v curl >/dev/null 2>&1; then
        log_message "[ERROR] curl is required for health checks but not installed."
        exit 1
    fi

    TOTAL_SERVICES=$#
    HEALTHY_SERVICES=0

    for url in "$@"; do
        # Выполняем запрос через curl, замеряя время ответа и HTTP-код
        # --max-time 5 предотвращает зависание скрипта
        RESPONSE=$(curl -s -o /dev/null -w "%{http_code},%{time_total}" --max-time 5 "$url" || echo "0,0")
        HTTP_CODE=$(echo "$RESPONSE" | cut -d',' -f1)
        # Переводим время в миллисекунды для соответствия примеру вывода
        TIME_TOTAL=$(echo "$RESPONSE" | cut -d',' -f2)
        TIME_MS=$(awk -v t="$TIME_TOTAL" 'BEGIN {print int(t*1000)}')

        if [ "$HTTP_CODE" -eq 200 ]; then
            log_message "[OK]   $url ($HTTP_CODE, ${TIME_MS}ms)"
            HEALTHY_SERVICES=$((HEALTHY_SERVICES + 1))
        elif [ "$HTTP_CODE" -eq 0 ]; then
            log_message "[FAIL] $url (connection refused / timeout)"
            EXIT_CODE=1
        else
            log_message "[FAIL] $url ($HTTP_CODE, ${TIME_MS}ms)"
            EXIT_CODE=1
        fi
    done

    log_message ""
    log_message "Result: $HEALTHY_SERVICES/$TOTAL_SERVICES services healthy"
fi

exit "$EXIT_CODE"
