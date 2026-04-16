# ============================================================
#  statistics-for-strava — local Docker setup
#  https://github.com/robiningelbrecht/statistics-for-strava
#
#  Prerequisites: Docker + Docker Compose
#
#  Quick start:
#    make setup   → interactive setup: credentials, config, auth, import
#
#  Other commands:
#    make start   make stop    make restart
#    make import  make build   make update
#    make logs    make shell
#    make clean   make nuke
# ============================================================

.PHONY: help setup start stop restart import build update logs shell clean nuke auth

## ── Colours ──────────────────────────────────────────────────
GREEN  := \033[0;32m
YELLOW := \033[0;33m
CYAN   := \033[0;36m
RESET  := \033[0m

help: ## Show this help
	@echo ""
	@echo "  $(CYAN)statistics-for-strava$(RESET) — available commands"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
		| awk 'BEGIN {FS = ":.*?## "}; {printf "  $(GREEN)%-12s$(RESET) %s\n", $$1, $$2}'
	@echo ""

# ── Setup ────────────────────────────────────────────────────

setup: ## Interactive first-time setup: creates .env and config/config.yaml
	@echo ""
	@echo "$(CYAN)╔══════════════════════════════════════════╗$(RESET)"
	@echo "$(CYAN)║     statistics-for-strava  setup         ║$(RESET)"
	@echo "$(CYAN)╚══════════════════════════════════════════╝$(RESET)"
	@echo ""
	@# ── Step 1: Strava API credentials ──────────────────────
	@echo "$(CYAN)Step 1/3 — Strava API credentials$(RESET)"
	@echo "  Open $(CYAN)https://www.strava.com/settings/api$(RESET) and create (or find) your app."
	@echo ""
	@if [ -f .env ]; then \
		echo "  $(YELLOW).env already exists, skipping. Delete it to re-run setup.$(RESET)"; \
	else \
		cp .env.example .env; \
		printf "  Client ID:     "; read CLIENT_ID; \
		printf "  Client Secret: "; read -s CLIENT_SECRET; echo; \
		sed -i.bak "s/YOUR_CLIENT_ID/$$CLIENT_ID/" .env; \
		sed -i.bak "s/YOUR_CLIENT_SECRET/$$CLIENT_SECRET/" .env; \
		rm -f .env.bak; \
		echo "  $(GREEN)✓ .env written$(RESET)"; \
	fi
	@echo ""
	@# ── Step 2: Personal details ─────────────────────────────
	@echo "$(CYAN)Step 2/3 — Personal details (for heart rate zones and w/kg)$(RESET)"
	@mkdir -p config
	@if [ ! -f config/config.yaml.example ]; then \
		echo "  $(YELLOW)config/config.yaml.example missing — restoring from repo...$(RESET)"; \
		curl -fsSL "https://raw.githubusercontent.com/robiningelbrecht/statistics-for-strava/master/config/config.yaml" \
			-o config/config.yaml.example 2>/dev/null || \
		{ echo "  $(YELLOW)Download failed. Please re-clone the repo.$(RESET)"; exit 1; }; \
		echo "  $(GREEN)✓ config/config.yaml.example restored$(RESET)"; \
	fi
	@if [ -f config/config.yaml ]; then \
		echo "  $(YELLOW)config/config.yaml already exists, skipping. Delete it to re-run setup.$(RESET)"; \
	else \
		cp config/config.yaml.example config/config.yaml; \
		while true; do \
			printf "  Birthday       (YYYY-MM-DD): "; read BIRTHDAY; \
			if echo "$$BIRTHDAY" | grep -qE '^[0-9]{4}-(0[1-9]|1[0-2])-(0[1-9]|[12][0-9]|3[01])$$'; then \
				break; \
			fi; \
			echo "  $(YELLOW)Invalid date. Please use YYYY-MM-DD format (e.g. 1990-04-16).$(RESET)"; \
		done; \
		printf "  Weight in kg   (e.g. 75):    "; read WEIGHT; \
		TODAY=$$(date +%Y-%m-%d); \
		sed -i.bak "s/birthday: 'YYYY-MM-DD'/birthday: '$$BIRTHDAY'/" config/config.yaml; \
		sed -i.bak "s/\"YYYY-MM-DD\": 70/\"$$TODAY\": $$WEIGHT/" config/config.yaml; \
		rm -f config/config.yaml.bak; \
		echo "  $(GREEN)✓ config/config.yaml written$(RESET)"; \
	fi
	@echo ""
	@# ── Step 3: Start + auth + optional import ───────────────
	@echo "$(CYAN)Step 3/3 — Start the app$(RESET)"
	@echo "  Starting container..."
	@docker compose up -d --pull always
	@printf "  Waiting for app to be ready"
	@until docker inspect --format='{{.State.Health.Status}}' statistics-for-strava 2>/dev/null | grep -q "healthy"; do \
		printf "."; sleep 3; \
	done
	@echo " $(GREEN)✓$(RESET)"
	@echo "  $(GREEN)✓ Running at http://localhost:8080$(RESET)"
	@echo ""
	@echo "$(CYAN)Strava authorisation$(RESET)"
	@echo "  The app will guide you through authorising with Strava."
	@echo "  Opening $(CYAN)http://localhost:8080$(RESET) — follow the on-screen instructions."
	@open "http://localhost:8080" 2>/dev/null || true
	@echo ""
	@printf "  Press $(CYAN)Enter$(RESET) once you have authorised in the browser: "; read _WAIT
	@echo ""
	@while true; do \
		printf "  Paste the $(CYAN)Strava refresh token$(RESET) shown by the app: "; read -s REFRESH_TOKEN; echo; \
		if [ -n "$$REFRESH_TOKEN" ]; then \
			grep -v '^STRAVA_REFRESH_TOKEN=' .env > .env.tmp && \
			echo "STRAVA_REFRESH_TOKEN=$$REFRESH_TOKEN" >> .env.tmp && \
			mv .env.tmp .env && \
			echo "  $(GREEN)✓ Refresh token saved to .env$(RESET)"; \
			echo "  Restarting container to pick up new token..."; \
			docker compose down && docker compose up -d; \
			printf "  Waiting for app to be ready"; \
			until docker inspect --format='{{.State.Health.Status}}' statistics-for-strava 2>/dev/null | grep -q "healthy"; do \
				printf "."; sleep 3; \
			done; \
			echo " $(GREEN)✓$(RESET)"; \
			break; \
		fi; \
		echo "  $(YELLOW)Token cannot be empty. Please paste the token from the app.$(RESET)"; \
	done
	@echo ""
	@printf "  $(CYAN)Import your Strava activities now?$(RESET) [Y/n]: "; read DO_IMPORT; \
	case "$$DO_IMPORT" in \
		[nN]*) \
			echo "  Skipped. Run $(CYAN)make import$(RESET) whenever you're ready."; \
			;; \
		*) \
			echo "  $(CYAN)→ Importing activities (this may take a while)...$(RESET)"; \
			docker compose exec app bin/console app:strava:import-data; \
			echo "  $(CYAN)→ Building dashboard...$(RESET)"; \
			docker compose exec app bin/console app:strava:build-files; \
			echo "  $(GREEN)✓ Done — open http://localhost:8080$(RESET)"; \
			;; \
	esac
	@echo ""

# ── Container lifecycle ──────────────────────────────────────

start: ## Start the container
	@echo "$(CYAN)→ Starting statistics-for-strava...$(RESET)"
	@docker compose up -d --pull always
	@echo "$(GREEN)✓ Running at http://localhost:8080$(RESET)"

stop: ## Stop the container
	@echo "$(CYAN)→ Stopping...$(RESET)"
	@docker compose down

restart: ## Restart (picks up .env changes)
	@echo "$(CYAN)→ Restarting...$(RESET)"
	@docker compose down && docker compose up -d
	@echo "$(GREEN)✓ Restarted at http://localhost:8080$(RESET)"

# ── Auth ─────────────────────────────────────────────────────

auth: ## Print the OAuth URL — visit it to get your refresh token
	@echo ""
	@echo "  $(CYAN)Open this URL in your browser to authorise Strava:$(RESET)"
	@echo ""
	@CLIENT_ID=$$(grep '^STRAVA_CLIENT_ID=' .env | cut -d= -f2); \
	echo "  https://www.strava.com/oauth/authorize?client_id=$$CLIENT_ID&response_type=code&redirect_uri=http://localhost:8080/strava-callback&approval_prompt=auto&scope=read,activity:read_all"
	@echo ""
	@echo "  $(YELLOW)After authorising, the app will capture the token automatically."
	@echo "  Check your .env — STRAVA_REFRESH_TOKEN should be filled in."
	@echo "  Then run: $(CYAN)make import$(RESET)"
	@echo ""

# ── Data ─────────────────────────────────────────────────────

import: ## Import activities from Strava + rebuild the dashboard
	@echo "$(CYAN)→ Importing Strava activities...$(RESET)"
	@docker compose exec app bin/console app:strava:import-data
	@echo "$(CYAN)→ Building dashboard files...$(RESET)"
	@docker compose exec app bin/console app:strava:build-files
	@echo "$(GREEN)✓ Done — open http://localhost:8080$(RESET)"

build: ## Rebuild dashboard files only (no API calls)
	@echo "$(CYAN)→ Building dashboard files...$(RESET)"
	@docker compose exec app bin/console app:strava:build-files
	@echo "$(GREEN)✓ Done$(RESET)"

# ── Maintenance ──────────────────────────────────────────────

update: ## Pull the latest image and restart
	@echo "$(CYAN)→ Pulling latest image...$(RESET)"
	@docker compose pull
	@docker compose up -d
	@echo "$(GREEN)✓ Updated and restarted$(RESET)"

logs: ## Tail container logs
	@docker compose logs -f

shell: ## Open a shell inside the container
	@docker compose exec app sh

clean: ## Stop container and remove all imported data (keeps .env and config)
	@echo "$(YELLOW)⚠ This will delete all downloaded Strava data (build + storage).$(RESET)"
	@read -p "  Are you sure? [y/N] " confirm; \
	if [ "$$confirm" = "y" ] || [ "$$confirm" = "Y" ]; then \
		docker compose down -v; \
		rm -rf build storage; \
		echo "$(GREEN)✓ Cleaned up$(RESET)"; \
	else \
		echo "Aborted."; \
	fi

nuke: ## Full reset — removes everything including .env and config (run make setup after)
	@echo "$(YELLOW)⚠ This will delete ALL local data including credentials and config.$(RESET)"
	@read -p "  Are you sure? [y/N] " confirm; \
	if [ "$$confirm" = "y" ] || [ "$$confirm" = "Y" ]; then \
		docker compose down -v; \
		rm -rf build storage; \
		rm -f config/config.yaml .env; \
		echo "$(GREEN)✓ Nuked — run make setup to start fresh$(RESET)"; \
	else \
		echo "Aborted."; \
	fi
