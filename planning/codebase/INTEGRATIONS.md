# External Integrations

**Analysis Date:** 2024-01-30

## APIs & External Services

**Messaging Platforms:**
- Telegram - Bot integration via Telegram Bot API
  - SDK: Native CLI (openclaw channels add telegram)
  - Auth: TELEGRAM_BOT_TOKEN env var
  - Config: Written via `openclaw config set channels.telegram`
- Discord - Bot integration via Discord API
  - SDK: Native CLI (openclaw channels add discord)
  - Auth: DISCORD_BOT_TOKEN env var
  - Config: Written via `openclaw config set channels.discord`
  - Note: Requires MESSAGE CONTENT INTENT
- Slack - Bot and app integration via Slack API
  - SDK: Native CLI (openclaw channels add slack)
  - Auth: SLACK_BOT_TOKEN or SLACK_APP_TOKEN env vars
  - Config: Written via `openclaw config set channels.slack`

**Development Platforms:**
- GitHub - Git repository hosting
  - Usage: Openclaw source code cloning
  - Ref: OPENCLAW_GIT_REF build argument
- GitHub Copilot - AI code completion
  - Integration: Device login flow
  - Auth: GitHub OAuth flow

**Infrastructure:**
- Railway - Platform as a Service
  - Usage: Deployment hosting
  - Features: Automatic reverse proxy, volume mounting
- Docker - Container platform
  - Usage: Multi-stage build, runtime isolation
  - Base: node:22-bookworm
- Homebrew - Package manager
  - Usage: Linux package installation in Docker
  - Purpose: Build dependencies

## Data Storage

**Databases:**
- File-based only - No external databases
  - State: `/data/.openclaw/openclaw.json`
  - Workspace: `/data/workspace/`
  - Storage: Local filesystem or Railway Volume

**File Storage:**
- Local filesystem (Railway Volume)
- Export functionality: `.tar.gz` backup creation

**Caching:**
- None detected - Session-based authentication only

## Authentication & Identity

**Auth Provider:**
- Custom Bearer Token - Gateway authentication
  - Implementation: Token injection via proxy headers
  - Token resolution order: ENV → file → generate
- Basic Auth - Setup wizard protection
  - Implementation: HTTP Basic authentication
  - Password: SETUP_PASSWORD environment variable
- GitHub OAuth - Copilot integration
  - Implementation: Device login flow

## Monitoring & Observability

**Error Tracking:**
- None detected - Console logging only

**Logs:**
- Console output - Node.js console logging
- Debug mode: OPENCLAW_TEMPLATE_DEBUG=true
- Gateway logs: Streamed from child process

## CI/CD & Deployment

**Hosting:**
- Railway - Primary deployment platform
  - Features: One-click deploy, automatic HTTPS, volume mounting

**CI Pipeline:**
- GitHub Actions - Docker build automation
  - File: `.github/workflows/docker-build.yml`
  - Purpose: Container build and deployment

## Environment Configuration

**Required env vars:**
- SETUP_PASSWORD - Protects setup wizard
- PORT - HTTP server port (default 8080)
- OPENCLAW_STATE_DIR - State directory
- OPENCLAW_WORKSPACE_DIR - Workspace directory

**Optional env vars:**
- OPENCLAW_GATEWAY_TOKEN - Gateway authentication
- INTERNAL_GATEWAY_PORT - Internal gateway port
- OPENCLAW_ENTRY - Openclaw entry point
- OPENCLAW_GIT_REF - Git reference for build
- OPENCLAW_TEMPLATE_DEBUG - Debug logging

**Secrets location:**
- Environment variables - Railway Variables
- Token persistence - `${STATE_DIR}/gateway.token`

## Webhooks & Callbacks

**Incoming:**
- Setup wizard - `/setup/*` endpoints (Basic auth protected)
- Gateway proxy - All other routes (token auth protected)

**Outgoing:**
- Openclaw gateway spawning - Local child process
- External API calls - Via spawned Openclaw processes
- Backup exports - Archive creation via tar

---

*Integration audit: 2024-01-30*
```