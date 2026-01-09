# 🧠 Claude Skills Collection  
### *Your Personal Toolkit for Claude Code — Extend, Automate, and Accelerate*

[![Stars](https://img.shields.io/github/stars/ogromwang/skills?style=social)](https://github.com/ogromwang/skills)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

> 💡 个人 Claude Code 技能集合，持续收集和开发各种实用的 Claude Skills。

---

## 🔍 什么是 Claude Skills？

Claude Skills 是一个包含 `SKILL.md` 文件的文件夹，该文件包含元数据（`name` 和 `description`）和告诉 agent 如何执行特定任务的指令。Skills 还可以包含脚本、模板和参考资料。

> 📚 参考: [Agent Skills Specification](https://agentskills.io/specification)

---

## 🗂️ 标准结构

```
skill-name/
├── SKILL.md          # 必需：指令 + 元数据
├── scripts/          # 可选：可执行代码
├── references/       # 可选：文档资料
└── assets/           # 可选：模板、资源
```

### 🌐 Progressive Disclosure（渐进式披露）

Skills 使用渐进式披露来高效管理上下文：

1. **发现（Discovery）**: 启动时，agent 只加载每个 skill 的 `name` 和 `description`  
2. **激活（Activation）**: 当任务匹配 skill 的 description 时，agent 将完整的 `SKILL.md` 读入上下文  
3. **执行（Execution）**: agent 遵循指令，根据需要加载引用文件或执行捆绑的代码  

---

## 📁 Skills 目录

| Skill | 描述 | 状态 |
|-------|------|------|
| [git-merge](#git-merge) | 安全地将当前分支合并到目标分支，并自动返回原分支 | ✅ 已完成 |

---

## 📖 添加新 Skill

参考 [AGENTS.md](AGENTS.md) 了解完整的开发规范。

### ⚡ 快速结构

```
new-skill/
├── SKILL.md              # 必需
├── scripts/              # 可选
│   └── *.sh
├── references/           # 可选
└── assets/               # 可选
```

### ✅ 核心要点

- `SKILL.md` 必须包含 `name` 和 `description` 的 YAML frontmatter  
- `name` 使用小写字母 + 连字符（如 `pdf-extract`）  
- `description` 应包含触发关键词（如 “PDF”、“合并”、“提取表格”）  
- 脚本建议使用 `set -e` 并支持彩色输出，提升可读性与健壮性  

---

## 📝 更新日志

- **2026-01-09**: 初始化项目，添加 `git-merge` skill

---

## 🤝 Contributing

欢迎贡献！如果你有新的技能想法、改进脚本，或发现了 bug，请随时提交 Issue 或 Pull Request。

<a href="https://github.com/ogromwang/skills/graphs/contributors">
  <img src="https://contrib.rocks/image?repo=ogromwang/skills" />
</a>

🌟 **Star 趋势**：  
[![GitHub stars](https://img.shields.io/github/stars/ogromwang/skills?label=Stars&logo=github)](https://github.com/ogromwang/skills/stargazers)
[![GitHub forks](https://img.shields.io/github/forks/ogromwang/skills?label=Forks&logo=github)](https://github.com/ogromwang/skills/network/members)

---

> 🔜 *更多技能正在路上……你的 star 是我持续更新的最大动力！*
