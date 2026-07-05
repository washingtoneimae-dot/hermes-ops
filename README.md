# Hermes Ops

> **AI operations agent for Docker — like Gordon with actual agency.**

Hermes Ops is a Docker-native AI agent that lives inside your container ecosystem and manages everything via natural language. Debug crashing containers, optimize Dockerfiles, deploy stacks, and monitor health — all by describing what you want.

**Status:** Planning phase. Not yet built.

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

## Quick Start (when built)

```bash
git clone https://github.com/washingtoneimae-dot/hermes-ops.git
cd hermes-ops
cp .env.example .env
nano .env
docker compose up -d
hermes-ops "why is my postgres container restarting?"
```

---

## Roadmap

| Phase | What | Status |
|-------|------|--------|
| 1 | Core container with Docker socket access | Planned |
| 2 | hermes-ops skill (Docker knowledge base) | Planned |
| 3 | Safety guardrails (dry-run, confirmation) | Planned |
| 4 | CLI + optional web dashboard | Planned |
| 5 | Openfield integration (first real-world test) | Planned |

Full plan: [`.hermes/plans/2026-07-06_hermes-ops-agent.md`](.hermes/plans/2026-07-06_hermes-ops-agent.md)

---

## License

MIT — open source.
