# Codebase Concerns

**Analysis Date:** 2026-01-30

## Tech Debt

**Single Large Server File:**
- Issue: `src/server.js` is 935 lines, mixing proxy logic, auth management, onboarding, and HTTP routing
- Files: `src/server.js`
- Impact: Hard to navigate, risky changes, poor testability
- Fix approach: Split into modules - auth, proxy, gateway, routes, utils

**Hardcoded Channel Configurations:**
- Issue: Channel setup logic is hardcoded and brittle across Openclaw versions
- Files: `src/server.js:644-737`
- Impact: Breaks when `channels add --help` output changes
- Fix approach: Parse CLI help output dynamically or maintain version-specific mappings

**Token Sync Complexity:**
- Issue: Complex token resolution/sync logic with multiple failure points
- Files: `src/server.js:31-75, 147-189, 557-614`
- Impact: Multiple sync verification steps increase failure surface
- Fix approach: Simplify to single sync function with atomic config update

## Known Bugs

**Gateway Token Mismatch:**
- Symptoms: "token_missing" or "token_mismatch" errors in browser
- Files: `src/server.js:540-555`
- Trigger: Openclaw `onboard` command ignoring `--gateway-token` flag
- Workaround: Force sync after onboarding

**WebSocket Auth Intermittent Failures:**
- Symptoms: Random auth failures on WebSocket connections
- Files: `src/server.js:874-881`
- Trigger: Direct header modification not working for WebSocket upgrades
- Workaround: Must use `proxyReqWs` event handler

**Missing Config Validation:**
- Symptoms: Invalid config can prevent gateway startup
- Files: `src/server.js:903-902`
- Trigger: No validation before proxying requests
- Workaround: None - must restart after config fix

## Security Considerations

**Basic Auth Only:**
- Risk: Simple base64 encoding, no rate limiting
- Files: `src/server.js:261-285`
- Current mitigation: Basic auth with password env var
- Recommendations: Consider adding rate limiting and HTTPS enforcement

**Token Exposure in Logs:**
- Risk: Full tokens logged to stdout in debug mode
- Files: `src/server.js:40, 41, 53, 54`
- Current mitigation: DEBUG mode only
- Recommendations: Never log full tokens, always redact

**No Input Sanitization:**
- Risk: User input passed directly to shell commands
- Files: `src/server.js:486-508`
- Current mitigation: Trusting Openclaw CLI sanitization
- Recommendations: Add input validation for all API endpoints

## Performance Bottlenecks

**Synchronous File Operations:**
- Problem: Multiple sync file reads/writes during startup
- Files: `src/server.js:147-189`
- Cause: Blocking config verification
- Improvement path: Use async/await for all file operations

**Gateway Polling Timeout:**
- Problem: 20-second timeout for gateway readiness
- Files: `src/server.js:116-138`
- Cause: Hardcoded timeout with exponential backoff
- Improvement path: Configurable timeout with adaptive polling

**Heavy Proxy Logging:**
- Problem: All proxy errors logged unconditionally
- Files: `src/server.js:869-871`
- Cause: No log level control
- Improvement path: Add configurable logging levels

## Fragile Areas

**Openclaw Version Dependencies:**
- Files: `src/server.js:310-427`
- Why fragile: Auth provider mappings hardcoded and may not match CLI
- Safe modification: Parse CLI help output dynamically
- Test coverage: Only basic version check in smoke test

**Channel Detection Logic:**
- Files: `src/server.js:642-643, 678`
- Why fragile: `channels add --help` output varies between builds
- Safe modification: Always check for channel presence before trying to configure
- Test coverage: Debug endpoint shows detected channels

**Environment Variable Parsing:**
- Files: `src/server.js:12-21`
- Why fragile: Multiple fallbacks with potential undefined behavior
- Safe modification: Add explicit validation for required env vars
- Test coverage: No unit tests for env var resolution

## Scaling Limits

**Single Gateway Instance:**
- Current capacity: Single gateway process
- Limit: No horizontal scaling
- Scaling path: Add gateway load balancing with sticky sessions

**File-Based State:**
- Current capacity: Limited by filesystem
- Limit: No distributed deployment support
- Scaling path: Add Redis/state service for multi-instance deployments

## Dependencies at Risk

**Openclaw Git Dependency:**
- Risk: Custom fork/branch may diverge or disappear
- Impact: Build fails if ref doesn't exist
- Migration plan: Pin to stable releases or maintain fork

**pnpm Dependency:**
- Risk: pnpm version may cause build failures
- Impact: Docker build fails if pnpm not available
- Migration plan: Add explicit pnpm version pinning

## Missing Critical Features

**No Health Monitoring:**
- Problem: Only basic /setup/healthz endpoint
- Blocks: Proactive gateway health detection
- Recommendation: Add comprehensive health checks with metrics

**No Configuration Validation:**
- Problem: Invalid configs cause silent failures
- Blocks: Prevent deployment of broken configurations
- Recommendation: Add schema validation for all config updates

## Test Coverage Gaps

**No Unit Tests:**
- What's not tested: Individual functions, error handling, edge cases
- Files: `src/server.js` (no test coverage)
- Risk: Silent failures, regressions
- Priority: High

**No Integration Tests:**
- What's not tested: Proxy behavior, auth flow, channel setup
- Files: All endpoints lack integration tests
- Risk: HTTP/WebSocket proxy failures
- Priority: Medium

**No End-to-End Tests:**
- What's not tested: Complete onboarding flow
- Files: Setup wizard, proxy routing
- Risk: UI/UX breakages
- Priority: Medium

---

*Concerns audit: 2026-01-30*