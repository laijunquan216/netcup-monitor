Changelog (更新日志)

本项目的所有重要更改都将记录在此文件中。

格式基于 Keep a Changelog，
并且遵守 Semantic Versioning 语义化版本控制。

[Unreleased]

[v1.1.0] - 2024-05-20

Fixed (修复)

通知系统: 修复企业微信应用 (WeChat App) 推送 Markdown 消息在普通微信客户端被折叠的问题。

新增纯文本消息生成逻辑。

企业微信应用推送类型从 markdown 更改为 text，确保消息内容直接在聊天窗口完整显示。

流控逻辑: 修复了“保留分类 (Keep Categories)”种子在解除限速后无法自动恢复运行的 Bug。

修复了当仅存在保留分类种子（无 HR 种子）时，未生成恢复标记文件的问题。现在只要处于限速状态，无论是否有 HR 种子，都会强制生成标记文件。

恢复高速状态时，现在会执行全局 resume 操作，确保被暂停的保留种子能正确启动。

兼容性: 增强 qBittorrent API 兼容性 (适配 v4.x 及 v5.x)。

将启动命令标准化为 resume (符合 API v2 标准)。

增加 API 命令失败时的自动回退 (Fallback) 机制：如果 resume 失败尝试 start，如果 stop 失败尝试 pause。

Changed (变更)

优化了 app.py 中的日志记录格式，增加了更详细的时间戳。

[v1.0.0] - 2023-12-01

Initial Release (初始发布)

基础功能发布：Netcup RS/VPS 流量监控与自动化流控。

支持功能：

对接 Netcup SOAP API 获取实时流控状态。

qBittorrent 深度集成（HR 保护、自动删种、保留分类）。

Vertex 联动（根据限速状态动态更新 RSS 规则）。

多渠道通知（Telegram Bot、企业微信 Webhook/应用）。

Web 可视化仪表盘与配置管理。
