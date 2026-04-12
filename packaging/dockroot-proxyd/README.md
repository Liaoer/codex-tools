# codex-tools-proxyd for DockRoot

这个目录是 `codex-tools-proxyd` 的 DockRoot 容器包装层，对应原始“方案 2”的主线交付物。

它只负责最小可运行能力：

- 在路由器上监听 `0.0.0.0:8787`
- 提供 `/health`、`/v1/models`、`/v1/chat/completions`、`/v1/responses`
- 将 `accounts.json` 和 `api-proxy.key` 持久化到 USB 挂载目录
- 提供 `auth.json -> accounts.json` 的本地导入脚本
- 提供 DockRoot 构建、部署和排障说明

它不负责：

- 复用桌面版 Tauri UI
- 修改 `codex-tools-proxyd` 核心协议逻辑
- 把 Merlin 软件中心控制面板纳入方案 2 主线验收

## 方案 2 主线边界

当前主线交付只包含这些内容：

- `Dockerfile`
- `docker-entrypoint.sh`
- `scripts/import_auth_to_accounts.py`
- `README-dockroot.md`

这条主线的目标是交付“容器镜像 + 导入脚本 + 部署说明 + 最小测试”。

## 运行约定

固定启动命令：

```bash
codex-tools-proxyd serve --data-dir /data --host 0.0.0.0 --port 8787 --no-sync-current-auth
```

推荐宿主机挂载：

```text
/tmp/mnt/sda1/codex-proxyd-data:/data
```

局域网客户端使用的 Base URL：

```text
http://<router-lan-ip>:8787/v1
```

镜像默认包含较保守的路由器保护参数：

- `CODEX_TOOLS_PROXY_MAX_BODY_MIB=16`
- `CODEX_TOOLS_PROXY_MAX_CONCURRENT_REQUESTS=2`
- `CODEX_TOOLS_PROXY_LOG_MAX_BYTES=524288`
- `CODEX_TOOLS_PROXY_MAX_UPSTREAM_BYTES=8388608`

## 快速开始

### 1. 构建并发布镜像

在仓库根目录执行：

```bash
docker buildx build \
  --platform linux/arm64 \
  -f packaging/dockroot-proxyd/Dockerfile \
  -t <public-image-ref> \
  --push \
  .
```

`<public-image-ref>` 指完整镜像引用，例如：

```text
ghcr.io/liaoer/codex-tools-proxyd:latest
```

### 2. 准备账号数据

优先使用桌面版 `codex-tools` 已导出的 `accounts.json`。

如果只有完整 `auth.json`，可先在本机转换：

```bash
python packaging/dockroot-proxyd/scripts/import_auth_to_accounts.py \
  --input /path/to/auth.json \
  --output /path/to/accounts.json
```

### 3. 上传到路由器数据目录

```bash
mkdir -p /tmp/mnt/sda1/codex-proxyd-data
chmod 700 /tmp/mnt/sda1/codex-proxyd-data
chmod 600 /tmp/mnt/sda1/codex-proxyd-data/accounts.json
```

### 4. 通过 DockRoot 启动

```bash
cd /tmp/mnt/sda1/DockRootBin
./DockRoot pull <public-image-ref> codexproxyd
./DockRoot run -v /tmp/mnt/sda1/codex-proxyd-data:/data --renew codexproxyd
./DockRoot run -d codexproxyd
./DockRoot ps codexproxyd
```

### 5. 验证状态

```bash
curl http://127.0.0.1:8787/health
```

## 可选 Merlin 扩展

仓库里另外提供了一个可选的 Merlin 软件中心扩展包：

- [../rogsoft-codexproxyd/README.md](../rogsoft-codexproxyd/README.md)

它不是方案 2 主线交付物。这个扩展包的界面能力、测试和验收口径都单独维护，不并入 DockRoot 主线定义。

## 文档入口

- 详细部署说明：[README-dockroot.md](./README-dockroot.md)
- 可选 Merlin 扩展说明：[../rogsoft-codexproxyd/README.md](../rogsoft-codexproxyd/README.md)
