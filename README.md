# statistics-for-strava — local Docker setup

> A zero-friction local setup kit for [Statistics for Strava](https://github.com/robiningelbrecht/statistics-for-strava) by [@robiningelbrecht](https://github.com/robiningelbrecht).
> This repo does not contain the application itself — it wraps it with a guided `make setup` so you can get from zero to running in a single command.

## Prerequisites

- [Docker](https://docs.docker.com/get-docker/) + Docker Compose
- A [Strava API app](https://www.strava.com/settings/api) (free, takes ~2 minutes to create)

## Quick start

```bash
git clone https://github.com/matthiasseghers/statistics-for-strava-quickstart.git statistics-for-strava
cd statistics-for-strava
make setup
```

`make setup` walks through everything interactively:

1. Prompts for your Strava Client ID and Client Secret
2. Prompts for your birthday and weight (needed for heart rate zones and w/kg)
3. Starts the Docker container and waits until it is healthy
4. Opens `http://localhost:8080` for the Strava OAuth flow
5. Prompts you to paste the refresh token the app provides
6. Restarts the container with the token and optionally runs the first import

## Available commands

```
make setup    Interactive first-time setup
make start    Start the container
make stop     Stop the container
make restart  Restart and pick up .env changes
make import   Import activities from Strava + rebuild dashboard
make build    Rebuild dashboard files only (no API calls)
make update   Pull the latest image and restart
make logs     Tail container logs
make shell    Open a shell inside the container
make clean    Remove imported data only (keeps .env and config)
make nuke     Full reset — removes everything including credentials and config
```

## Configuration

| File | Purpose |
|------|---------|
| `.env` | Strava credentials and timezone. Created by `make setup`. |
| `config/config.yaml` | App behaviour: locale, heart rate zones, gear, etc. Created by `make setup`. |

Both files are git-ignored. Their templates (`.env.example` and `config/config.yaml.example`) are committed and used as the base during setup.

For all available configuration options refer to the [official documentation](https://statistics-for-strava-docs.robiningelbrecht.be/#/configuration/main-configuration).

## Re-running setup

Each step is skipped if the target file already exists. To redo a specific step, delete the corresponding file first:

```bash
# Remove imported data only (keeps credentials and config)
make clean

# Redo credentials only
rm .env && make setup

# Redo personal config only
rm config/config.yaml && make setup

# Full reset — removes everything, start from scratch
make nuke && make setup
```

## Credits

All credit goes to [Robin Ingelbrecht](https://github.com/robiningelbrecht) for building [Statistics for Strava](https://github.com/robiningelbrecht/statistics-for-strava). This repo is just a convenience wrapper around his Docker image.
