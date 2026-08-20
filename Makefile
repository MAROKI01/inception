NAME = inception
COMPOSE = docker compose -f srcs/docker-compose.yml

DATA_DIR = /home/ntahadou/data
MYSQL_DATA = $(DATA_DIR)/mariadb
WORDPRESS_DATA = $(DATA_DIR)/wordpress
DOMAIN_NAME := $(shell grep '^DOMAIN_NAME=' srcs/.env | cut -d '=' -f2)


all: setup up

setup:
	sudo mkdir -p $(MYSQL_DATA)
	sudo mkdir -p $(WORDPRESS_DATA)
	@if ! grep -qE "^[[:space:]]*127\.0\.0\.1[[:space:]].*\b$(DOMAIN_NAME)\b" /etc/hosts; then \
		echo "Adding $(DOMAIN_NAME) to /etc/hosts..."; \
		echo "127.0.0.1 $(DOMAIN_NAME)" | sudo tee -a /etc/hosts > /dev/null; \
	else \
		echo "$(DOMAIN_NAME) already exists in /etc/hosts."; \
	fi

build:
	$(COMPOSE) build

up:
	$(COMPOSE) up -d

down:
	$(COMPOSE) down

stop:
	$(COMPOSE) stop

start:
	$(COMPOSE) start

restart:
	$(COMPOSE) restart

logs:
	$(COMPOSE) logs

ps:
	$(COMPOSE) ps

clean:
	$(COMPOSE) down -v

fclean:
	$(COMPOSE) down -v
	docker system prune -af
	sudo rm -rf $(MYSQL_DATA)
	sudo rm -rf $(WORDPRESS_DATA)

re:
	$(MAKE) fclean
	$(MAKE) setup
	$(MAKE) build
	$(MAKE) up

.PHONY: all setup build up down stop start restart logs ps clean fclean re