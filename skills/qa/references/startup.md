# Application Startup

How to discover, start, and verify any application. This reference is
discovery-based — probe the project to find out what it needs, then
act on what you find. Do not assume any specific stack.

## Workflow

```
1. Discover    Probe project files to detect stack, commands, ports, deps
2. Install     Install dependencies based on what was detected
3. Infra       Start infrastructure (docker, databases, caches)
4. Migrate     Run database migrations if detected
5. Start       Launch the application, track PIDs
6. Verify      Poll until the app responds (readiness check)
```

Note: cleanup is handled by SKILL.md Phase 7 after all testing completes.
Startup only starts — it never stops.

## Phase 1: Discover

The goal is to answer five questions:
1. **What runtime/framework?** (Node, Python, Go, Rust, Ruby, Java, etc.)
2. **How to start it?** (which command)
3. **What port?** (where does it listen)
4. **What dependencies?** (docker, database, cache, etc.)
5. **What testing tools are available?** (agent-browser, curl, etc.)

### Probe project files

Check these files in order. Stop as soon as you have clear answers.

```bash
# 1. Project docs (highest signal — human-written instructions)
cat CLAUDE.md 2>/dev/null | head -50
cat AGENTS.md 2>/dev/null | head -50
cat README.md 2>/dev/null | grep -A 20 -iE 'getting started|quick start|development|setup|run'

# 2. Makefile (common in mature projects)
cat Makefile 2>/dev/null | grep -E '^[a-zA-Z_-]+:' | head -20
# Look for: dev, start, serve, run, up, setup, install, migrate

# 3. Package manager files (detect runtime)
ls package.json Cargo.toml go.mod pyproject.toml setup.py Gemfile build.gradle pom.xml mix.exs 2>/dev/null

# 4. Docker
ls docker-compose.yml compose.yml Dockerfile 2>/dev/null
```

### Detect testing tools

```bash
# Check agent-browser
which agent-browser 2>/dev/null && echo "TOOL: agent-browser" || echo "TOOL: agent-browser NOT FOUND"

# Check curl (should always be available)
which curl 2>/dev/null && echo "TOOL: curl" || echo "TOOL: curl NOT FOUND"

# Check docker
which docker 2>/dev/null && echo "TOOL: docker" || echo "TOOL: docker NOT FOUND"
```

**If agent-browser is not found:** AskUserQuestion:

> Browser testing requires agent-browser CLI (https://github.com/vercel-labs/agent-browser).
> Without it, browser and Electron testing will be skipped — only API and CLI testing will run.
>
> A) Install agent-browser now (`npm install -g agent-browser`)
> B) Skip browser testing for this run

If A → run `npm install -g agent-browser`, verify with `which agent-browser`.
If install fails, continue without it.

If B → skip `references/browser.md` and `references/electron.md`.
API and CLI testing still work with just curl.

### Detect runtime

```bash
# Node.js
if [ -f package.json ]; then
  echo "RUNTIME: node"
  # Package manager
  [ -f pnpm-lock.yaml ] && echo "PKG: pnpm"
  [ -f yarn.lock ] && echo "PKG: yarn"
  [ -f bun.lockb ] && echo "PKG: bun"
  [ -f package-lock.json ] && echo "PKG: npm"
  # Framework
  grep -q '"next"' package.json && echo "FRAMEWORK: next"
  grep -q '"nuxt"' package.json && echo "FRAMEWORK: nuxt"
  grep -q '"vite"' package.json && echo "FRAMEWORK: vite"
  grep -q '"remix"' package.json && echo "FRAMEWORK: remix"
  grep -q '"astro"' package.json && echo "FRAMEWORK: astro"
  grep -q '"express"' package.json && echo "FRAMEWORK: express"
  grep -q '"fastify"' package.json && echo "FRAMEWORK: fastify"
  grep -q '"hono"' package.json && echo "FRAMEWORK: hono"
  grep -q '"electron"' package.json && echo "FRAMEWORK: electron"
fi

# Python
if [ -f pyproject.toml ] || [ -f setup.py ] || [ -f requirements.txt ]; then
  echo "RUNTIME: python"
  [ -f pyproject.toml ] && grep -q 'django' pyproject.toml && echo "FRAMEWORK: django"
  [ -f pyproject.toml ] && grep -q 'fastapi' pyproject.toml && echo "FRAMEWORK: fastapi"
  [ -f pyproject.toml ] && grep -q 'flask' pyproject.toml && echo "FRAMEWORK: flask"
  [ -f poetry.lock ] && echo "PKG: poetry"
  [ -f uv.lock ] && echo "PKG: uv"
  [ -f Pipfile.lock ] && echo "PKG: pipenv"
fi

# Go
if [ -f go.mod ]; then
  echo "RUNTIME: go"
  grep -q 'gin-gonic' go.mod && echo "FRAMEWORK: gin"
  grep -q 'gofiber' go.mod && echo "FRAMEWORK: fiber"
  grep -q 'echo' go.mod && echo "FRAMEWORK: echo"
fi

# Rust
if [ -f Cargo.toml ]; then
  echo "RUNTIME: rust"
  grep -q 'actix' Cargo.toml && echo "FRAMEWORK: actix"
  grep -q 'axum' Cargo.toml && echo "FRAMEWORK: axum"
  grep -q 'rocket' Cargo.toml && echo "FRAMEWORK: rocket"
  grep -q 'tauri' Cargo.toml && echo "FRAMEWORK: tauri"
fi

# Ruby
if [ -f Gemfile ]; then
  echo "RUNTIME: ruby"
  grep -q 'rails' Gemfile && echo "FRAMEWORK: rails"
  grep -q 'sinatra' Gemfile && echo "FRAMEWORK: sinatra"
fi

# Java / Kotlin
if [ -f build.gradle ] || [ -f build.gradle.kts ] || [ -f pom.xml ]; then
  echo "RUNTIME: java"
  grep -q 'spring' build.gradle 2>/dev/null && echo "FRAMEWORK: spring"
  grep -q 'spring' pom.xml 2>/dev/null && echo "FRAMEWORK: spring"
fi

# Elixir
if [ -f mix.exs ]; then
  echo "RUNTIME: elixir"
  grep -q 'phoenix' mix.exs && echo "FRAMEWORK: phoenix"
fi
```

### Detect start command

```bash
# From package.json scripts
if [ -f package.json ]; then
  node -e "
    const pkg = require('./package.json');
    const s = pkg.scripts || {};
    const order = ['dev', 'start:dev', 'start', 'serve', 'develop'];
    for (const key of order) {
      if (s[key]) { console.log('CMD: ' + key + ' → ' + s[key]); break; }
    }
  " 2>/dev/null
fi

# From Makefile
if [ -f Makefile ]; then
  grep -E '^(dev|start|serve|run|up)\s*:' Makefile | head -3
fi

# From Procfile (Heroku-style)
if [ -f Procfile ]; then
  cat Procfile | head -5
fi
```

### Detect port

```bash
# From .env / .env.example / .env.local
grep -hiE 'PORT=' .env .env.example .env.local .env.development 2>/dev/null | head -3

# From package.json scripts (look for --port or -p flags)
grep -oE '(--port|-p)\s*[0-9]+' package.json 2>/dev/null

# From docker-compose
grep -E 'ports:' -A 2 docker-compose.yml compose.yml 2>/dev/null

# Common defaults by framework
# Next.js: 3000, Vite: 5173, Django: 8000, Rails: 3000
# FastAPI: 8000, Go: 8080, Spring: 8080, Phoenix: 4000
```

### Detect infrastructure dependencies

```bash
# Docker compose services
if [ -f docker-compose.yml ] || [ -f compose.yml ]; then
  COMPOSE_FILE=$([ -f compose.yml ] && echo "compose.yml" || echo "docker-compose.yml")
  docker compose -f "$COMPOSE_FILE" config --services 2>/dev/null
fi

# Database from dependencies
grep -liE 'postgres|mysql|sqlite|mongo|redis|prisma|typeorm|sequelize|drizzle|sqlalchemy|diesel|activerecord' \
  package.json pyproject.toml Gemfile go.mod Cargo.toml 2>/dev/null

# Database from env
grep -hiE 'DATABASE_URL|DB_HOST|REDIS_URL|MONGO_URI' .env .env.example 2>/dev/null
```

### Output discovery results

After probing, print a summary:

```
[QA] Discovery:
  Runtime: <node|python|go|rust|ruby|java|elixir>
  Framework: <next|django|fastapi|express|...>
  Package manager: <npm|pnpm|yarn|bun|poetry|uv|cargo|...>
  Start command: <the command>
  Port: <number>
  Infrastructure: <postgres, redis, ...>
  Docker: <yes|no>
```

If any critical piece is unclear (especially start command or port),
use AskUserQuestion before proceeding.

## Phase 2: Install Dependencies

Based on detected runtime and package manager:

```bash
# Node.js
[ -f pnpm-lock.yaml ] && pnpm install
[ -f yarn.lock ] && yarn install
[ -f bun.lockb ] && bun install
[ -f package-lock.json ] && npm install
# Fallback if no lockfile
[ -f package.json ] && [ ! -d node_modules ] && npm install

# Python
[ -f poetry.lock ] && poetry install
[ -f uv.lock ] && uv sync
[ -f Pipfile.lock ] && pipenv install
[ -f requirements.txt ] && pip install -r requirements.txt

# Go
[ -f go.mod ] && go mod download

# Rust
[ -f Cargo.toml ] && cargo build

# Ruby
[ -f Gemfile ] && bundle install

# Java (Gradle)
[ -f build.gradle ] && ./gradlew build -x test

# Java (Maven)
[ -f pom.xml ] && mvn install -DskipTests

# Elixir
[ -f mix.exs ] && mix deps.get
```

## Phase 3: Start Infrastructure

Only if docker compose detected:

```bash
COMPOSE_FILE=$([ -f compose.yml ] && echo "compose.yml" || echo "docker-compose.yml")

# Validate
docker compose -f "$COMPOSE_FILE" config --quiet 2>&1

# Build if needed
docker compose -f "$COMPOSE_FILE" build 2>&1

# Start
docker compose -f "$COMPOSE_FILE" up -d 2>&1

# Wait for healthy (120s timeout)
for i in $(seq 1 40); do
  UNHEALTHY=$(docker compose -f "$COMPOSE_FILE" ps --format json 2>/dev/null \
    | grep -v '"healthy"' | grep -c '"running"' || echo "0")
  [ "$UNHEALTHY" -eq 0 ] && echo "INFRA: all healthy" && break
  sleep 3
done

# Fallback: TCP check on common ports
for PORT in 5432 3306 6379 27017; do
  (echo > /dev/tcp/localhost/$PORT) 2>/dev/null && echo "PORT $PORT: open"
done
```

If no docker compose but database URL is in .env, assume external
database and skip this phase.

## Phase 4: Run Migrations

Detect and run migration commands:

```bash
# Prisma (Node.js)
[ -f prisma/schema.prisma ] && npx prisma migrate deploy 2>&1
[ -f prisma/schema.prisma ] && npx prisma generate 2>&1

# Drizzle (Node.js)
[ -f drizzle.config.ts ] && npx drizzle-kit push 2>&1

# TypeORM (Node.js)
grep -q 'typeorm' package.json 2>/dev/null && npx typeorm migration:run 2>&1

# Django (Python)
[ -f manage.py ] && python manage.py migrate 2>&1

# SQLAlchemy / Alembic (Python)
[ -d alembic ] && alembic upgrade head 2>&1

# Rails (Ruby)
[ -f bin/rails ] && bin/rails db:migrate 2>&1

# Go (goose, migrate, atlas)
which goose >/dev/null 2>&1 && goose up 2>&1
which migrate >/dev/null 2>&1 && migrate up 2>&1

# Elixir / Phoenix
[ -f mix.exs ] && mix ecto.migrate 2>&1

# From Makefile (common pattern)
grep -qE '^(migrate|db-setup|db-migrate)\s*:' Makefile 2>/dev/null && make migrate 2>&1
```

If no migration tool detected, skip this phase.

### Seed data (if needed)

```bash
# Prisma
[ -f prisma/seed.ts ] && npx prisma db seed 2>&1

# Django
[ -f manage.py ] && python manage.py loaddata fixtures/*.json 2>&1

# Rails
[ -f db/seeds.rb ] && bin/rails db:seed 2>&1

# From Makefile
grep -qE '^(seed|db-seed)\s*:' Makefile 2>/dev/null && make seed 2>&1
```

## Phase 5: Start Application

All logs and PID tracking go to the QA evidence directory.

```bash
QA_DIR=".ship/tasks/<task_id>/qa"

# Check port is free
PORT=<detected_port>
lsof -i :$PORT -t 2>/dev/null && echo "WARNING: port $PORT already in use" || echo "PORT $PORT: free"

# Start in background, track PID in the same call
nohup <start_command> > "$QA_DIR/app.log" 2>&1 &
PID=$!
echo $PID >> "$QA_DIR/pids.txt"
echo "Started app PID=$PID"
```

### Common start commands by framework

```bash
# Next.js
nohup npx next dev > "$QA_DIR/app.log" 2>&1 &

# Vite (React, Vue, Svelte)
nohup npx vite dev > "$QA_DIR/app.log" 2>&1 &

# Express / Fastify / Hono
nohup node server.js > "$QA_DIR/app.log" 2>&1 &
nohup npm run dev > "$QA_DIR/app.log" 2>&1 &

# Django
nohup python manage.py runserver 0.0.0.0:8000 > "$QA_DIR/app.log" 2>&1 &

# FastAPI
nohup uvicorn main:app --host 0.0.0.0 --port 8000 > "$QA_DIR/app.log" 2>&1 &

# Flask
nohup flask run --host 0.0.0.0 > "$QA_DIR/app.log" 2>&1 &

# Go
nohup go run ./cmd/server > "$QA_DIR/app.log" 2>&1 &
nohup go run . > "$QA_DIR/app.log" 2>&1 &

# Rust
nohup cargo run > "$QA_DIR/app.log" 2>&1 &

# Rails
nohup bin/rails server > "$QA_DIR/app.log" 2>&1 &

# Phoenix
nohup mix phx.server > "$QA_DIR/app.log" 2>&1 &

# Spring Boot
nohup ./gradlew bootRun > "$QA_DIR/app.log" 2>&1 &
nohup mvn spring-boot:run > "$QA_DIR/app.log" 2>&1 &
```

Always prefer the start command found in discovery (Makefile, package.json scripts,
CLAUDE.md) over these defaults. These are fallbacks.

### Monorepo: multiple services

Some projects have multiple services (frontend + backend, or microservices).
Start each one separately with its own PID and log file:

```bash
# Example: frontend + backend
nohup npm run dev --prefix packages/frontend > "$QA_DIR/frontend.log" 2>&1 &
echo $! >> "$QA_DIR/pids.txt"

nohup npm run dev --prefix packages/backend > "$QA_DIR/backend.log" 2>&1 &
echo $! >> "$QA_DIR/pids.txt"
```

## Phase 6: Verify Readiness

Poll until the app responds. 90 second timeout.

```bash
PORT=<detected_port>

# Try common health endpoints
for i in $(seq 1 30); do
  for ENDPOINT in "/" "/health" "/healthz" "/api/health" "/api"; do
    STATUS=$(curl -sf -o /dev/null -w '%{http_code}' "http://localhost:$PORT$ENDPOINT" 2>/dev/null)
    if [ "$STATUS" -ge 200 ] && [ "$STATUS" -lt 500 ]; then
      echo "READY: http://localhost:$PORT$ENDPOINT returned $STATUS"
      break 2
    fi
  done
  sleep 3
done

# If still not ready, check the log for errors
if [ $i -eq 30 ]; then
  echo "TIMEOUT: app did not become ready in 90 seconds"
  echo "Last 20 lines of log:"
  tail -20 "$QA_DIR/app.log"
fi
```

### Verify PID is still alive

```bash
PID=$(tail -1 "$QA_DIR/pids.txt")
kill -0 $PID 2>/dev/null && echo "PID $PID: running" || echo "PID $PID: DEAD — check app.log"
```

### Output

```
[QA] Services:
  app:3000 — healthy
  docker:postgres:5432 — healthy
  docker:redis:6379 — healthy
```

If the app fails to start:
```
[QA] app:3000 — FAILED
[QA] Last 20 lines of server log:
<tail -20 app.log>
```

SKIP criteria that depend on the failed service. Do not SKIP the entire
run unless ALL criteria depend on it.

## Cleanup

**Cleanup is NOT part of startup.** Startup only starts services.
Cleanup is handled by SKILL.md Phase 7, which runs after ALL testing
is complete. Do not kill processes or stop docker here — the tests
need the services running.

## Troubleshooting

### Port already in use

```bash
# Find what's using the port
lsof -i :<port> -t 2>/dev/null
# Kill it if it's a leftover from a previous QA run
lsof -i :<port> -t 2>/dev/null | xargs kill -9 2>/dev/null
```

### Dependencies won't install

```bash
# Node: clear cache and retry
rm -rf node_modules && <pkg_manager> install

# Python: check venv
python -m venv .venv && source .venv/bin/activate && pip install -r requirements.txt
```

### Docker won't start

```bash
# Check docker daemon
docker info 2>&1 | head -5 || echo "Docker not running"

# Check compose file is valid
docker compose config --quiet 2>&1

# Nuclear reset (ask user first)
docker compose down -v --remove-orphans 2>&1
```

### App starts but immediately crashes

```bash
# Check the log
tail -50 "$QA_DIR/app.log"

# Common causes:
# - Missing .env file (copy from .env.example)
# - Database not ready yet (migration didn't run or docker still starting)
# - Port conflict
# - Missing build step (Next.js needs `next build` for production mode)
```

### App starts but returns 500 on every request

```bash
# Check if it's a build issue
# Some frameworks need a build step before serving
npm run build 2>&1  # Next.js, Vite in production
python manage.py collectstatic 2>&1  # Django

# Check if it's a database issue
# App started before migrations ran or database is empty
```

### Migrations fail

```bash
# Check database is reachable
(echo > /dev/tcp/localhost/5432) 2>/dev/null && echo "DB reachable" || echo "DB unreachable"

# Check DATABASE_URL is set
grep DATABASE_URL .env 2>/dev/null || echo "No DATABASE_URL in .env"

# Copy .env.example if .env is missing
[ ! -f .env ] && [ -f .env.example ] && cp .env.example .env && echo "Copied .env.example to .env"
```
