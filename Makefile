COMPOSE  = docker compose -f srcs/docker-compose.yml
DATA_DIR = /home/abnemili/data

all: up

up:
	@mkdir -p $(DATA_DIR)/wordpress $(DATA_DIR)/mariadb
	@$(COMPOSE) up -d --build

down:
	@$(COMPOSE) down

logs:
	@$(COMPOSE) logs -f

ps:
	@$(COMPOSE) ps

clean:
	@$(COMPOSE) down --rmi local --volumes --remove-orphans

fclean: clean
	@sudo rm -rf $(DATA_DIR)/wordpress $(DATA_DIR)/mariadb

re: fclean all

.PHONY: all up down logs ps clean fclean re
