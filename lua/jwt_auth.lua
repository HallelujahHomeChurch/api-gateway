-- ============================================================================
-- JWT Authentication Module
-- ============================================================================
-- Purpose: Verify JWT tokens and extract user information
-- Usage: Called from nginx location blocks with different auth modes
-- ============================================================================

local jwt = require "resty.jwt"
local json = require "cjson"

local _M = {}

-- JWT secret key (should be set via environment variable)
local JWT_SECRET = os.getenv("JWT_SECRET") or "your-secret-key-change-in-production"

-- Account API base URL for token validation (optional, for additional validation)
local ACCOUNT_API_BASE = os.getenv("ACCOUNT_API_BASE") or "http://account-api:8080"

-- Auth modes
_M.AUTH_MODE_NONE = "none"        -- No authentication required
_M.AUTH_MODE_OPTIONAL = "optional" -- Authenticate if token present, otherwise allow
_M.AUTH_MODE_REQUIRED = "required" -- Authentication required

-- ============================================================================
-- Clear user headers to prevent header injection
-- ============================================================================
function _M.clear_user_headers()
    ngx.req.set_header("X-User-ID", nil)
    ngx.req.set_header("X-Roles", nil)
    ngx.req.set_header("X-Permissions", nil)
end

-- ============================================================================
-- Extract JWT token from Authorization header
-- ============================================================================
function _M.extract_token()
    local auth_header = ngx.var.http_authorization
    if not auth_header then
        return nil, "Missing Authorization header"
    end

    -- Check for Bearer token format
    local token = string.match(auth_header, "Bearer%s+(.+)")
    if not token then
        return nil, "Invalid Authorization header format"
    end

    return token, nil
end

-- ============================================================================
-- Verify JWT token and extract claims
-- ============================================================================
function _M.verify_token(token)
    -- Create JWT verifier with secret
    local jwt_obj = jwt:verify(JWT_SECRET, token)
    
    if not jwt_obj then
        return nil, "Failed to parse token"
    end
    
    -- Check if token is valid
    if not jwt_obj.valid then
        local reason = jwt_obj.reason or "Invalid token"
        return nil, reason
    end

    -- Extract payload
    local payload = jwt_obj.payload
    if not payload then
        return nil, "Token payload is empty"
    end

    -- Check token expiration (if exp claim exists)
    if payload.exp then
        local current_time = ngx.time()
        if payload.exp < current_time then
            return nil, "Token has expired"
        end
    end

    return payload, nil
end

-- ============================================================================
-- Set user headers from JWT claims
-- ============================================================================
function _M.set_user_headers(claims)
    -- Extract user ID
    local user_id = claims.sub or claims.user_id or claims.id
    if user_id then
        ngx.req.set_header("X-User-ID", tostring(user_id))
    end

    -- Extract roles (can be string, array, or comma-separated string)
    local roles = claims.roles
    if roles then
        if type(roles) == "table" then
            roles = table.concat(roles, ",")
        elseif type(roles) == "string" then
            -- Already a string, use as is
        else
            roles = tostring(roles)
        end
        ngx.req.set_header("X-Roles", roles)
    end

    -- Extract permissions (can be string, array, or comma-separated string)
    local permissions = claims.permissions or claims.perms
    if permissions then
        if type(permissions) == "table" then
            permissions = table.concat(permissions, ",")
        elseif type(permissions) == "string" then
            -- Already a string, use as is
        else
            permissions = tostring(permissions)
        end
        ngx.req.set_header("X-Permissions", permissions)
    end
end

-- ============================================================================
-- Main authentication function
-- ============================================================================
-- Parameters:
--   mode: "none", "optional", or "required"
-- Returns:
--   true, nil on success
--   false, error_message on failure
-- ============================================================================
function _M.authenticate(mode)
    -- Clear headers first to prevent injection
    _M.clear_user_headers()

    -- Mode: none - no authentication required
    if mode == _M.AUTH_MODE_NONE then
        return true, nil
    end

    -- Extract token
    local token, err = _M.extract_token()
    
    -- Mode: optional - if no token, allow request
    if mode == _M.AUTH_MODE_OPTIONAL then
        if not token then
            return true, nil
        end
    end

    -- Mode: required - token must be present
    if mode == _M.AUTH_MODE_REQUIRED then
        if not token then
            return false, "Missing or invalid Authorization header"
        end
    end

    -- Verify token
    local claims, verify_err = _M.verify_token(token)
    if not claims then
        if mode == _M.AUTH_MODE_OPTIONAL then
            -- In optional mode, if token is invalid, just allow without auth
            return true, nil
        end
        return false, verify_err or "Token verification failed"
    end

    -- Set user headers
    _M.set_user_headers(claims)

    return true, nil
end

return _M

