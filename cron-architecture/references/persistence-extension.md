# 持久化层扩展指南

Nanobot 的 cron 持久化目前基于 JSON 文件。本文档说明如何将存储层迁移到 MySQL、Redis 或其他数据库。

## 当前架构

`CronService` 的持久化集中在两个方法：

- `_load_store()` — 从文件加载，支持热加载（检测 `st_mtime`）
- `_save_store()` — 序列化写入文件

数据模型定义在 `nanobot/cron/types.py`：
- `CronStore` — 顶层容器，包含 `version` 和 `jobs` 列表
- `CronJob` — 单个任务，包含 schedule、payload、state
- `CronSchedule` / `CronPayload` / `CronJobState` / `CronRunRecord`

## 迁移方案

### 方案一：抽象 Store 接口（推荐）

将 `_load_store()` / `_save_store()` 抽象为独立的 `StoreBackend` 协议：

```python
from typing import Protocol

class CronStoreBackend(Protocol):
    """持久化后端抽象接口。"""

    async def load(self) -> CronStore:
        """加载所有任务。"""
        ...

    async def save(self, store: CronStore) -> None:
        """保存所有任务。"""
        ...

    async def get_job(self, job_id: str) -> CronJob | None:
        """按 ID 查询单个任务（可选优化）。"""
        ...

    async def upsert_job(self, job: CronJob) -> None:
        """插入或更新单个任务（可选优化）。"""
        ...

    async def delete_job(self, job_id: str) -> bool:
        """删除单个任务（可选优化）。"""
        ...
```

**JSON 实现**（保持现有行为）：

```python
class JsonStoreBackend:
    def __init__(self, path: Path):
        self.path = path

    async def load(self) -> CronStore:
        # 现有 _load_store 逻辑
        ...

    async def save(self, store: CronStore) -> None:
        # 现有 _save_store 逻辑
        ...
```

**MySQL 实现**：

```python
import aiomysql

class MySQLStoreBackend:
    def __init__(self, pool: aiomysql.Pool):
        self.pool = pool

    async def load(self) -> CronStore:
        async with self.pool.acquire() as conn:
            async with conn.cursor() as cur:
                await cur.execute("SELECT data FROM cron_jobs")
                rows = await cur.fetchall()
                jobs = [CronJob(**json.loads(r[0])) for r in rows]
                return CronStore(jobs=jobs)

    async def save(self, store: CronStore) -> None:
        async with self.pool.acquire() as conn:
            async with conn.cursor() as cur:
                await cur.execute("DELETE FROM cron_jobs")
                for job in store.jobs:
                    await cur.execute(
                        "INSERT INTO cron_jobs (id, data) VALUES (%s, %s)",
                        (job.id, json.dumps(asdict(job), default=str))
                    )
            await conn.commit()

    async def upsert_job(self, job: CronJob) -> None:
        async with self.pool.acquire() as conn:
            async with conn.cursor() as cur:
                await cur.execute(
                    """INSERT INTO cron_jobs (id, data) VALUES (%s, %s)
                       ON DUPLICATE KEY UPDATE data = VALUES(data)""",
                    (job.id, json.dumps(asdict(job), default=str))
                )
            await conn.commit()

    async def delete_job(self, job_id: str) -> bool:
        async with self.pool.acquire() as conn:
            async with conn.cursor() as cur:
                await cur.execute("DELETE FROM cron_jobs WHERE id = %s", (job_id,))
            await conn.commit()
            return cur.rowcount > 0
```

**Redis 实现**：

```python
import redis.asyncio as aioredis

class RedisStoreBackend:
    PREFIX = "cron:job:"

    def __init__(self, redis: aioredis.Redis):
        self.redis = redis

    async def load(self) -> CronStore:
        keys = await self.redis.keys(f"{self.PREFIX}*")
        jobs = []
        for key in keys:
            data = await self.redis.get(key)
            if data:
                jobs.append(CronJob(**json.loads(data)))
        return CronStore(jobs=jobs)

    async def save(self, store: CronStore) -> None:
        async with self.redis.pipeline() as pipe:
            existing = await self.redis.keys(f"{self.PREFIX}*")
            for key in existing:
                pipe.delete(key)
            for job in store.jobs:
                pipe.set(f"{self.PREFIX}{job.id}", json.dumps(asdict(job), default=str))
            await pipe.execute()

    async def upsert_job(self, job: CronJob) -> None:
        await self.redis.set(
            f"{self.PREFIX}{job.id}",
            json.dumps(asdict(job), default=str)
        )

    async def delete_job(self, job_id: str) -> bool:
        return bool(await self.redis.delete(f"{self.PREFIX}{job_id}"))
```

### 方案二：最小改动（直接修改 CronService）

如果不需要多后端切换，直接在 `CronService` 中替换 `_load_store()` 和 `_save_store()` 的实现即可。改动最小但扩展性较差。

## CronService 改造要点

### 1. 构造函数注入后端

```python
class CronService:
    def __init__(
        self,
        store_backend: CronStoreBackend,  # 替换原来的 store_path: Path
        on_job: Callable[[CronJob], Coroutine[Any, Any, str | None]] | None = None,
    ):
        self._backend = store_backend
        self.on_job = on_job
        # ...
```

### 2. 异步化加载和保存

当前 `_load_store()` / `_save_store()` 是同步方法（直接读写文件）。迁移到数据库后需要改为 `async`，同时更新所有调用点：

- `start()` 中 `_load_store()` → `await self._backend.load()`
- `_on_timer()` 中的加载/保存
- `add_job()` / `remove_job()` / `enable_job()` 等公共 API

注意：`add_job()` 等方法目前是同步的，改为 async 会影响 CronTool 中的调用方式。

### 3. 热加载策略调整

JSON 文件通过 `st_mtime` 检测变更。数据库后端需要不同策略：

- **轮询**：定时 `SELECT MAX(updated_at) FROM cron_jobs` 检测变更
- **Pub/Sub**：Redis Pub/Sub 或 MySQL 通知
- **跳过**：如果是单实例部署，可以去掉热加载

### 4. 配置化

在 `Config` 中添加后端选择：

```yaml
cron:
  backend: json          # json | mysql | redis
  json_path: cron/jobs.json
  mysql:
    host: localhost
    port: 3306
    database: nanobot
    user: nanobot
    password: ${MYSQL_PASSWORD}
  redis:
    url: redis://localhost:6379/0
```

## MySQL 建表参考

```sql
CREATE TABLE cron_jobs (
    id          VARCHAR(32)  PRIMARY KEY,
    name        VARCHAR(255) NOT NULL,
    enabled     BOOLEAN      DEFAULT TRUE,
    schedule    JSON         NOT NULL,
    payload     JSON         NOT NULL,
    state       JSON         NOT NULL,
    created_at  BIGINT       NOT NULL,
    updated_at  BIGINT       NOT NULL,
    delete_after_run BOOLEAN DEFAULT FALSE,
    INDEX idx_enabled_next_run ((CAST(state->>'$.nextRunAtMs' AS SIGNED)))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

将 `schedule`、`payload`、`state` 存为 JSON 列，既保持灵活性又方便查询。

## 测试策略

1. 为 `CronStoreBackend` 编写抽象测试套件（所有后端共享）
2. 每个 `StoreBackend` 实现只需通过该测试套件
3. 测试覆盖：CRUD、并发写入、大数据量、异常恢复
