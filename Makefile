NAME = inception
COMPOSE = docker compose -f srcs/docker-compose.yml

DATA_DIR = /home/ntahadou/data
MYSQL_DATA = $(DATA_DIR)/mariadb
WORDPRESS_DATA = $(DATA_DIR)/wordpress

all: setup up

setup:
	mkdir -p $(MYSQL_DATA)
	mkdir -p $(WORDPRESS_DATA)

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
	rm -rf $(MYSQL_DATA)
	rm -rf $(WORDPRESS_DATA)

re:
	$(MAKE) fclean
	$(MAKE) build
	$(MAKE) up

.PHONY: all setup build up down stop start restart logs ps clean fclean re