# rogsoft-codexproxyd

`rogsoft-codexproxyd` 是给 ASUS Merlin 软件中心使用的控制面板插件，用来管理运行在 DockRoot 中的 `codex-tools-proxyd` 容器。

它是一个可选扩展包，不是方案 2 主线交付物。

方案 2 的主线只包含 DockRoot 容器包装、导入脚本、部署说明和最小测试，对应目录是：

- [../dockroot-proxyd/README-dockroot.md](../dockroot-proxyd/README-dockroot.md)

这个插件是在主线能力之外，额外提供 Merlin 后台图形控制面板。

## 当前定位

这个包负责 Merlin 软件中心里的扩展运维能力，例如：

- 查看 DockRoot 和容器状态
- 查看本机 URL、局域网 URL 和 API Key
- 保存镜像地址、默认模型、默认 effort 和审计日志级别
- 在页面内导入 `accounts.json` 或可移植 `auth.json`
- 执行拉取镜像、启动、停止、重启、删除容器、刷新 Key 等动作
- 查看运行日志、请求审计日志和错误日志
- 在发现宿主机残留进程冲突时提供清理入口

这些能力属于 Merlin 扩展口径，测试和验收标准也和 DockRoot 主线分开维护。

## 页面填写说明

- `镜像地址`
  - 填完整镜像引用，格式是 `仓库地址:标签`
  - 示例：`ghcr.io/liaoer/codex-tools-proxyd:latest`
  - `拉取/更新镜像` 只负责 pull
  - `启动` 或 `重启` 会自动刷新挂载配置并重新启动容器
- `Default Model`
- 默认值是 `gpt-5-4`
- `Default Effort`
  - 默认值是 `high`
- `Audit Log Level`
  - `off`：不记录审计日志
  - `basic`：记录方法、路径、状态码、耗时和上游请求标识等基础信息
  - `debug`：在 `basic` 的基础上额外记录请求和响应摘要

## 运行约定

- 平台：Merlin rogsoft `arm64`
- 容器名：`codexproxyd`
- 端口：`8787`
- DockRoot 路径：`<disk>/DockRootBin/DockRoot`
- 数据目录：`<disk>/codex-proxyd-data`
- 运行日志：`<disk>/DockRootData/codexproxyd/ruri.log`
- 审计日志：`<disk>/codex-proxyd-data/logs/access.jsonl`
- 调试日志：`<disk>/codex-proxyd-data/logs/debug.jsonl`
- 错误日志：`<disk>/codex-proxyd-data/logs/error.jsonl`

## 快速使用

1. 在 Merlin 软件中心离线安装 `codexproxyd.tar.gz`
2. 打开插件页面
3. 选择 ext4 U 盘或硬盘挂载点
4. 填写镜像地址，例如 `ghcr.io/liaoer/codex-tools-proxyd:latest`
5. 按需配置默认模型、effort 和日志级别
6. 点击“保存设置”
7. 导入 `accounts.json` 或完整 `auth.json`
8. 点击“拉取/更新镜像”
9. 点击“启动”

成功后页面会显示：

- 当前运行状态
- `http://127.0.0.1:8787/v1`
- `http://<router-lan-ip>:8787/v1`
- 当前 API Key

## 构建

在当前目录执行：

```bash
python build.py
```

这会完成：

- 同步模块版本
- 生成 `codexproxyd.tar.gz`
- 更新 `config.json.js` 中的 `md5` 和 `build_date`
- 更新根目录 `version`

也可以直接运行一键脚本：

```powershell
.\build-plugin.ps1
```

## 目录说明

- `config.json.js`
  - 软件中心离线安装包元数据
- `build.py`
  - 生成离线安装包并更新版本元数据
- `build-plugin.ps1`
  - Windows 一键打包脚本
- `codexproxyd/webs/Module_codexproxyd.asp`
  - 控制面板页面
- `codexproxyd/scripts/codexproxyd_status.sh`
  - 读取 DockRoot、容器和当前配置状态
- `codexproxyd/scripts/codexproxyd_action.sh`
  - 执行保存设置、导入账号、容器控制等动作
- `codexproxyd/scripts/codexproxyd_log.sh`
  - 读取运行日志、请求审计日志和错误日志

## 相关文档

- DockRoot 主线包装说明：[../dockroot-proxyd/README.md](../dockroot-proxyd/README.md)
- DockRoot 详细部署说明：[../dockroot-proxyd/README-dockroot.md](../dockroot-proxyd/README-dockroot.md)
