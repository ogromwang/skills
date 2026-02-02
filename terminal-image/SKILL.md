---
name: terminal-image
description: 在终端中显示图片。当用户需要在终端中查看图片时使用此技能。支持多种显示模式（Kitty/iTerm2图形协议、Unicode符号、ASCII艺术），自动检测最佳显示工具。
---

# Terminal Image

在终端中显示图片，解决远程SSH连接或无图形界面环境下查看图片的需求。

## Quick Start

### 基本用法

```bash
# 显示本地图片
display_image.sh /path/to/image.png

# 指定显示尺寸
display_image.sh /path/to/image.png -w 80 -h 25

# 指定显示模式
display_image.sh /path/to/image.png -m kitty
display_image.sh /path/to/image.png -m symbols
```

## Display Modes

### 1. Kitty Graphics Protocol (最高质量)
- 24-bit真彩色，原生分辨率
- 兼容: Kitty, WezTerm
- 命令: `display_image.sh -m kitty`

### 2. iTerm2 Inline Images
- 24-bit真彩色，支持Retina显示
- 兼容: iTerm2
- 命令: `display_image.sh -m iterm`

### 3. Unicode Symbols
- 24-bit Truecolor，字符分辨率
- 兼容: 所有现代终端
- 命令: `display_image.sh -m symbols`

### 4. ASCII Art
- 纯文本，最广泛兼容
- 兼容: 所有终端
- 命令: `display_image.sh -m ascii`

### Auto Mode (默认)
自动检测终端能力并选择最佳显示模式

## Command Reference

| 选项 | 说明 | 示例 |
|------|------|------|
| `-m, --mode MODE` | 显示模式 | `-m kitty/sixel/symbols/ascii` |
| `-w, --width WIDTH` | 显示宽度(字符数) | `-w 80` |
| `-h, --height HEIGHT` | 显示高度(字符数) | `-h 25` |

## Required Tools

至少安装以下工具之一:

```bash
# 推荐 (支持所有模式)
brew install chafa

# 或者 (Kitty/iTerm2 协议)
brew install viu

# 或者 (通用兼容)
brew install jp2a catimg
```

## Examples

```bash
# 显示截图
display_image.sh ~/Downloads/screenshot.png

# 调整尺寸
display_image.sh image.jpg -w 100 -h 30

# 纯ASCII输出
display_image.sh image.png -m ascii
```
