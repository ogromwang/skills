# AGENTS.md

当您需要为本项目添加新的 Claude Skill 时，请遵循以下规范。

## 项目结构

```
claude-skills/
├── skill-name/
│   ├── SKILL.md              # 必需：技能定义
│   ├── scripts/              # 可选：执行脚本
│   ├── references/           # 可选：参考资料
│   └── assets/               # 可选：模板资源
└── AGENTS.md                 # 本文件
```

## 创建新 Skill 步骤

1. 在 `claude-skills/` 下创建目录
2. 创建 `SKILL.md`，包含 YAML frontmatter 和说明
3. 如需要，在 `scripts/` 添加执行脚本
4. 更新 `README.md` 的 Skills 表格

## SKILL.md 格式

### 必须包含 YAML frontmatter：

```yaml
---
name: skill-name              # 小写字母+连字符，1-64字符
description: 技能描述...       # 1-1024字符，说明做什么和何时使用
---
```

### 建议的正文结构：

```markdown
# 技能标题

## 使用场景

- 用户可能说的话...
- 触发条件...

## 工作流程

**始终使用脚本执行**：
```bash
bash scripts/script.sh <参数>
```

## 详细说明

[Claude 如何执行此任务]

## 注意事项

[边界情况和错误处理]
```

## 脚本规范

### 必须使用 `set -e`：

```bash
#!/bin/bash
set -e
```

### 使用颜色输出：

```bash
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

info() { echo -e "${GREEN}→${NC} $1"; }
warn() { echo -e "${YELLOW}⚠${NC} $1"; }
error() { echo -e "${RED}✗${NC} $1" >&2; }
```

### 必须包含：

- `-h` 或 `--help` 参数
- 危险操作的用户确认
- 清晰的错误信息

## 参考示例

参考现有 skill 结构：

- [git-merge](git-merge/) - 完整的 SKILL.md + scripts 示例

## 验证

使用 skills-ref 验证：

```bash
skills-ref validate ./skill-name
```

## 添加到项目

1. 创建 skill 目录和文件
2. 确保脚本有执行权限：`chmod +x scripts/*.sh`
3. 更新 README.md 的 Skills 表格
4. 运行验证工具检查
