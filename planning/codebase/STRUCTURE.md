# Codebase Structure

**Analysis Date:** 2026-01-30

## Directory Layout

```
C:\Users\derek\moltbot-railway-template-easy-config\
├── .planning\codebase\          # Analysis documents (generated)
├── src\                         # Source code
│   ├── public\                  # Static assets for setup wizard
│   │   ├── setup.html          # Setup wizard HTML structure
│   │   ├── setup-app.js        # Client-side JS for setup wizard
│   │   └── styles.css          # Setup wizard styling
│   └── server.js               # Main Express wrapper application
├── scripts\                     # Utility scripts
│   └── smoke.js                # Local smoke test script
├── package.json                 # Project dependencies and scripts
├── Dockerfile                  # Container build definition
├── railway.toml               # Railway configuration
└── README.md                   # User documentation
```

## Directory Purposes

**src/**:
- Purpose: Application source code
- Contains: Main server, setup wizard assets
- Key files: `server.js` (main entry), `public/` (setup wizard)

**src/public/**:
- Purpose: Static assets for the setup wizard
- Contains: HTML, CSS, and JavaScript for `/setup` UI
- Key files: `setup.html`, `setup-app.js`, `styles.css`

**scripts/**:
- Purpose: Development and testing utilities
- Contains: Helper scripts for local development
- Key files: `smoke.js` (local testing)

## Key File Locations

**Entry Points:**
- `C:\Users\derek\moltbot-railway-template-easy-config\src\server.js`: Main Express wrapper
- `C:\Users\derek\moltbot-railway-template-easy-config\src\public\setup.html`: Setup wizard UI

**Configuration:**
- `C:\Users\derek\moltbot-railway-template-easy-config\package.json`: Project config and dependencies
- `C:\Users\derek\moltbot-railway-template-easy-config\Dockerfile`: Container build definition
- `C:\Users\derek\moltbot-railway-template-easy-config\railway.toml`: Railway platform config

## Naming Conventions

**Files:**
- lowercase with hyphens: `server.js`, `setup.html`, `smoke.js`
- Extensions: `.js` for JavaScript, `.html` for HTML, `.css` for CSS, `.json` for config

**Directories:**
- lowercase with hyphens: `src`, `public`, `scripts`
- No camelCase or underscores

**Functions (in server.js):**
- camelCase: `buildOnboardArgs()`, `requireSetupAuth()`, `waitForGatewayReady()`
- Descriptive names that reflect purpose

**Constants (in server.js):**
- UPPER_SNAKE_CASE: `PORT`, `STATE_DIR`, `WORKSPACE_DIR`, `INTERNAL_GATEWAY_PORT`
- Configuration constants grouped at top

## Where to Add New Code

**New Channel Support:**
- Setup form: `C:\Users\derek\moltbot-railway-template-easy-config\src\public\setup.html`
- Client JS: `C:\Users\derek\moltbot-railway-template-easy-config\src\public\setup-app.js`
- Server logic: `C:\Users\derek\moltbot-railway-template-easy-config\src\server.js` (in `/setup/api/run` handler)

**New Authentication Provider:**
- Config mapping: `C:\Users\derek\moltbot-railway-template-easy-config\src\server.js:458-476`
- Auth group config: `C:\Users\derek\moltbot-railway-template-easy-config\src\server.js:318-419`
- Client form: `C:\Users\derek\moltbot-railway-template-easy-config\src\public\setup.html`

**New Proxy Configuration:**
- Proxy setup: `C:\Users\derek\moltbot-railway-template-easy-config\src\server.js:863-925`
- Health checks: `C:\Users\derek\moltbot-railway-template-easy-config\src\server.js:116-138`

**Utility Functions:**
- Add to `C:\Users\derek\moltbot-railway-template-easy-config\src\server.js` or create new module in `src/utils/`

## Special Directories

**.planning/codebase/**:
- Purpose: Generated architecture and planning documents
- Generated: Yes (by GSD tools)
- Committed: Yes (for team reference)

**src/public/**:
- Purpose: Client-side assets for setup wizard
- Generated: No (hand-written vanilla JS/CSS)
- Committed: Yes

---

*Structure analysis: 2026-01-30*