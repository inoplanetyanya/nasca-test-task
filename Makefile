# Запрещаем Git Bash на Windows искажать пути в Docker-командах
export MSYS_NO_PATHCONV=1

# Автоматически загружаем переменные из .env файла, если он существует
ifneq (,$(wildcard ./.env))
    include .env
    export
endif

# Кроссплатформенное определение путей к виртуальному окружению (Windows vs Linux)
ifeq ($(OS),Windows_NT)
    VENV_BIN = .venv/Scripts
    SYS_PYTHON = python
    PYTHON = $(VENV_BIN)/python.exe
    PIP = $(VENV_BIN)/pip.exe
    UVICORN = $(VENV_BIN)/uvicorn.exe
else
    VENV_BIN = .venv/bin
    SYS_PYTHON = python3
    PYTHON = $(VENV_BIN)/python
    PIP = $(VENV_BIN)/pip
    UVICORN = $(VENV_BIN)/uvicorn
endif

.PHONY: help install lint test run server-info docker-build docker-run docker-stop compose-up compose-down compose-logs ansible-check ansible-dry ansible-run

help: ## Показать все команды
	@echo "Доступные команды:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'

install: ## Установить зависимости Python
	$(SYS_PYTHON) -m venv .venv
	$(PYTHON) -m pip install --upgrade pip
	$(PIP) install -r app/requirements.txt
	@echo "Окружение создано успешно."

lint: ## Проверить качество кода (ruff для Python, shellcheck для Bash)
	@echo "=== Линтинг Python (ruff) ==="
	$(PYTHON) -m ruff check app/ $(ARGS)
	@echo "=== Линтинг Bash (shellcheck) ==="
	docker run --rm -v "$(CURDIR)":/apps -w /apps koalaman/shellcheck scripts/server-info.sh

test: ## Запустить автоматические тесты
	PYTHONPATH=. $(PYTHON) -m pytest

run: ## Запустить приложение локально на хосте (разработка)
	$(UVICORN) app.main:app --reload --host 0.0.0.0 --port $(CONTAINER_PORT)

server-info: ## Запустить Bash-скрипт диагностики сервера
	chmod +x scripts/server-info.sh
	./scripts/server-info.sh http://localhost:$(HOST_PORT)/health

docker-build: ## Собрать Docker образ
	docker build --build-arg APP_PORT=$(CONTAINER_PORT) -t $(IMAGE_NAME):$(IMAGE_TAG) .

docker-run: docker-stop ## Запустить Docker контейнер вручную
	docker run -d -p $(HOST_PORT):$(CONTAINER_PORT) --name $(CONTAINER_NAME) $(IMAGE_NAME):$(IMAGE_TAG)

docker-stop: ## Остановить и удалить созданный вручную Docker контейнер
	docker stop $(CONTAINER_NAME) 2>/dev/null || true
	docker rm $(CONTAINER_NAME) 2>/dev/null || true

compose-up: ## Запустить Docker Compose в фоне
	docker compose up -d

compose-down: ## Остановить и удалить Docker Compose контейнеры
	docker compose down

compose-logs: ## Просмотреть логи Docker Compose
	docker compose logs -f app

ansible-check: ## Проверить синтаксис Ansible playbook
	docker run --rm -v "$(CURDIR)":/ansible -w /ansible alpine/ansible ansible-playbook -i $(INVENTORY) $(PLAYBOOK) --syntax-check --extra-vars "DEPLOY_DIR=$(DEPLOY_DIR) APP_PORT=$(CONTAINER_PORT)"

ansible-dry: ## Начать dry-run Ansible (имитация деплоя)
	docker run --rm -v "$(CURDIR)":/ansible -w /ansible alpine/ansible ansible-playbook -i $(INVENTORY) $(PLAYBOOK) --check --extra-vars "DEPLOY_DIR=$(DEPLOY_DIR) APP_PORT=$(CONTAINER_PORT)"

ansible-run: ## Запустить реальный Ansible playbook
	docker run --rm -v "$(CURDIR)":/ansible -w /ansible alpine/ansible ansible-playbook -i $(INVENTORY) $(PLAYBOOK) --extra-vars "DEPLOY_DIR=$(DEPLOY_DIR) APP_PORT=$(CONTAINER_PORT)"
