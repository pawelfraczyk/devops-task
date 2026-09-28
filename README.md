# DevOps task

Small pnpm monorepo for a junior DevOps exercise. The application is already written. Container images, Compose, and GitHub Actions are intentionally missing. The assignment is [TASKS.md](./TASKS.md).

## What it does

`apps/web` is a static page with one button. The page asks the web server for `POST /api/clicks`, and that server proxies the call to `apps/api`.

The API does three things, in order:

1. Increments a row in Postgres (`counters.id = 'clicks'`).
2. Writes that count into Valkey with a TTL.
3. Reads the count back from Valkey and returns it.

```json
{ "count": 1, "source": "valkey", "persisted": true }
```

`GET /health` checks Postgres and Valkey. It does not increment the counter. Use it as a readiness probe. A probe against `POST /api/clicks` would count as a real click.

The schema lives in `apps/api/sql/001_counters.sql`. The API applies it on startup.

## Layout

```text
apps/api     Node.js HTTP API
apps/web     static files plus a small server that proxies /api/clicks
TASKS.md     the work to do
```

## Prerequisites

- Node.js 24.21.0 (see `.nvmrc`). The app is written for the Node 24 LTS line.
- pnpm 11.20.0. From the repo root, `corepack enable` then `corepack install` will use the version in `packageManager`.
- PostgreSQL 18 and Valkey 9, only if you want to press the button before the stack is containerized.

## Run it locally

Create an empty database named `devops_task` and a Valkey instance on port 6379. Then, in one shell:

```bash
pnpm install
export DATABASE_URL=postgres://postgres:postgres@127.0.0.1:5432/devops_task
export VALKEY_URL=redis://127.0.0.1:6379
pnpm dev:api
```

In a second shell:

```bash
export PORT=3000
export API_UPSTREAM=http://127.0.0.1:3001
pnpm dev:web
```

Open http://127.0.0.1:3000 and press **Record click**.

Do not source `.env.example` into both shells. Both processes read `PORT`, and they need different values. `.env.example` is documentation. Nothing in this repo loads dotenv.

The local passwords above are for a laptop only. [TASKS.md](./TASKS.md) does not allow those values in Compose.

## Run the stack

Docker Compose wires the API, web app, Postgres, and Valkey together. Export two passwords in the shell (do not commit real values):

```bash
export POSTGRES_PASSWORD='choose-a-strong-postgres-password'
export VALKEY_PASSWORD='choose-a-strong-valkey-password'
docker compose up --build
```

Open http://127.0.0.1:3000 and press **Record click**. The counter should increase on each click.

Stop the stack:

```bash
docker compose down
```

Postgres data is kept in a named volume, so `docker compose down` followed by `docker compose up -d` preserves the counter. Only the web port is published on the loopback interface.

## Checks

```bash
pnpm check
pnpm test
```

The tests do not need Postgres or Valkey.

## Environment

| Variable | Process | Purpose |
| --- | --- | --- |
| `PORT` | both | API defaults to 3001, web defaults to 3000 |
| `HOST` | both | Bind address, default `0.0.0.0` |
| `DATABASE_URL` | API | Postgres connection string |
| `VALKEY_URL` | API | Valkey connection string. `redis://` URLs are correct. A password looks like `redis://:<password>@host:6379` |
| `CACHE_TTL_SECONDS` | API | Cache TTL, default 30, max 86400 |
| `CORS_ORIGIN` | API | Allowed browser origin for direct API calls. Default `http://127.0.0.1:3000` |
| `API_UPSTREAM` | web | API origin, with no path, query, or credentials. Default `http://127.0.0.1:3001` |

Inside Compose, the web service should keep proxying, and the API port should not be published on the host. The button calls the same origin.
