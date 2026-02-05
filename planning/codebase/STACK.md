# Technology Stack

**Analysis Date:** 2024-01-30

## Languages

**Primary:**
- JavaScript ES6+ - Runtime language for wrapper application
- Node.js 22+ - Runtime environment (required)

**Secondary:**
- Shell script - Docker build processes
- Python 3 - System dependencies (Debian packages)

## Runtime

**Environment:**
- Node.js 22+ (production)
- Node.js 22-bookworm (Docker base)

**Package Manager:**
- pnpm - Production dependencies (PNPM_LOCK present)
- npm - Development scripts (legacy compatibility)
- Bun - Build tool for Openclaw (in Docker build)

**Build/Dev:**
- Docker - Multi-stage container build
- corepack - Package manager launcher
- Shell scripting - Build automation

## Frameworks

**Core:**
- Express 5.1.0 - Web server and proxy wrapper
- Openclaw - AI coding assistant platform (built from source)

**Testing:**
- Custom smoke test - Integration testing
- Node.js syntax check - Basic validation

**Build/Dev:**
- Multi-stage Docker build - Production container
- Homebrew - Linux package manager (Docker runtime)

## Key Dependencies

**Critical:**
- express 5.1.0 - Web server, HTTP routing, middleware
- http-proxy 1.18.1 - Reverse proxy for gateway communication
- tar 7.5.4 - Backup/export functionality

**Infrastructure:**
- Node.js built-in modules:
  - node:child_process - Spawn Openclaw gateway
  - node:crypto - Token generation and security
  - node:fs - File system operations
  - node:path - Path manipulation
  - node:os - Operating system utilities

## Configuration

**Environment:**
- PORT (default: 8080) - HTTP server port
- SETUP_PASSWORD - Required setup wizard protection
- OPENCLAW_STATE_DIR (default: /data/.openclaw) - Configuration storage
- OPENCLAW_WORKSPACE_DIR (default: /data/workspace) - Workspace storage
- OPENCLAW_GATEWAY_TOKEN - Gateway authentication token
- INTERNAL_GATEWAY_PORT (default: 18789) - Internal gateway port
- OPENCLAW_ENTRY (default: /openclaw/dist/entry.js) - Openclaw entry point
- OPENCLAW_GIT_REF (default: main) - Git reference for Openclaw build

**Build:**
- pnpm-lock.yaml - Dependency lockfile
- .env.example - Environment variable template
- Dockerfile - Multi-stage build configuration

## Platform Requirements

**Development:**
- Node.js 22+
- pnpm
- Docker (for smoke tests)

**Production:**
- Railway platform (target deployment)
- Node.js 22+ runtime
- Docker container support
- Volume mount at /data
- Public networking enabled

---

*Stack analysis: 2024-01-30*
```