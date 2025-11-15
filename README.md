# API Gateway

Production-ready API Gateway based on OpenResty, designed for Azure Container Apps and Dapr environments.

## 📁 Directory Structure

```
api-gateway/
├── Dockerfile              # Container image definition
├── entrypoint.sh           # Startup script (handles template rendering)
├── nginx.conf.tmpl         # Nginx main configuration template
├── conf.d/
│   ├── default.conf.tmpl   # Server configuration template
│   ├── api/                # API route configurations
│   │   ├── bible.conf.tmpl
│   │   └── search.conf.tmpl
│   └── common/             # Shared configurations
│       ├── cors.conf       # CORS settings
│       ├── dapr.conf       # Dapr proxy settings
│       ├── error.conf      # Error handling
│       ├── fqdn.conf       # Backend service FQDN variables
│       ├── health.conf     # Health check endpoints
│       └── streaming.conf  # Streaming configuration
├── lua/                    # Custom Lua modules
│   └── health_services.lua # Health check service configuration
└── README.md
```

## 🚀 Core Features

- **Modular Configuration**: Clear directory structure with separation of configuration and code
- **Dapr Integration**: Service invocation through Dapr sidecar
- **Template-based Configuration**: Environment variable injection using dockerize
- **Performance Optimization**: Gzip compression, connection pooling, buffer optimization
- **Security**: Rate limiting, connection limits, security headers
- **Monitoring Support**: Health check endpoints, detailed logging, metrics

## 🔧 Quick Start

### Local Development

```bash
# Build image
docker build -t api-gateway .

# Run container
docker run -p 10000:10000 \
  -e SERVER_NAME=localhost \
  -e EXPOSE_PORT=10000 \
  api-gateway

# Test health check
curl http://localhost:10000/health
```

### Environment Variables

- `SERVER_NAME`: Server name (default: `localhost`)
- `EXPOSE_PORT`: Listening port (default: `10000`)
- `DAPR_SIDECAR_URL`: Dapr sidecar URL (default: `http://127.0.0.1:3500`)

## 📝 Configuration

### Backend Service Configuration

Define Dapr invocation addresses for backend services in `conf.d/common/fqdn.conf`:

```nginx
set $bible_api_base http://127.0.0.1:3500/v1.0/invoke/bible-api/method;
set $search_api_base http://127.0.0.1:3500/v1.0/invoke/search-api/method;
```

### Health Check Service List

Configure services to be checked in `lua/health_services.lua`:

```lua
_M.services = {
    { name = "bible-api", app_id = "bible-api" },
    { name = "search-api", app_id = "search-api" },
}
```

### Adding New API Routes

1. Create a new `.conf.tmpl` file in `conf.d/api/`
2. Define location rules and corresponding Dapr service invocations
3. Reference existing `bible.conf.tmpl` or `search.conf.tmpl`

## ☁️ Azure Container Apps Deployment

### Basic Configuration

```yaml
resources:
  cpu: 0.25
  memory: 0.5Gi

scale:
  minReplicas: 1
  maxReplicas: 10

ingress:
  external: true
  targetPort: 10000

probes:
  liveness:
    httpGet:
      path: /health
      port: 10000
    periodSeconds: 30
  readiness:
    httpGet:
      path: /health
      port: 10000
    periodSeconds: 10
```

### Environment Variables

```yaml
env:
  - name: SERVER_NAME
    value: "your-domain.com"
  - name: EXPOSE_PORT
    value: "10000"
```

## 📊 Endpoints

- `GET /health`: Gateway health status (JSON format)
- `GET /health/services`: Aggregated health status of all backend services
- `GET /metrics`: Nginx stub status (localhost only)

## 🔒 Security Features

- **Rate Limiting**: API 100 req/s (burst=50), Health 10 req/s (burst=5)
- **Connection Limits**: Maximum 50 concurrent connections per IP
- **Security Headers**: X-Frame-Options, X-Content-Type-Options, X-XSS-Protection
- **Hide Server Information**: Removes Server and X-Powered-By headers

## 🐛 Troubleshooting

### View Logs

```bash
# Azure Container Apps
az containerapp logs show -n api-gateway -g <resource-group> --follow
```

### Common Issues

- **502 Bad Gateway**: Check backend service status and Dapr sidecar connection
- **429 Too Many Requests**: Rate limiting triggered, adjust rate limit parameters
- **Cannot Access Backend**: Verify Dapr app-id and sidecar URL configuration

## 📚 Resources

- [OpenResty Documentation](https://openresty.org/)
- [Dapr Documentation](https://docs.dapr.io/)
- [Azure Container Apps](https://learn.microsoft.com/azure/container-apps/)

## 📄 License

Apache License 2.0 - Copyright (c) 2025 rayselfs@alive.org.tw

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
implied. See the License for the specific language governing
permissions and limitations under the License.
