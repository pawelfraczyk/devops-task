# DevOps task

Small pnpm monorepo for a DevOps exercise. The application is already written. Tasks 1-5 containerize it and publish images. Tasks 6-10 run those images on Amazon EKS. The assignment is [TASKS.md](./TASKS.md).

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

## Images

On push to `main`, GitHub Actions publishes container images to GitHub Container Registry:

- `ghcr.io/<owner>/<repo>/api`
- `ghcr.io/<owner>/<repo>/web`

Replace `<owner>/<repo>` with this repository's GitHub path (for example `fpurichaya/devops-task`).

Tag scheme:

- `sha-<full git commit sha>` — immutable build identifier
- `main` — moving tag for the latest `main` build

No `latest` tag is published.

## Checks

```bash
pnpm check
pnpm test
```

The tests do not need Postgres or Valkey.

## Remote state

Task 6 adds a Terragrunt layout and one S3 bucket for OpenTofu state. This unit does not create a VPC or a cluster.

```text
infra/provider.hcl         AWS provider and version pins
infra/root.hcl             S3 backend for every later unit
infra/live/dev/env.hcl     region eu-central-1 and name prefix devops-task-dev
infra/live/dev/state/      the bucket, with a local backend
```

Pinned versions: OpenTofu 1.13.9, Terragrunt 1.1.6, and hashicorp/aws 6.72.0. OpenTofu 1.13.9 is the current 1.13 patch. Terragrunt 1.2.1 is a newer minor, so this repo stays on the 1.1 line.

The bucket name is `devops-task-dev-tfstate-<account id>`. Terragrunt reads the account id from the caller identity when it runs. The id is not stored in git.

`infra/live/dev/state` includes `provider.hcl` and uses a local backend. It does not include `root.hcl`, because that backend points at the bucket this unit creates. Later units include the root file like this:

```hcl
include "root" {
  path = find_in_parent_folders("root.hcl")
}
```

That generates an S3 backend. The state key is the unit path relative to `infra/root.hcl`. The backend encrypts state and locks with `use_lockfile = true`. It does not set `dynamodb_table`.

`root.hcl` only writes the backend configuration. It does not create the bucket. The state unit creates it with versioning, AES256 encryption, all four public access block settings, and a bucket policy that denies non-TLS access.

Install OpenTofu 1.13.9 and Terragrunt 1.1.6, and point the AWS CLI at the account you own. Then, from the repo root:

```bash
cd infra/live/dev/state
terragrunt init
terragrunt plan
terragrunt apply
```

`terragrunt init` writes `infra/live/dev/state/.terraform.lock.hcl`. Commit that lock file. Do not commit `.terraform/`, `.terragrunt-cache/`, `*.tfstate`, or `*.tfvars`.

Local state for this unit is `infra/live/dev/state/terraform.tfstate`. Keep that file on the machine that applies the unit. Deleting it leaves the bucket in the account with no state to destroy it.

After apply, read the bucket settings. Replace nothing in these commands; the account id comes from the caller identity:

```bash
ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
BUCKET="devops-task-dev-tfstate-${ACCOUNT_ID}"
REGION="eu-central-1"

aws s3api get-bucket-versioning --bucket "$BUCKET" --region "$REGION"
aws s3api get-bucket-encryption --bucket "$BUCKET" --region "$REGION"
aws s3api get-public-access-block --bucket "$BUCKET" --region "$REGION"
aws s3api get-bucket-policy --bucket "$BUCKET" --region "$REGION"
```

`force_destroy` is off. Destroy fails while objects or versions remain. `aws s3 rm --recursive` leaves noncurrent versions and delete markers, so remove every version and delete marker first:

```bash
ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
BUCKET="devops-task-dev-tfstate-${ACCOUNT_ID}"
REGION="eu-central-1"

python3 - "$BUCKET" "$REGION" <<'PY'
import json
import subprocess
import sys

bucket, region = sys.argv[1], sys.argv[2]
key_marker = None
version_marker = None

while True:
    command = [
        "aws", "s3api", "list-object-versions",
        "--bucket", bucket,
        "--region", region,
        "--max-keys", "1000",
        "--output", "json",
    ]
    if key_marker:
        command.extend([
            "--key-marker", key_marker,
            "--version-id-marker", version_marker,
        ])
    page = json.loads(subprocess.check_output(command))
    objects = []
    for field in ("Versions", "DeleteMarkers"):
        for item in page.get(field) or []:
            objects.append({"Key": item["Key"], "VersionId": item["VersionId"]})
    if objects:
        subprocess.check_call([
            "aws", "s3api", "delete-objects",
            "--bucket", bucket,
            "--region", region,
            "--delete", json.dumps({"Objects": objects, "Quiet": True}),
        ])
    if not page.get("IsTruncated"):
        break
    key_marker = page["NextKeyMarker"]
    version_marker = page["NextVersionIdMarker"]
PY

cd infra/live/dev/state
terragrunt destroy
```

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
