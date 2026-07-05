# Hermes Ops

> **AI operations agent for Docker — like Gordon with actual agency.**

Hermes Ops is a Docker-native AI agent that lives inside your container ecosystem and manages everything via natural language. Debug crashing containers, optimize Dockerfiles, deploy stacks, and monitor health — all by describing what you want.

**Status:** Alpha — core container builds and has Docker socket access. Hermes reasoning requires API key configuration.

---

## The Problem

Docker Desktop's Gordon AI is useful — but it can only *suggest* things. It can't actually do anything. It has no write access, no agency, and no ability to execute commands on your behalf.

Hermes Ops fixes that. It has:
- **Agency** — actually starts, stops, inspects, and manages containers
- **Reasoning** — diagnoses problems, not just suggests fixes
- **Memory** — remembers what it did and why
- **Safety** — confirms destructive actions, supports dry-run mode

---

## Architecture

```
You: "why is my API container crashing?"
        │
        ▼
┌──────────────────────────────┐
│     Hermes Ops Container     │
│                              │
│  Hermes Agent (headless)     │
│  + hermes-ops skill          │
│  + Docker SDK (docker-py)    │
│  + /var/run/docker.sock      │
└──────────┬───────────────────┘
           │ docker.sock
           ▼
┌──────────────────────────────┐
│        Docker Host           │
│  Your containers live here   │
└──────────────────────────────┘
```

---

## Quick Start

```bash
git clone https://github.com/washingtoneimae-dot/hermes-ops.git
cd hermes-ops
cp .env.example .env
```

Edit `.env` and set your AI provider API key and provider:

```env
HERMES_PROVIDER=deepseek          # or openrouter, openai, opencode-zen
HERMES_MODEL=deepseek-v4-flash    # or your preferred model
DEEPSEEK_API_KEY=sk-your-real-key # your actual API key
```

Then start:

```bash
docker compose up -d
```

Verify Docker socket access works:

```bash
docker exec hermes-ops python3 -c "
import docker
client = docker.from_env()
for c in client.containers.list():
    print(f'{c.name}: {c.status}')
"
```

Once your API key is configured, you can ask Hermes Ops anything:

```bash
docker exec hermes-ops hermes chat -q "why is my container crashing?" -s hermes-ops -Q --provider deepseek -m deepseek-v4-flash
```

---

## What's Verified

- ✅ Docker image builds from Dockerfile
- ✅ Container starts and stays alive
- ✅ Docker socket mounted and accessible — sees all host containers
- ✅ Docker Python SDK works from inside the container
- ✅ Hermes Agent CLI v0.15.2 installed and running
- ✅ 10KB hermes-ops skill loaded with Docker knowledge, safety rules, debugging patterns

---

## Skill Contents

The `skills/hermes-ops/SKILL.md` file contains:

- **Docker command reference** — ps, logs, inspect, compose, build, networks, volumes
- **Debugging patterns** — container restart loops, immediate exits, build failures, network issues
- **Dockerfile best practices** — layer optimization, multi-stage builds, security
- **docker-compose patterns** — healthchecks, dependencies, resource limits, secrets
- **Safety rules** — destructive actions always require confirmation, safe actions allowed
- **Common errors and fixes** — port conflicts, OOM kills, permission denied, disk full
- **Procedural workflows** — deploy new stack, diagnose slow service, update running stack

---

## How to Use

### One-shot queries (non-interactive)
```bash
docker exec hermes-ops hermes chat -q "your question" -s hermes-ops -Q --provider deepseek -m deepseek-v4-flash
```

### Interactive session
```bash
docker exec -it hermes-ops hermes chat -s hermes-ops --provider deepseek -m deepseek-v4-flash
```

### Cron-based health monitoring (future)
```
*/5 * * * * docker exec hermes-ops hermes chat -q "check that all containers are healthy" -s hermes-ops -Q
```

---

## Safety

The hermes-ops skill enforces strict safety rules:

| Action | Requires Confirmation? |
|--------|----------------------|
| docker ps, logs, inspect, stats | No — safe, read-only |
| docker start, restart (non-prod) | No — safe |
| docker stop (production) | Yes — warn first |
| docker rm -f | Yes — always confirm |
| docker compose down -v | Yes — destroys data |
| docker system prune | Yes — removes images |
| docker volume rm | Yes — permanent data loss |

---

## Roadmap

| Phase | What | Status |
|-------|------|--------|
| 1 | Core container + Docker socket + skill | ✅ Done |
| 2 | API key wiring + first real queries | 🔧 In progress |
| 3 | Safety wrapper (dry-run mode, confirmation layer) | Planned |
| 4 | CLI (`hermes-ops`) + optional web dashboard | Planned |
| 5 | Openfield integration (deploy + monitor) | Planned |

Full plan: [`.hermes/plans/2026-07-06_hermes-ops-agent.md`](.hermes/plans/2026-07-06_hermes-ops-agent.md)

---

## License

MIT — open source.
