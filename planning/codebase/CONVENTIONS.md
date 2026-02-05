# Coding Conventions

**Analysis Date:** 2024-01-30

## Naming Patterns

**Files:**
- kebab-case for server files: `src/server.js`
- kebab-case for HTML assets: `src/public/setup.html`
- kebab-case for CSS assets: `src/public/styles.css`
- kebab-case for JavaScript assets: `src/public/setup-app.js`
- kebab-case for scripts: `scripts/smoke.js`

**Functions:**
- camelCase for JavaScript functions: `resolveGatewayToken()`, `waitForGatewayReady()`, `buildOnboardArgs()`
- camelCase for variable names: `gatewayProc`, `gatewayStarting`, `SETUP_PASSWORD`
- PascalCase for constants in all caps: `PORT`, `STATE_DIR`, `INTERNAL_GATEWAY_PORT`
- snake_case for CLI flags and environment variables: `OPENCLAW_STATE_DIR`, `SETUP_PASSWORD`

**Variables:**
- const/let based on mutability preference: `const PORT = Number.parseInt(...)`
- destructuring preferred where appropriate: `const { channel, code } = req.body || {}`

**Types:**
- No TypeScript detected - codebase uses pure JavaScript with JSDoc comments in development

## Code Style

**Formatting:**
- No code formatter configured
- Manual formatting follows consistent indentation (2 spaces)
- Curly braces on new lines for control structures
- Semicolons consistently used throughout

**Linting:**
- Basic syntax check available: `npm run lint` (uses `node -c src/server.js`)
- No ESLint or other advanced linting setup
- Error handling consistent throughout with try/catch blocks

## Import Organization

**Order:**
1. Node.js built-ins: `import childProcess from "node:child_process"`
2. Third-party packages: `import express from "express"`
3. Relative imports: Not used (single file application)

**Path Aliases:**
- No path aliases configured
- Absolute paths used consistently: `path.join(process.cwd(), "src", "public", "setup-app.js")`

## Error Handling

**Patterns:**
```javascript
try {
    const config = JSON.parse(fs.readFileSync(configPath(), "utf8"));
    const configToken = config?.gateway?.auth?.token;
    // Process config
} catch (err) {
    console.error(`[gateway] ERROR: Token verification failed: ${err}`);
    throw err; // Don't start gateway with mismatched token
}
```

- Consistent use of try/catch for file operations and JSON parsing
- Error messages include context: `[gateway]`, `[onboard]`, `[proxy]` prefixes
- Errors are logged with `console.error` for visibility
- Critical errors throw to halt execution, warnings use `console.warn`

## Logging

**Framework:** Native `console.log` and `console.error`

**Patterns:**
```javascript
const DEBUG = process.env.OPENCLAW_TEMPLATE_DEBUG?.toLowerCase() === "true";
function debug(...args) {
  if (DEBUG) console.log(...args);
}

// Usage:
console.log(`[token] ========== SERVER STARTUP TOKEN RESOLUTION ==========`);
console.log(`[gateway] ready at ${endpoint}`);
console.error(`[gateway] ERROR: Token verification failed: ${err}`);
```

- Bracketed prefixes for context: `[token]`, `[gateway]`, `[onboard]`, `[proxy]`
- Debug logging conditional on environment variable
- Errors go to `console.error`, regular messages to `console.log`
- Consistent timestamp format not used - relies on Node.js built-in

## Comments

**When to Comment:**
- Complex logic sections (token resolution, token sync)
- Diagnostic logging blocks
- Important configuration decisions (loopback binding, auth mode)
- Workaround explanations (bypassing `channels add`)

**JSDoc/TSDoc:**
- No JSDoc comments detected in codebase
- Comments are inline prose explaining why, not what

## Function Design

**Size:**
- Functions range from small helpers (`sleep()`, `isConfigured()`) to large complex handlers (`/setup/api/run`)
- Average function length: 15-25 lines
- Functions with clear single responsibility preferred where possible

**Parameters:**
- Optional parameters with defaults: `opts = {}`
- Object destructuring for complex parameters: `const { channel, code } = req.body || {}`

**Return Values:**
- Consistent return objects: `{ ok: boolean, reason?: string }`
- Promises for async operations
- Explicit error throwing for unrecoverable conditions

## Module Design

**Exports:**
- No explicit exports - all code in single file
- Functions defined at module level with `const` for top-level scope

**Barrel Files:**
- Not applicable - single file application structure