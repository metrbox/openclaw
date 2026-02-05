# Architecture

**Analysis Date:** 2026-01-30

## Pattern Overview

**Overall:** Wrapper Proxy Pattern

**Key Characteristics:**
- Express-based wrapper server with HTTP/WebSocket reverse proxy
- Gateway lifecycle management with health checks
- Two-layer authentication scheme (setup wizard + gateway)
- State persistence via external volume
- Configuration-driven runtime behavior

## Layers

**Wrapper Layer:**
- Purpose: HTTP server, authentication, proxy configuration, setup wizard UI
- Location: `C:\Users\derek\moltbot-railway-template-easy-config\src\server.js`
- Contains: Express app, proxy setup, authentication handlers, setup API endpoints
- Depends on: Node.js built-ins, Express, http-proxy, tar
- Used by: External HTTP clients (browsers, APIs)

**Gateway Layer:**
- Purpose: Openclaw core functionality (AI models, chat, tools)
- Location: `/openclaw/dist/entry.js` (external binary)
- Contains: Openclaw CLI implementation
- Depends on: Node.js, Openclaw package
- Used by: Wrapper proxy

**Configuration Layer:**
- Purpose: State persistence and configuration management
- Location: `${STATE_DIR}/openclaw.json`, `${STATE_DIR}/gateway.token`
- Contains: User preferences, channel configs, auth tokens
- Depends on: Filesystem access
- Used by: Wrapper and gateway processes

## Data Flow

**Setup Flow:**
1. User accesses `/setup` → Basic auth validation → HTML/JS/CSS served
2. User submits form → `/setup/api/run` → validates config → runs `openclaw onboard`
3. Onboard completes → wrapper syncs token to config → starts gateway
4. Gateway becomes ready → proxy activated → user can access Openclaw UI

**Runtime Flow:**
1. External request → wrapper checks if configured
2. If not configured → redirect to `/setup`
3. If configured → ensure gateway running → proxy with injected auth token
4. WebSocket upgrades handled via proxy event handlers

**State Management:**
- Configuration: JSON file at `STATE_DIR/openclaw.json`
- Gateway token: Environment-persistent file at `STATE_DIR/gateway.token`
- Workspace: Directory at `WORKSPACE_DIR` for agent data

## Key Abstractions

**Token Management:**
- Purpose: Stable authentication token across restarts
- Examples: `C:\Users\derek\moltbot-railway-template-easy-config\src\server.js:31-75`
- Pattern: Multi-source resolution (env → persisted file → generated)

**Proxy Configuration:**
- Purpose: Transparent gateway access with auth injection
- Examples: `C:\Users\derek\moltbot-railway-template-easy-config\src\server.js:863-925`
- Pattern: http-proxy event handlers for HTTP/WebSocket auth injection

**Gateway Lifecycle:**
- Purpose: Start/stop/restart Openclaw gateway process
- Examples: `C:\Users\derek\moltbot-railway-template-easy-config\src\server.js:140-259`
- Pattern: Child process management with health checks

## Entry Points

**Wrapper Server:**
- Location: `C:\Users\derek\moltbot-railway-template-easy-config\src\server.js`
- Triggers: Railway deployment, local `npm run dev/start`
- Responsibilities: HTTP routing, authentication, proxy setup, gateway management

**Setup Wizard UI:**
- Location: `C:\Users\derek\moltbot-railway-template-easy-config\src\public\setup.html`
- Triggers: Browser access to `/setup` (with auth)
- Responsibilities: User onboarding flow, channel configuration

**Openclaw Gateway:**
- Location: `/openclaw/dist/entry.js`
- Triggers: Wrapper spawns via child process
- Responsibilities: AI model interaction, chat processing, tool execution

## Error Handling

**Strategy:** Graceful degradation with detailed logging

**Patterns:**
- Gateway startup failures → retry with timeout, detailed error messages
- Config file issues → validation with specific error context
- Proxy failures → pass-through errors with stack traces
- Token sync failures → verification and explicit error messages

## Cross-Cutting Concerns

**Logging:** Structured logging with prefixes (`[token]`, `[gateway]`, `[proxy]`)
**Validation:** Configuration validation before gateway startup
**Authentication:** Two-layer auth (Basic auth for setup, Bearer token for gateway)
**Persistence:** Volume-based state persistence across redeploys

---

*Architecture analysis: 2026-01-30*