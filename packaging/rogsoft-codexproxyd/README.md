# rogsoft-codexproxyd

`rogsoft-codexproxyd` 是一个给 ASUS Merlin 软件中心使用的控制面板插件，用来管理运行在 DockRoot 中的 `codex-tools-proxyd` 容器。

它不是代理核心本身，而是给已经容器化的 `codexproxyd` 增加一层 Merlin 后台图形界面，方便在路由器页面里完成状态查看、账号导入、镜像管理和日志排障。

## 当前状态

当前版本已经在真实 Merlin 软件中心页面上跑通这些链路：

- 插件离线安装
- 软件中心卡片显示与页面打开
- DockRoot 检测和版本显示
- 容器状态读取
- 本机 URL / 局域网 URL / API Key 展示
- `accounts.json` 存在状态识别
- 运行日志、请求审计日志、错误日志查看
- 页面内保存设置
- 重装或升级时保留已保存配置

## 已实现能力

- 检查 DockRoot 是否可用，并显示版本
- 显示容器是否运行、PID、Base URL、API Key、最近错误
- 保存磁盘挂载点、镜像地址、开机自启
- 配置默认 `Model`
- 配置默认 `Effort`
- 配置审计日志级别：`off` / `basic` / `debug`
- 拉取或更新镜像
- 启动、停止、重启、删除容器
- 刷新 API Key
- 粘贴 `accounts.json` 或完整 `auth.json` 并导入
- 查看运行日志、请求审计日志、错误日志
- 自动轮询状态，运行中自动刷新日志

## 页面说明

- `Default Model`
  - 当前默认值是 `gpt-5.4`
  - 如果客户端请求没有显式传 `model`，服务端会回落到这里配置的默认值
- `Default Effort`
  - 当前默认值是 `high`
- `Audit Log Level`
  - `off`：不记录请求审计日志
  - `basic`：记录方法、路径、状态码、耗时、模型、上游请求 ID 等基础信息
  - `debug`：在 `basic` 基础上额外记录请求摘要和响应摘要
- `最近导入`
  - 如果账号是通过页面导入的，会显示导入时间
  - 如果数据目录里已存在 `accounts.json`，但不是通过页面导入的，会显示“已存在（外部导入）”

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

1. 在 Merlin 软件中心手动安装 `codexproxyd.tar.gz`
2. 打开插件页面
3. 选择 ext4 U 盘或硬盘挂载点
4. 填写镜像地址
5. 按需设置默认 Model、Effort 和日志级别
6. 点击“保存设置”
7. 导入 `accounts.json` 或 `auth.json`
8. 点击“拉取/更新镜像”
9. 点击“启动”

成功后页面会显示：

- 运行状态
- `http://127.0.0.1:8787/v1`
- `http://<router-lan-ip>:8787/v1`
- 当前 API Key

## 构建

在当前目录执行：

```bash
python build.py
```

这会完成：

- 同步模块 `version`
- 生成 `codexproxyd.tar.gz`
- 更新 `config.json.js` 中的 `md5` 和 `build_date`
- 更新根目录 `version`

## 目录说明

- `config.json.js`
  - 软件中心离线安装包元数据
- `build.py`
  - 生成离线安装包并更新版本元数据
- `codexproxyd/webs/Module_codexproxyd.asp`
  - 控制面板页面
- `codexproxyd/scripts/codexproxyd_status.sh`
  - 读取 DockRoot、容器和当前配置状态
- `codexproxyd/scripts/codexproxyd_action.sh`
  - 执行保存设置、导入账号、容器控制等动作
- `codexproxyd/scripts/codexproxyd_log.sh`
  - 读取运行日志、请求审计日志和错误日志

## 相关文档

- DockRoot 容器包装层简介：[../dockroot-proxyd/README.md](../dockroot-proxyd/README.md)
- DockRoot 详细部署说明：[../dockroot-proxyd/README-dockroot.md](../dockroot-proxyd/README-dockroot.md)
