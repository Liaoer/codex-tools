# codex-tools-proxyd for DockRoot

这个目录提供 `codex-tools-proxyd` 的 DockRoot 容器包装层，用于在 ASUS Merlin 路由器上以轻量容器方式运行 OpenAI 兼容 API 反代。

当前实现的核心目标是：

- 监听 `0.0.0.0:8787`
- 暴露 `/health`、`/v1/models`、`/v1/chat/completions`、`/v1/responses`
- 把 `accounts.json` 和 `api-proxy.key` 持久化到 USB 数据目录
- 不依赖 `systemd`
- 不复用 Tauri 桌面 UI
- 默认只面向局域网使用

## 当前状态

- 上游核心: `codex-tools-proxyd`
- 目标平台: `linux/arm64`
- 运行方式: `DockRoot`
- 默认端口: `8787`
- 已提供可选 Merlin 软件中心控制面板

## 适用场景

- 你已经在梅林路由器上安装了 DockRoot
- 你希望把 API 反代常驻运行在路由器，而不是桌面电脑
- 你需要重启后可恢复、镜像升级后可复用的数据目录
- 你可以接受先用 DockRoot 命令行方式运行，或者再叠加软件中心控制面板

## 不适合的场景

- 你想直接复用桌面版 Tauri 管理界面
- 你需要 `systemd`、SSH 一键部署、远程守护运维这一整套流程
- 你希望默认暴露到公网
- 你手里还没有可移植的 `accounts.json` 或完整 `auth.json`

## 核心能力

- 多阶段 Docker 构建，直接编译 `src-tauri/proxyd`
- `alpine` 运行时镜像，便于在容器内排障
- 启动前强制检查 `/data/accounts.json`
- 持久化目录固定为 `/data`
- 提供本地 `auth.json -> accounts.json` 转换脚本

## 可选软件中心控制面板

除了纯 DockRoot 运行方式，仓库现在还提供一个可选的 Merlin 软件中心插件：

- [../rogsoft-codexproxyd/README.md](../rogsoft-codexproxyd/README.md)

这个插件可以在 Merlin 后台中完成：

- DockRoot 和容器状态查看
- URL 和 API Key 展示
- `accounts.json` / `auth.json` 页面导入
- 拉取镜像、启动、停止、重启、删除容器
- 查看运行日志

## 运行约定

容器固定用下面的命令启动：

```bash
codex-tools-proxyd serve --data-dir /data --host 0.0.0.0 --port 8787 --no-sync-current-auth
```

推荐挂载：

```text
/tmp/mnt/sda1/codex-proxyd-data:/data
```

局域网客户端使用的 Base URL：

```text
http://<router-lan-ip>:8787/v1
```

## 目录说明

- `Dockerfile`
  - 构建 `linux/arm64` 镜像
- `docker-entrypoint.sh`
  - 启动前检查 `/data/accounts.json`
- `scripts/import_auth_to_accounts.py`
  - 把可移植 `auth.json` 转成单账号 `accounts.json`
- `README-dockroot.md`
  - 更详细的构建、部署、验证说明

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

### 2. 准备账号数据

优先使用桌面版 `codex-tools` 已导出的 `accounts.json`。

如果只有完整 `auth.json`，可以先在本机转换：

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
```

### 5. 验证状态

```bash
curl http://127.0.0.1:8787/health
```

## 已实现范围

- DockRoot 容器包装层
- `arm64` 构建路径
- 启动入口检查与固定启动参数
- `auth.json -> accounts.json` 导入脚本
- 详细部署文档
- 可选 Merlin 软件中心控制面板

## 当前不包含

- Tauri UI 复用
- SSH 远程部署流程
- `systemd` 管理
- Cloudflare / DDNS / 公网接入

## 下一步可扩展方向

- 镜像升级检查和快速回滚
- 更完整的 API 健康检查
- 受控公网访问评估
- 面板侧更多运维信息展示

## 文档入口

- 详细部署说明: [README-dockroot.md](./README-dockroot.md)
- 软件中心插件说明: [../rogsoft-codexproxyd/README.md](../rogsoft-codexproxyd/README.md)
