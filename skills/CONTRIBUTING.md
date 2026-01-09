# 贡献指南

感谢您有兴趣为本项目贡献新的 Claude Skills！

## 如何贡献

### 1. 确认使用场景

确保您的 skill 基于真实的使用需求，避免重复造轮子。

### 2. 检查现有 Skills

查看现有目录，避免与已有 skill 功能重复。

### 3. 遵循项目结构

```
skill-name/
├── SKILL.md              # 必需
├── scripts/              # 可选
│   └── *.sh
├── templates/            # 可选
└── resources/            # 可选
```

### 4. 编写 SKILL.md

参考 [README.md](README.md) 中的模板，确保包含：

- YAML frontmatter（name, description）
- 使用场景说明（When to Use）
- 详细指令
- 示例
- 注意事项

### 5. 测试您的 Skill

在 Claude Code 中测试，确保：
- 正确识别触发场景
- 脚本无错误
- 输出信息清晰

### 6. 提交 PR

1. 创建新分支
2. 添加您的 skill
3. 更新 README.md 的 Skills 表格
4. 提交并描述您的更改

## Skill 质量标准

- ✅ 专注于单一、可重复的任务
- ✅ 包含清晰的触发条件说明
- ✅ 指令面向 Claude（而非终端用户）
- ✅ 脚本使用 `set -e` 处理错误
- ✅ 提供有颜色的进度输出
- ✅ 包含边界情况处理

## 建议

- 从简单的脚本开始
- 优先解决高频痛点
- 参考 [awesome-claude-skills](https://github.com/ComposioHQ/awesome-claude-skills) 获取灵感
