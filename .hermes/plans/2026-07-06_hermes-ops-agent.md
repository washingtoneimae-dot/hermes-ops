# Hermes Ops — AI Operations Agent for Docker

> **For Hermes:** Execute directly or via subagent-driven-development.

**Goal:** Build an AI agent that lives inside a Docker container, has full control over the Docker host, and can manage containers, debug failures, optimize configs, and respond to natural language commands — essentially Gordon with actual agency.

**Architecture:** A Hermes Agent running in a privileged Docker container with the Docker socket mounted. It uses the Docker Python SDK to control the host. Users interact via CLI, API, or a lightweight web UI. A Hermes skill wraps all Docker knowledge.

**Tech Stack:** Docker, Docker SDK for Python (docker-py), Hermes Agent (headless), FastAPI (optional web UI), Python 3.14

---

## Difficulty Assessment

| Dimension | Score | Notes |
|-----------|-------|-------|
| Core plumbing (Docker socket + SDK) | 3/10 | Trivial. Mount socket, install docker-py, done. |
| Hermes in a container | 4/10 | Already documented. Slight config work. |
| Docker knowledge base (the skill) | 6/10 | Need to curate good prompts. Docker docs are good. |
| Natural language → Docker actions | 5/10 | Hermes already reasons. Just needs the skill context. |
| Safety / guardrails | 7/10 | The hard part. Don't want "delete all containers" to actually work. |
| Web UI (optional) | 4/10 | Simple FastAPI + htmx or Streamlit. |
| Multi-container orchestration | 6/10 | docker-py can do it. Logic is the hard part. |
| **Overall** | **5/10** | Medium. The core is easy. Safety and polish are the work. |

---

## Architecture

```
User (CLI / API / Web UI)
        │
        ▼
┌──────────────────────────────────┐
│  Master Container (Hermes Ops)   │
│                                  │
│  /var/run/docker.sock mounted    │
│  docker-py SDK installed         │
│  Hermes Agent running headless   │
│  hermes-ops skill loaded         │
│                                  │
│  Capabilities:                   │
│  • list/inspect/start/stop       │
│  • read logs, diagnose errors    │
│  • docker compose up/down        │
│  • optimize Dockerfiles          │
│  • monitor health                │
│  • suggest fixes                 │
└──────────────┬───────────────────┘
               │ docker.sock
               ▼
┌──────────────────────────────────┐
│         Docker Host              │
│                                  │
│  ┌────────┐ ┌────────┐ ┌──────┐ │
│  │ postgres│ │ redis  │ │ nginx│ │
│  └────────┘ └────────┘ └──────┘ │
│  ┌────────┐ ┌────────┐          │
│  │  api   │ │frontend│  ...     │
│  └────────┘ └────────┘          │
└──────────────────────────────────┘
```

---

## Phase 1: Core Container (Risk Spike — verify docker.sock access works)

### Task 1: Create the Hermes Ops Dockerfile

**Objective:** Build a container with Hermes + Docker SDK that can control the host.

**File:** `hermes-ops/Dockerfile`

```dockerfile
FROM python:3.14-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl git docker.io && \
    rm -rf /var/lib/apt/lists/*

RUN pip install docker hermes-agent

WORKDIR /workspace

COPY docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

ENTRYPOINT ["docker-entrypoint.sh"]
```

**Verification:** `docker build -t hermes-ops .` succeeds.

---

### Task 2: Create docker-compose.yml for Hermes Ops

**Objective:** Define the master container with Docker socket access.

**File:** `hermes-ops/docker-compose.yml`

```yaml
services:
  master:
    build: .
    container_name: hermes-ops
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - ./workspace:/workspace
      - ./skills:/root/.hermes/skills
    environment:
      - HERMES_PROVIDER=${HERMES_PROVIDER:-deepseek}
      - HERMES_MODEL=${HERMES_MODEL:-deepseek-v4-flash}
      - DEEPSEEK_API_KEY=${DEEPSEEK_API_KEY}
    stdin_open: true
    tty: true
    restart: unless-stopped
```

**Verification:** `docker compose up -d` starts the container.

---

### Task 3: Verify docker.sock access

**Objective:** Prove the container can control the host Docker daemon.

**Command:**
```bash
docker compose exec master python3 -c "
import docker
client = docker.from_env()
containers = client.containers.list()
for c in containers:
    print(f'{c.name}: {c.status}')
"
```

**Expected output:** List of running containers on the host. Confirms docker.sock works.

---

## Phase 2: The Hermes Ops Skill

### Task 4: Create the hermes-ops skill

**Objective:** Give Hermes deep Docker knowledge — commands, debugging patterns, best practices, safety rules.

**File:** `skills/hermes-ops/SKILL.md`

The skill should contain:
- Docker command reference (run, build, compose, logs, inspect, exec, prune)
- Debugging patterns (container crash → check logs, check exit code, check healthcheck, check resource limits)
- Dockerfile best practices (multi-stage builds, layer caching, non-root user, .dockerignore)
- docker-compose patterns (service dependencies, healthchecks, volumes, networks, env files)
- Safety rules (never force-remove running production containers without confirmation, never delete volumes without backup warning, always show what WILL happen before doing it)
- Common errors and fixes (port already allocated, OOM killed, permission denied, disk full)

---

### Task 5: Install the skill and test basic commands

**Objective:** Verify Hermes can answer Docker questions using the skill.

**Command:**
```bash
docker compose exec master hermes ask "list all running containers"
```

**Expected output:** Hermes runs `docker ps` and returns the list.

---

### Task 6: Test a debugging scenario

**Objective:** Verify Hermes can diagnose a real problem.

**Test:** Start a container with a deliberate error (wrong port, missing env var), then ask Hermes to debug it.

**Command:**
```bash
docker compose exec master hermes ask "my-api container keeps restarting, figure out why and fix it"
```

**Expected:** Hermes reads logs, identifies the error, suggests a fix, applies it (or asks for confirmation first for destructive changes).

---

## Phase 3: Safety & Guardrails

### Task 7: Implement safety confirmation for destructive actions

**Objective:** Never let Hermes delete, force-remove, or prune without explicit confirmation.

**File:** `skills/hermes-ops/references/safety-rules.md`

Safety rules:
- `docker rm -f` — ALWAYS confirm first
- `docker compose down -v` — ALWAYS confirm first (destroys volumes)
- `docker system prune -a` — ALWAYS confirm first (destroys unused images)
- `docker stop` on production containers — warn, suggest graceful alternatives
- Read-only actions (ps, logs, inspect, images ls) — always allowed without confirmation

Implement as a Python wrapper around docker-py that checks the safety rules before executing.

---

### Task 8: Add a "dry run" mode

**Objective:** `hermes ops --dry-run "restart the api container"` shows what WOULD happen without doing it.

**Implementation:** Add a `DRY_RUN=true` env var that makes all docker-py calls log the action instead of executing it.

---

## Phase 4: CLI & UX

### Task 9: Create the `hermes-ops` CLI wrapper

**Objective:** A simple CLI that feels like Gordon but has real agency.

**File:** `hermes-ops/cli.py`

```python
#!/usr/bin/env python3
"""Hermes Ops CLI — AI operations agent for Docker."""
import sys
import subprocess

def main():
    if len(sys.argv) < 2:
        print("Usage: hermes-ops <natural language command>")
        print("Example: hermes-ops 'why is my API container crashing?'")
        sys.exit(1)
    
    prompt = " ".join(sys.argv[1:])
    cmd = ["hermes", "ask", prompt]
    subprocess.run(cmd)

if __name__ == "__main__":
    main()
```

**Verification:** `hermes-ops "list all containers"` returns results.

---

### Task 10: Create a lightweight web dashboard (optional but high-impact)

**Objective:** A Streamlit or FastAPI+htmx dashboard showing container status with a chat interface.

**File:** `hermes-ops/dashboard.py`

Simple Streamlit app showing:
- Container list (name, status, ports, uptime)
- Chat input at the bottom
- Response area with actions taken
- One-click actions: restart, logs, inspect

**Verification:** `streamlit run dashboard.py` shows the UI at localhost:8501.

---

## Phase 5: Openfield Integration (the side quest pays off)

### Task 11: Deploy Openfield using Hermes Ops

**Objective:** The first real-world test — can Hermes Ops deploy and manage the Openfield stack?

**Command:**
```bash
hermes-ops "clone https://github.com/washingtoneimae-dot/agent.git, set up .env, and docker compose up -d"
```

**Expected:** Hermes clones the repo, copies .env.example to .env, prompts for required values (or uses defaults), runs `docker compose up -d`, verifies health.

---

### Task 12: Monitor Openfield health

**Objective:** Set up a cron job inside the master container that checks Openfield health every 5 minutes and alerts if anything is down.

**Cron in the master container:**
```bash
*/5 * * * * hermes ops "check that all openfield containers are healthy, restart any that aren't, and log what you did"
```

---

## Risks & Open Questions

| Risk | Mitigation |
|------|------------|
| Docker socket access = root on host | Run container as non-root user with docker group. Add guardrails. |
| Hermes could be prompted to do dangerous things | Safety confirmation layer. Dry-run mode. Audit log. |
| Gordon adds agency before we ship | Docker said "future features will allow the agent to do the work for you." We have a time window. |
| Too many tools, overlapping with existing Docker tooling | Focus on the AI reasoning layer. docker-py does the mechanical work, Hermes does the thinking. |
| Kubernetes vs Docker Swarm vs standalone | Start with standalone Docker. Add K8s support via kubectl in v2. |

---

## What Success Looks Like

1. User types natural language → Docker actions happen
2. Hermes Ops can debug a crashing container without human intervention
3. Openfield deploys and runs via a single Hermes Ops command
4. The safety layer prevents accidents even when the prompt is ambiguous
5. Someone who's never used Docker can deploy a stack by describing what they want

---

## Data Sources

| Data | Source | Status |
|------|--------|--------|
| Docker SDK docs | docker-py.readthedocs.io | Real, public |
| Docker best practices | docs.docker.com | Real, public |
| Gordon capabilities | docker.com/blog | Real, public — baseline comparison |
| Hermes in Docker | hermes-agent.nousresearch.com/docs | Real, public |
| Openfield stack | github.com/washingtoneimae-dot/agent | Real, private |
