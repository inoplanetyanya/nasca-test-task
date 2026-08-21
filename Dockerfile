# --- Этап 1: Сборка зависимостей ---
FROM python:3.12-slim AS builder

WORKDIR /build

# Установка системных зависимостей для сборки (если потребуются)
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Копируем и собираем зависимости в локальную директорию wheels
COPY app/requirements.txt .
RUN pip install --no-cache-dir --user -r requirements.txt


# --- Этап 2: Финальный легковесный образ ---
FROM python:3.12-slim AS runner

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Создаем системного пользователя без прав root для безопасности
RUN useradd -u 10001 -m appuser

# Копируем установленные библиотеки из этапа сборки
COPY --from=builder /root/.local /home/appuser/.local
COPY app/ /app/

# Настройка переменных окружения Python
ENV PATH=/home/appuser/.local/bin:$PATH
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

# Открываем порт 5000 в соответствии с ТЗ
EXPOSE 5000

# Добавляем HEALTHCHECK (интервал 30с, таймаут 5с, 3 попытки)
HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:5000/health || exit 1

# Переключаемся на безопасного пользователя
USER appuser

# Запуск через gunicorn с uvicorn-воркерами на порту 5000
CMD ["gunicorn", "main:app", "--workers", "4", "--worker-class", "uvicorn.workers.UvicornWorker", "--bind", "0.0.0.0:5000"]
