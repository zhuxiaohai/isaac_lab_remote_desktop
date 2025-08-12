
dev_build:
	docker compose build

dev_up: dev_build
	docker compose up -d

dev_down:
	docker compose down

dev_purge:
	docker compose down --volumes --remove-orphans

dev_build_5.0:
	docker compose -f docker-compose-5.0.yml build

dev_up_5.0: dev_build_5.0
	docker compose -f docker-compose-5.0.yml up -d

dev_down_5.0:
	docker compose -f docker-compose-5.0.yml down

dev_purge_5.0:
	docker compose -f docker-compose-5.0.yml down --volumes --remove-orphans