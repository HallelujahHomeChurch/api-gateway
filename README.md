# API Gateway Configuration

生產環境級別的 Nginx API Gateway 配置，針對 Azure Container Apps 環境優化。

## 📁 檔案結構

```
api-gateway/
├── Dockerfile                      # 容器映像定義（含 headers-more 模組 v0.39）
├── nginx.conf                      # 主配置文件（全局設置 + 載入模組）
├── conf.d/
│   ├── default.conf                # 主要 Server 配置與路由規則
│   └── common/                     # 共用配置目錄
│       ├── resolvers.conf          # DNS Resolver 配置
│       ├── host.conf               # 後端服務 Host 變數定義
│       ├── proxy.conf              # 共用 Proxy 設定
│       ├── error.conf              # 錯誤處理頁面
│       └── health.conf             # 健康檢查與監控端點
├── .azure-devops/
│   └── azure-pipelines.yml         # Azure DevOps CI/CD 流程
├── .dockerignore                   # Docker 建置忽略文件
├── .gitignore                      # Git 忽略文件
├── LICENSE                         # MIT 授權文件
└── README.md                       # 本文件
```

## 🚀 核心特性

### 1. 模組化配置架構
- ✅ **DNS Resolver**: `common/resolvers.conf` Azure 內部 DNS 配置
- ✅ **變數化 Host**: `common/host.conf` 集中管理後端服務 FQDN
- ✅ **共用 Proxy 設定**: `common/proxy.conf` 統一管理 proxy 行為
- ✅ **獨立錯誤處理**: `common/error.conf` 自訂錯誤頁面
- ✅ **健康檢查**: `common/health.conf` 提供 `/health` 和 `/metrics` 端點
- ✅ **清晰的路由配置**: `default.conf` 僅關注路由規則（54 行）

### 2. 性能優化
- ✅ **Worker 優化**: 自動設置 worker 數量，最大連接數 4096
- ✅ **HTTP/1.1**: 使用 HTTP/1.1 與後端通信
- ✅ **SSL Session Reuse**: 重用 SSL session，減少握手開銷
- ✅ **Gzip 壓縮**: 自動壓縮 JSON/JS/CSS 等響應
- ✅ **Buffer 優化**: 8k buffer size，16 buffers
- ✅ **TCP 優化**: tcp_nopush, tcp_nodelay, sendfile
- ✅ **智能重試**: 自動重試（最多 2 次），timeout 5s

### 3. 增強安全性
- ✅ **Rate Limiting**: API 100 req/s（burst=50），Health 10 req/s（burst=5）
- ✅ **Connection Limiting**: 每個 IP 最多 50 個並發連接
- ✅ **安全 Headers**: X-Frame-Options, X-Content-Type-Options, X-XSS-Protection
- ✅ **隱藏服務器信息**: 使用 headers-more-nginx-module v0.39 完全移除 Server 和 X-Powered-By headers
- ✅ **隱藏文件保護**: 拒絕訪問 .git, .htaccess 等敏感文件
- ✅ **TLS 1.2/1.3**: 與 Azure Container Apps 內部通信使用 HTTPS
- ✅ **SSL 驗證關閉**: 信任內部網路的自簽證書

### 4. 監控與日誌
- ✅ **詳細日誌**: 包含響應時間、upstream 時間等指標
- ✅ **Metrics 端點**: `/metrics` 提供 nginx stub_status（僅限內部訪問）
- ✅ **Health Check**: `/health` 端點返回 JSON 格式健康狀態
- ✅ **日誌緩衝**: 減少 I/O 操作，提升性能（32k buffer, 5s flush）

### 5. 容錯機制
- ✅ **自動重試**: 遇到錯誤自動重試（最多 2 次）
- ✅ **超時設置**: 連接 10s, 讀取 60s, 發送 60s
- ✅ **優雅降級**: 統一的 JSON 格式錯誤響應（429, 500, 502, 503, 504）
- ✅ **智能 upstream**: 自動重試 error, timeout, 5xx 錯誤

## 📊 配置參數說明

### Rate Limiting
```nginx
api_limit: 100 req/s, burst=50      # 一般 API 請求
health_limit: 10 req/s, burst=5     # 健康檢查
addr: 最多 50 個並發連接             # 每個 IP
```

### Connection Pool
```nginx
keepalive: 64 connections           # 保持 64 個連接
keepalive_requests: 1000            # 每個連接最多 1000 個請求
keepalive_timeout: 60s              # 閒置 60 秒後關閉
```

### Timeouts
```nginx
proxy_connect_timeout: 10s          # 連接後端超時
proxy_send_timeout: 60s             # 發送請求超時
proxy_read_timeout: 60s             # 讀取響應超時
```

## 🌐 後端服務配置

### 變數化 Host 管理

本 Gateway 透過 `conf.d/common/host.conf` 集中管理後端服務 FQDN：

```nginx
# conf.d/common/host.conf
# Azure Container Apps Environment
set $aca_environment "gentleriver-81abd7bc.eastasia.azurecontainerapps.io";

# Backend Services
set $bible_api_host "bible-api.internal.$aca_environment";
set $alive_app_host "alive-app.internal.$aca_environment";
```

**注意**: 
- `host.conf` 透過 `default.conf` 的 `include` 指令載入在 `server` 區塊內，因此可以使用 `set` 指令。
- 使用變數進行 `proxy_pass` 需要配置 DNS resolver（見下方）

### DNS Resolver 配置

當 `proxy_pass` 使用變數時，nginx 需要在運行時動態解析域名，必須配置 resolver。

我們將 DNS resolver 配置獨立在 `conf.d/common/resolvers.conf`：

```nginx
# conf.d/common/resolvers.conf
resolver 168.63.129.16 valid=30s ipv6=off;
resolver_timeout 5s;
```

在 `default.conf` 中引用：

```nginx
# conf.d/default.conf
server {
    include /etc/nginx/conf.d/common/resolvers.conf;
    ...
}
```

**重要說明：**
- `168.63.129.16` 是 Azure 虛擬網路的內部 DNS resolver
- `valid=30s` DNS 緩存時間為 30 秒
- `ipv6=off` 禁用 IPv6 查詢
- `resolver_timeout=5s` DNS 查詢超時時間
- **必須在 server 區塊內 include**（resolver 指令不能在 http 區塊使用）

### 在 Location 中使用

```nginx
location ~ ^/api/bible/v[0-9]+ {
    proxy_pass https://$bible_api_host;
    proxy_ssl_name $bible_api_host;
    proxy_set_header Host $bible_api_host;
}
```

### 優勢
- ✅ **集中管理**: 所有 host 定義在一個文件中
- ✅ **易於維護**: 更換環境只需修改 `$aca_environment`
- ✅ **減少錯誤**: 避免在多處重複長 FQDN
- ✅ **可擴展**: 新增服務只需添加一行變數定義

### Proxy 設定

共用的 proxy 配置統一在 `conf.d/common/proxy.conf`：
- **協議**: HTTPS (TLS 1.2/1.3)
- **HTTP 版本**: 1.1
- **超時**: 連接 10s, 讀取/發送 60s
- **Buffer**: 8k x 16
- **重試**: 最多 2 次，5s timeout

## ☁️ Azure Container Apps 部署

### 1. 資源配置建議
```yaml
resources:
  cpu: 0.25        # 0.25 vCPU
  memory: 0.5Gi    # 512 Mi
```

### 2. 縮放規則
```yaml
scale:
  minReplicas: 1
  maxReplicas: 10
  rules:
    - name: http-scaling
      http:
        metadata:
          concurrentRequests: "100"
```

### 3. 健康檢查
```yaml
probes:
  liveness:
    httpGet:
      path: /health
      port: 10000
    initialDelaySeconds: 10
    periodSeconds: 30
    
  readiness:
    httpGet:
      path: /health
      port: 10000
    initialDelaySeconds: 5
    periodSeconds: 10
```

### 4. Ingress 配置
```yaml
ingress:
  external: true
  targetPort: 10000
  transport: auto
  allowInsecure: false
```

## 🔧 Nginx 模組

### headers-more-nginx-module (v0.39)

本 Gateway 編譯並載入了 `headers-more-nginx-module`，提供更強大的 header 操作能力。

**功能：**
- ✅ 完全移除 response headers（包括 Server 和 X-Powered-By）
- ✅ 比 `proxy_hide_header` 更徹底的 header 控制
- ✅ 可以修改、添加、清除任何 HTTP header

**使用：**
```nginx
# nginx.conf
load_module modules/ngx_http_headers_more_filter_module.so;

more_clear_headers 'Server';
more_clear_headers 'X-Powered-By';
```

**自訂版本：**
```dockerfile
# Dockerfile
ARG HEADERS_MORE_VERSION=0.39
docker build --build-arg HEADERS_MORE_VERSION=0.40 -t api-gateway .
```

**編譯流程：**
- 自動偵測當前 nginx 版本
- 下載對應的 nginx 源碼和模組
- 編譯為動態模組 (.so)
- 編譯完成後清理依賴，保持映像精簡

## 📈 監控指標

### Nginx Stub Status
訪問 `/metrics` 端點（僅限容器內部）可獲取以下資訊：
- **Active connections**: 當前活躍連接數
- **Accepts/Handled/Requests**: 接受/處理的連接數與請求總數
- **Reading/Writing/Waiting**: 當前讀取/寫入/等待的連接數

### 日誌格式
```nginx
$remote_addr - $remote_user [$time_local] "$request" 
$status $body_bytes_sent "$http_referer" "$http_user_agent" 
"$http_x_forwarded_for" 
rt=$request_time uct="$upstream_connect_time" 
uht="$upstream_header_time" urt="$upstream_response_time"
```

### Azure Monitor 整合
可以透過 Azure Container Apps 的日誌串流查看：
```bash
az containerapp logs show -n api-gateway -g <resource-group> --follow
```

## 🔧 調優建議

### 高流量場景 (>1000 req/s)
```nginx
worker_connections 8192;           # 增加連接數
keepalive 128;                     # 增加連接池
limit_req rate=500r/s burst=100;   # 提高限流閾值
```

### 大文件上傳
```nginx
client_max_body_size 100m;         # 增加最大請求大小
proxy_read_timeout 300s;           # 增加讀取超時
```

### 長連接/SSE
```nginx
proxy_buffering off;               # 禁用緩衝
proxy_read_timeout 3600s;          # 增加超時
```

## 🧪 測試

### 本地測試
```bash
# 1. 驗證配置
docker build -t api-gateway .
docker run --rm api-gateway nginx -t

# 2. 本地運行（需要後端服務可用）
docker run -d -p 9999:9999 --name api-gateway api-gateway

# 3. 測試健康檢查
curl http://localhost:9999/health

# 預期輸出：
# {"status":"ok","service":"api-gateway","timestamp":"2025-10-11T12:00:00+00:00"}

# 4. 測試限流（快速發送多個請求）
for i in {1..60}; do curl http://localhost:9999/health; done

# 預期：部分請求會收到 429 Too Many Requests

# 5. 壓力測試（如果已安裝 Apache Bench）
ab -n 1000 -c 50 http://localhost:9999/health
```

### Azure Container Apps 部署測試
```bash
# 1. 使用 Azure CLI 部署
az containerapp create \
  --name api-gateway \
  --resource-group <your-resource-group> \
  --environment <your-environment> \
  --image <your-acr>.azurecr.io/api-gateway:latest \
  --target-port 9999 \
  --ingress external \
  --min-replicas 1 \
  --max-replicas 10 \
  --cpu 0.25 --memory 0.5Gi

# 2. 測試健康端點
GATEWAY_URL=$(az containerapp show -n api-gateway -g <resource-group> --query properties.configuration.ingress.fqdn -o tsv)
curl https://$GATEWAY_URL/health

# 3. 測試 API 路由
curl https://$GATEWAY_URL/your-api-path
```

### 生產環境檢查清單
- [ ] ✅ 確認後端服務的內部 FQDN 正確配置
- [ ] ✅ 調整 rate limiting 參數適合你的流量
- [ ] ✅ 確認 Azure Container Apps 資源配置合理
- [ ] ✅ 配置自動縮放規則
- [ ] ✅ 設置健康檢查探針
- [ ] ✅ 整合 Azure Monitor 和告警
- [ ] ✅ 配置 Application Insights（可選）
- [ ] ✅ 測試故障轉移行為
- [ ] ✅ 壓力測試驗證性能

## 🐛 故障排查

### 查看日誌
```bash
# 實時查看日誌
az containerapp logs show \
  --name api-gateway \
  --resource-group <resource-group> \
  --follow

# 查看最近的日誌
az containerapp logs show \
  --name api-gateway \
  --resource-group <resource-group> \
  --tail 100
```

### 檢查 metrics（容器內部）
```bash
# 進入容器
az containerapp exec \
  --name api-gateway \
  --resource-group <resource-group> \
  --command /bin/sh

# 檢查 metrics
curl localhost:9999/metrics

# 檢查健康狀態
curl localhost:9999/health
```

### 檢查 Container App 狀態
```bash
# 查看基本資訊
az containerapp show \
  --name api-gateway \
  --resource-group <resource-group>

# 查看修訂版本
az containerapp revision list \
  --name api-gateway \
  --resource-group <resource-group> \
  -o table

# 查看副本數
az containerapp replica list \
  --name api-gateway \
  --resource-group <resource-group> \
  -o table
```

### 常見問題

**問題**: 502 Bad Gateway
- **原因**: 後端服務不可用或響應超時
- **檢查**: 
  ```bash
  # 檢查後端服務狀態
  az containerapp show -n <backend-service-name> -g <resource-group> --query "properties.runningStatus"
  ```
- **解決**: 確認後端服務正常運行，檢查網路連接

**問題**: 429 Too Many Requests
- **原因**: 觸發 rate limiting
- **檢查**: 查看日誌中的請求頻率
- **解決**: 調整 `limit_req` 參數或優化客戶端請求頻率

**問題**: 499 Client Closed Request
- **原因**: 客戶端在 nginx 響應前關閉連接
- **解決**: 增加 client timeout，優化後端響應速度

**問題**: 無法訪問後端服務
- **原因**: 後端服務的內部 FQDN 配置錯誤或網路問題
- **檢查**: 
  ```bash
  # 確認後端服務的內部 FQDN
  az containerapp show -n <backend-service-name> -g <resource-group> --query "properties.configuration.ingress.fqdn"
  ```
- **解決**: 更新 `conf.d/common/host.conf` 中的 server 地址

## 📝 配置更新

### 更新後端服務地址
只需修改 `conf.d/common/host.conf`：
```nginx
# 更新環境
set $aca_environment "new-environment-id.eastasia.azurecontainerapps.io";

# 或新增服務
set $new_service_host "new-service.internal.$aca_environment";
```

### 調整 Proxy 設定
修改 `conf.d/common/proxy.conf`，所有 location 自動套用：
```nginx
# 例如：增加 timeout
proxy_connect_timeout 20s;
proxy_read_timeout 120s;
```

### 調整 Rate Limiting
1. 修改 `nginx.conf` 中的 `limit_req_zone` 參數
2. 修改 `default.conf` 中各 location 的 `limit_req` 設置
3. 重新部署

### 新增路由
在 `default.conf` 中添加新的 location：
```nginx
location /api/new-service {
    limit_req zone=api_limit burst=50 nodelay;
    proxy_pass https://$new_service_host;
    proxy_ssl_name $new_service_host;
    proxy_set_header Host $new_service_host;
}
```

## 🔒 安全建議

### 1. 網路隔離
- ✅ 使用 Azure Container Apps Environment 的內部網路
- ✅ 後端服務設置為僅內部訪問（internal ingress）
- ✅ Gateway 設置為外部訪問（external ingress）

### 2. TLS/SSL
- ✅ 與後端服務通信使用 HTTPS（TLS 1.2/1.3）
- ✅ Azure Container Apps 自動提供 TLS 終止
- ✅ 啟用 SSL session reuse 減少開銷

### 3. Rate Limiting 策略
- ✅ API 端點：100 req/s per IP
- ✅ Health 端點：10 req/s per IP
- ✅ 連接限制：50 concurrent connections per IP
- ⚠️ 建議根據實際流量調整

### 4. 日誌和監控
- ✅ 記錄詳細的請求指標
- ✅ 整合 Azure Monitor
- ✅ 設置告警規則（錯誤率、延遲等）

## 📚 相關資源

- [Azure Container Apps 文檔](https://learn.microsoft.com/azure/container-apps/)
- [Nginx 官方文檔](https://nginx.org/en/docs/)
- [Nginx 最佳實踐](https://www.nginx.com/blog/nginx-high-performance-caching/)
- [headers-more-nginx-module](https://github.com/openresty/headers-more-nginx-module)

## 📄 授權

本專案採用 [MIT License](LICENSE)。

Copyright (c) 2025 rayselfs@alive.org.tw

