NAME     = inception
COMPOSE  = docker compose -f ./srcs/docker-compose.yml
DATA_DIR = /home/abnemili/data

all: build up

prepare:
	@mkdir -p $(DATA_DIR)/wordpress
	@mkdir -p $(DATA_DIR)/mariadb

build: prepare
	@$(COMPOSE) build

up: prepare
	@$(COMPOSE) up -d

down:
	@$(COMPOSE) down

logs:
	@$(COMPOSE) logs -f

ps:
	@$(COMPOSE) ps

# Scoped to this project only: removes its containers, its network, the volume
# definitions and the images it built. Other projects on the host are untouched.
clean:
	@$(COMPOSE) down --rmi local --volumes --remove-orphans

# Also drops the persisted website and database files.
fclean: clean
	@sudo rm -rf $(DATA_DIR)/wordpress
	@sudo rm -rf $(DATA_DIR)/mariadb

re: fclean all

.PHONY: all prepare build up down logs ps clean fclean re
