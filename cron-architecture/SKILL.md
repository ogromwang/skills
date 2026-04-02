---
name: cron-architecture
description: >
  Nanobot 定时任务系统的完整架构设计与实现原理。涵盖 cron 任务创建、调度执行、消息队列投递、
  channel 路由的全链路流程。适用于需要理解、扩展或二次开发定时任务功能的场景，包括持久化层
  扩展（如迁移到 MySQL/Redis）、新增 channel 适配、自定义调度策略等。
---

# Cron 架构设计

Nanobot 的定时任务系统是一个完整的异步调度框架，让 LLM 能够自主创建、管理和执行定时任务，
并将结果精准路由回原始对话。

## 系统总览

```
用户消息 → Channel → MessageBus.inbound → AgentLoop → LLM 调用 cron tool
                                                          ↓
                                                  CronService.add_job()
                                                 (持久化到 jobs.json)
                                                          ↓
                                                asyncio.sleep() 定时等待
                                                          ↓
                                                CronService._on_timer()
                                                          ↓
                                                on_cron_job() 回调
                                                          ↓
                                              agent.process_direct()
                                                (LLM 生成回复)
                                                          ↓
                                    ┌─ LLM 用了 message tool → bus.publish_outbound()
                                    │
                                    └─ 未用 message tool → evaluate_response()
                                                             ↓ (值得通知)
                                                    bus.publish_outbound()
                                                             ↓
                                    ChannelManager._dispatch_outbound()
                                         (从 bus.outbound 消费)
                                                             ↓
                                    channel.send() → 投递到用户
```

## 五阶段详解

### 阶段一：LLM 创建定时任务

涉及文件：`nanobot/agent/tools/cron.py`、`nanobot/cron/service.py`

**1. 工具注册与上下文注入**

`AgentLoop` 构造时将 `CronTool` 注册到工具表。当处理用户消息时，调用 `_set_tool_context()` 将当前 `channel` 和 `chat_id` 注入到 CronTool，确保任务"记住"来源对话。

**2. 三种调度类型**

| 类型 | 触发方式 | 参数 | 示例 |
|------|---------|------|------|
| `"at"` | 一次性，执行后删除或禁用 | `at: "2026-04-02T15:30:00"` | 会议提醒 |
| `"every"` | 固定间隔 | `every_seconds: 1800` | 每30分钟喝水 |
| `"cron"` | cron 表达式，支持时区 | `cron_expr: "0 9 * * 1-5", tz: "Asia/Shanghai"` | 工作日早9点 |

**3. 递归防护**

`ContextVar` 机制：cron 回调执行期间 `_in_cron_context=True`，LLM 此时调用 `cron add` 会被拒绝，防止无限嵌套。

### 阶段二：持久化与调度

涉及文件：`nanobot/cron/service.py`、`nanobot/cron/types.py`

**1. 数据模型**

```
CronJob
├── id: str                 # UUID 前8位
├── name: str               # 任务名称（message 前30字符）
├── enabled: bool           # 是否启用
├── schedule: CronSchedule  # 调度配置
│   ├── kind: "at" | "every" | "cron"
│   ├── at_ms: int          # 一次性时间戳
│   ├── every_ms: int       # 间隔毫秒
│   ├── expr: str           # cron 表达式
│   └── tz: str             # IANA 时区
├── payload: CronPayload    # 执行载荷
│   ├── message: str        # 给 LLM 的指令
│   ├── deliver: bool       # 是否投递结果
│   ├── channel: str        # 路由目标 channel
│   └── to: str             # 路由目标 chat_id
├── state: CronJobState     # 运行状态
│   ├── next_run_at_ms: int
│   ├── last_run_at_ms: int
│   ├── last_status: str
│   └── run_history: list
└── delete_after_run: bool  # 一次性任务标志
```

**2. 单定时器机制**

`_arm_timer()` 不是轮询，而是只设一个 `asyncio.sleep()` 指向所有任务中最早到期的时间点。触发后执行到期任务，再重新计算下一个最早时间。

**3. 当前持久化**

JSON 文件 (`{workspace}/cron/jobs.json`)，启动时加载，变更时写入。支持外部修改后热加载（通过 `st_mtime` 检测）。

### 阶段三：任务触发与 Agent 执行

涉及文件：`nanobot/cli/commands.py`（`on_cron_job` 回调）

**核心回调逻辑**：

```python
async def on_cron_job(job: CronJob) -> str | None:
    # 1. 构造提示词
    reminder_note = "[Scheduled Task] Timer finished. ..."

    # 2. 设置递归防护
    cron_token = cron_tool.set_cron_context(True)

    # 3. 绕过 inbound queue，直接调用 agent
    resp = await agent.process_direct(
        reminder_note,
        session_key=f"cron:{job.id}",
        channel=job.payload.channel,
        chat_id=job.payload.to,
    )

    # 4. 判断投递方式
    if message_tool._sent_in_turn:
        return  # LLM 已主动发送
    if job.payload.deliver and job.payload.to and response:
        should_notify = await evaluate_response(...)
        if should_notify:
            await bus.publish_outbound(OutboundMessage(...))
```

**关键设计**：`process_direct()` 绕过 inbound queue，因为 cron 触发不是用户消息，不需要排队。

### 阶段四：响应评估

涉及文件：`nanobot/utils/evaluator.py`

轻量级 LLM 调用，让模型判断响应是否值得通知用户：
- **通知**：包含可操作信息、错误、完成的交付物、用户明确要求的提醒
- **抑制**：例行状态检查且无新信息、一切正常的确认、空内容

失败时默认通知（`True`），确保重要消息不被静默丢弃。

### 阶段五：消息投递到 Channel

涉及文件：`nanobot/bus/queue.py`、`nanobot/channels/manager.py`

**1. MessageBus（双队列）**

```python
class MessageBus:
    inbound: asyncio.Queue[InboundMessage]   # Channel → Agent
    outbound: asyncio.Queue[OutboundMessage]  # Agent → Channel
```

**2. ChannelManager 消费循环**

`_dispatch_outbound()` 是常驻异步循环：
- 从 `bus.consume_outbound()` 阻塞等待消息
- 根据 `msg.channel` 查找对应的 `BaseChannel` 实例
- 调用 `_send_with_retry()` 发送，带指数退避（1s → 2s → 4s）

**3. OutboundMessage 路由**

```python
@dataclass
class OutboundMessage:
    channel: str    # 目标 channel 名称（如 "telegram"）
    chat_id: str    # 目标会话 ID
    content: str    # 消息内容
    reply_to: str | None = None
    media: list[str] = field(default_factory=list)
    metadata: dict[str, Any] = field(default_factory=dict)
```

## 持久化扩展指南

当前实现使用 JSON 文件存储。如需迁移到 MySQL 等数据库，参见 [references/persistence-extension.md](references/persistence-extension.md)。

## 关键文件索引

| 文件 | 职责 |
|------|------|
| `nanobot/cron/types.py` | 数据模型定义（CronJob/CronSchedule/CronPayload） |
| `nanobot/cron/service.py` | 调度核心（定时器/执行/持久化/公共 API） |
| `nanobot/agent/tools/cron.py` | LLM 工具接口（add/list/remove + 上下文捕获） |
| `nanobot/bus/queue.py` | 异步消息总线（inbound/outbound 双队列） |
| `nanobot/bus/events.py` | 消息类型定义（InboundMessage/OutboundMessage） |
| `nanobot/channels/manager.py` | Channel 管理与消息路由分发 |
| `nanobot/channels/base.py` | Channel 抽象基类 |
| `nanobot/cli/commands.py` | 系统组装（on_cron_job 回调 + 依赖注入） |
| `nanobot/utils/evaluator.py` | 响应评估（是否通知用户） |
