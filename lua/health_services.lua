-- ============================================================================
-- Health Check Services Configuration
-- ============================================================================
-- Purpose: Define services to be checked by /health/services endpoint
-- Usage: This file can be modified to add/remove services without changing
--        the main health check logic
-- ============================================================================

local _M = {}

-- Service list for health checks
-- Format: { name = "service-name", app_id = "dapr-app-id" }
_M.services = {
    { name = "bible-api", app_id = "bible-api" },
    { name = "search-api", app_id = "search-api" },
}

-- Dapr sidecar base URL (can be overridden via environment variable)
_M.dapr_base = os.getenv("DAPR_SIDECAR_URL") or "http://127.0.0.1:3500"

return _M

