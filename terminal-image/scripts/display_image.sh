#!/bin/bash
# Terminal Image Display - 在终端中显示图片
# 用法：display_image.sh <图片路径> [选项]

set -e

# 默认配置
DISPLAY_MODE="auto"
RESIZE_WIDTH=""
RESIZE_HEIGHT=""
INPUT_FILE=""

# 显示帮助信息
show_help() {
    cat << EOF
用法: $(basename "$0") <图片路径> [选项]

参数:
    图片路径              要显示的图片文件路径 (支持 png, jpg, jpeg, gif, webp)

选项:
    -m, --mode MODE       显示模式 (auto|kitty|iterm|sixel|symbols|ascii)
    -w, --width WIDTH     显示宽度 (字符数)
    -h, --height HEIGHT   显示高度 (字符数)
    -H, --help            显示此帮助信息

示例:
    # 显示图片（自动选择最佳模式）
    $(basename "$0") ~/Downloads/screenshot.png

    # 指定显示模式
    $(basename "$0") image.jpg -m kitty
    $(basename "$0") image.jpg -m symbols
    $(basename "$0") image.jpg -m ascii

    # 调整显示尺寸
    $(basename "$0") image.png -w 100 -h 30

显示模式说明:
    auto    - 自动检测终端能力并选择最佳模式 (默认)
    kitty   - Kitty 图形协议 (24-bit真彩色，需要 Kitty/WezTerm 终端)
    iterm   - iTerm2 内联图像协议 (24-bit真彩色，需要 iTerm2)
    sixel   - Sixel 图形协议 (256色，需要 xterm/foot/iTerm2)
    symbols - Unicode 符号字符 (24-bit真彩色，兼容所有现代终端)
    ascii   - ASCII 艺术 (纯文本，兼容所有终端)

EOF
}

# 解析命令行参数
while [[ $# -gt 0 ]]; do
    case $1 in
        # 图片文件参数（支持多种格式）
        *.png|*.jpg|*.jpeg|*.gif|*.webp|*.PNG|*.JPG|*.JPEG|*.GIF|*.WEBP)
            INPUT_FILE="$1"
            shift
            ;;
        -m|--mode)
            DISPLAY_MODE="$2"
            shift 2
            ;;
        -w|--width)
            RESIZE_WIDTH="$2"
            shift 2
            ;;
        -h|--height)
            RESIZE_HEIGHT="$2"
            shift 2
            ;;
        -H|--help)
            show_help
            exit 0
            ;;
        *)
            # 如果是第一个参数且不是选项，当作文件路径处理
            if [[ -z "$INPUT_FILE" && ! "$1" =~ ^- ]]; then
                INPUT_FILE="$1"
                shift
            else
                echo "错误: 未知参数 '$1'"
                show_help
                exit 1
            fi
            ;;
    esac
done

# 检查是否提供了图片文件
if [[ -z "$INPUT_FILE" ]]; then
    echo "错误: 请提供图片文件路径"
    echo ""
    show_help
    exit 1
fi

# 检查文件是否存在
if [[ ! -f "$INPUT_FILE" ]]; then
    echo "错误: 图片文件不存在: $INPUT_FILE"
    exit 1
fi

# 检测所有可用的显示工具
detect_available_tools() {
    local tools=()
    command -v chafa &> /dev/null && tools+=("chafa")
    command -v viu &> /dev/null && tools+=("viu")
    command -v timg &> /dev/null && tools+=("timg")
    command -v catimg &> /dev/null && tools+=("catimg")
    command -v jp2a &> /dev/null && tools+=("jp2a")
    command -v img2txt &> /dev/null && tools+=("img2txt")
    echo "${tools[@]}"
}

# 检测终端支持的图形协议
detect_terminal_protocol() {
    # Kitty 终端
    if [[ -n "$KITTY_WINDOW_ID" ]]; then
        echo "kitty"
    # iTerm2
    elif [[ "$TERM_PROGRAM" == "iTerm.app" ]]; then
        echo "iterm"
    # WezTerm
    elif [[ -n "$WEZTERM_EXECUTABLE" ]]; then
        echo "kitty"
    # 支持 Sixel 的终端
    elif [[ "$TERM" == *"xterm"* ]] || [[ "$TERM" == *"sixel"* ]]; then
        echo "sixel"
    # 其他终端使用 Unicode
    else
        echo "symbols"
    fi
}

# 根据终端能力和可用工具选择最佳工具
select_best_tool() {
    local available_tools=($(detect_available_tools))

    if [[ ${#available_tools[@]} -eq 0 ]]; then
        echo ""
        return
    fi

    local protocol
    protocol=$(detect_terminal_protocol)

    # 如果用户指定了显示模式
    if [[ "$DISPLAY_MODE" != "auto" ]]; then
        case "$DISPLAY_MODE" in
            kitty|iterm|sixel)
                if [[ " ${available_tools[*]} " =~ " chafa " ]]; then
                    echo "chafa"
                elif [[ " ${available_tools[*]} " =~ " timg " ]]; then
                    echo "timg"
                elif [[ " ${available_tools[*]} " =~ " viu " ]]; then
                    echo "viu"
                else
                    echo "${available_tools[0]}"
                fi
                ;;
            symbols|ascii)
                # 优先选择支持 ASCII/symbols 的工具
                if [[ " ${available_tools[*]} " =~ " chafa " ]]; then
                    echo "chafa"
                elif [[ " ${available_tools[*]} " =~ " jp2a " ]]; then
                    echo "jp2a"
                elif [[ " ${available_tools[*]} " =~ " img2txt " ]]; then
                    echo "img2txt"
                elif [[ " ${available_tools[*]} " =~ " viu " ]]; then
                    # viu 不支持纯 ASCII，降级使用
                    echo "viu"
                else
                    echo "${available_tools[0]}"
                fi
                ;;
        esac
        return
    fi

    # auto 模式：根据终端协议选择最佳工具
    case "$protocol" in
        kitty|iterm)
            if [[ " ${available_tools[*]} " =~ " chafa " ]]; then
                echo "chafa"
            elif [[ " ${available_tools[*]} " =~ " viu " ]]; then
                echo "viu"
            elif [[ " ${available_tools[*]} " =~ " timg " ]]; then
                echo "timg"
            else
                echo "${available_tools[0]}"
            fi
            ;;
        sixel)
            if [[ " ${available_tools[*]} " =~ " chafa " ]]; then
                echo "chafa"
            elif [[ " ${available_tools[*]} " =~ " timg " ]]; then
                echo "timg"
            else
                echo "${available_tools[0]}"
            fi
            ;;
        *)
            echo "${available_tools[0]}"
            ;;
    esac
}

# 显示图像
display_image() {
    local image_file="$1"

    # 构建尺寸参数
    local size_args=""
    if [[ -n "$RESIZE_WIDTH" && -n "$RESIZE_HEIGHT" ]]; then
        size_args="--size=${RESIZE_WIDTH}x${RESIZE_HEIGHT}"
    elif [[ -n "$RESIZE_WIDTH" ]]; then
        size_args="--size=${RESIZE_WIDTH}x"
    elif [[ -n "$RESIZE_HEIGHT" ]]; then
        size_args="--size=x${RESIZE_HEIGHT}"
    fi

    # 智能选择工具
    local tool
    tool=$(select_best_tool)

    if [[ -z "$tool" ]]; then
        echo "错误: 未找到可用的终端图像显示工具"
        echo ""
        echo "请安装以下工具之一:"
        echo "  macOS:   brew install chafa viu timg"
        echo "  Ubuntu:  sudo apt install chafa caca-utils timg"
        echo "  Arch:    sudo pacman -S chafa viu timg"
        exit 1
    fi

    # 显示检测到的可用工具
    local available_tools=($(detect_available_tools))
    if [[ ${#available_tools[@]} -gt 1 ]]; then
        echo "检测到可用工具: ${available_tools[*]}"
    fi

    # 根据自动检测结果设置显示模式
    local effective_mode="$DISPLAY_MODE"
    if [[ "$DISPLAY_MODE" == "auto" ]]; then
        effective_mode=$(detect_terminal_protocol)
    fi

    # 检测工具与模式兼容性
    if [[ "$DISPLAY_MODE" == "ascii" && "$tool" == "viu" ]]; then
        echo "⚠️  警告: viu 不支持纯 ASCII 模式，将使用其默认图形模式"
        effective_mode="kitty"  # viu 使用 kitty 协议
    fi

    echo "使用: $tool (模式: $effective_mode)"
    echo ""

    case "$tool" in
        chafa)
            local format_args=""
            case "$effective_mode" in
                kitty)
                    format_args="-f kitty"
                    ;;
                iterm)
                    format_args="-f iterm"
                    ;;
                sixel)
                    format_args="-f sixel"
                    ;;
                symbols)
                    format_args="-f symbols"
                    ;;
                ascii)
                    format_args="-f symbols --symbols ascii -c none"
                    ;;
            esac
            chafa $format_args $size_args "$image_file"
            ;;
        viu)
            local width_args=""
            local height_args=""
            [[ -n "$RESIZE_WIDTH" ]] && width_args="-w $RESIZE_WIDTH"
            [[ -n "$RESIZE_HEIGHT" ]] && height_args="-h $RESIZE_HEIGHT"
            viu $width_args $height_args "$image_file"
            ;;
        timg)
            local mode_args=""
            case "$effective_mode" in
                kitty) mode_args="-g k" ;;
                iterm) mode_args="-g I" ;;
                sixel) mode_args="-g s" ;;
            esac
            timg $mode_args "$image_file"
            ;;
        catimg)
            local resize_args="-r 2"
            [[ -n "$RESIZE_WIDTH" ]] && resize_args="-w $RESIZE_WIDTH"
            catimg $resize_args "$image_file"
            ;;
        jp2a)
            local width_args="--width=80"
            [[ -n "$RESIZE_WIDTH" ]] && width_args="--width=$RESIZE_WIDTH"
            local color_args="--color"
            jp2a $width_args $color_args "$image_file"
            ;;
        img2txt)
            local width_args="-W 80"
            [[ -n "$RESIZE_WIDTH" ]] && width_args="-W $RESIZE_WIDTH"
            local height_args="-H 25"
            [[ -n "$RESIZE_HEIGHT" ]] && height_args="-H $RESIZE_HEIGHT"
            img2txt $width_args $height_args "$image_file"
            ;;
    esac
}

# 主函数
main() {
    echo "🖼️  Terminal Image Display"
    echo "========================"
    echo "文件: $INPUT_FILE"
    echo ""

    display_image "$INPUT_FILE"

    echo ""
    echo "✅ 显示完成"
}

# 执行主函数
main "$@"
