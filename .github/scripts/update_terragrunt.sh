#!/bin/bash

set -e

# 参数检查
if [ $# -ne 2 ]; then
    echo "Usage: $0 <json_params> <terragrunt_file>"
    exit 1
fi

JSON_PARAMS="$1"
TERRAGRUNT_FILE="$2"

echo "Updating $TERRAGRUNT_FILE with JSON parameters..."

# 创建临时文件
TEMP_FILE=$(mktemp)
BACKUP_FILE="${TERRAGRUNT_FILE}.backup.$(date +%Y%m%d_%H%M%S)"

# 备份原文件
cp "$TERRAGRUNT_FILE" "$BACKUP_FILE"
echo "Backup created: $BACKUP_FILE"

# 改进的 jq 命令生成 HCL 内容
generate_hcl_from_json() {
    local json_params="$1"
    
    echo "$json_params" | jq -r '
    def process_value:
        if type == "object" then
            "{\n" + (to_entries | map("  \"\(.key)\" = \(.value | process_value)") | join("\n")) + "\n}"
        elif type == "array" then
            if length == 0 then "[]"
            elif .[0] | type == "object" then
                "[\n" + (map("{ " + (to_entries | map("\"\(.key)\" = \(.value | process_value)") | join(", ")) + " }") | join(",\n")) + "\n]"
            else
                "[ " + (map(if type == "string" then "\"\(.)\"" else . end) | join(", ")) + " ]"
            end
        elif type == "string" then "\"\(.)\""
        else .
        end;
    
    to_entries | map("\(.key) = \(.value | process_value)") | .[]
    '
}

# 生成新的 inputs 内容
HCL_CONTENT=$(generate_hcl_from_json "$JSON_PARAMS")

if [ $? -ne 0 ] || [ -z "$HCL_CONTENT" ]; then
    echo "Error: Failed to generate HCL content from JSON"
    exit 1
fi

echo "Generated HCL content:"
echo "$HCL_CONTENT"

# 使用改进的 awk 替换或添加 inputs 块
awk -v hcl_content="$HCL_CONTENT" '
BEGIN {
    # 将多行 HCL 内容转换为数组
    split(hcl_content, lines, "\n")
    in_inputs = 0
    inputs_depth = 0
    found_inputs = 0
    skip_original_inputs = 0
}

# 匹配 inputs 块开始
/^inputs[[:space:]]*=[[:space:]]*\{/ {
    if (!in_inputs) {
        in_inputs = 1
        inputs_depth = 1
        found_inputs = 1
        skip_original_inputs = 1
        
        # 打印新的 inputs 块开始
        print "inputs = {"
        # 输出新的 HCL 内容，每行缩进两个空格
        for (i in lines) {
            if (lines[i] != "") {
                print "  " lines[i]
            }
        }
        # 打印闭合大括号
        print "}"
        next
    }
}

# 在 inputs 块内（跳过原始内容）
skip_original_inputs && in_inputs {
    # 计算大括号深度
    if (/\{/) {
        inputs_depth++
    }
    if (/\}/) {
        inputs_depth--
        # 如果深度为0，说明 inputs 块结束
        if (inputs_depth == 0) {
            in_inputs = 0
            skip_original_inputs = 0
        }
    }
    # 跳过原始 inputs 块内的所有内容
    next
}

# 不在 inputs 块内的内容直接打印
{
    print
}

END {
    # 如果没有找到现有的 inputs 块，在文件末尾添加
    if (!found_inputs) {
        print ""
        print "inputs = {"
        for (i in lines) {
            if (lines[i] != "") {
                print "  " lines[i]
            }
        }
        print "}"
    }
}
' "$TERRAGRUNT_FILE" > "$TEMP_FILE"

# 检查 awk 命令是否成功
if [ $? -ne 0 ]; then
    echo "Error: Failed to update terragrunt.hcl"
    rm -f "$TEMP_FILE"
    exit 1
fi

# 替换原文件
mv "$TEMP_FILE" "$TERRAGRUNT_FILE"

echo "Update completed successfully!"
echo "Updated terragrunt.hcl content:"
cat "$TERRAGRUNT_FILE"

# 验证文件语法
echo "Validating terragrunt.hcl syntax..."
TERRAGRUNT_DIR=$(dirname "$TERRAGRUNT_FILE")
TERRAGRUNT_FILE_NAME=$(basename "$TERRAGRUNT_FILE")

# 切换到正确的目录
if [ -n "$TERRAGRUNT_DIR" ] && [ "$TERRAGRUNT_DIR" != "." ]; then
    cd "$TERRAGRUNT_DIR"
fi

if command -v terragrunt &> /dev/null; then
    # 先格式化文件
    terragrunt hcl format "$TERRAGRUNT_FILE_NAME"
    # 然后检查语法
    terragrunt hcl format --check "$TERRAGRUNT_FILE_NAME" && echo "Syntax validation passed!" || echo "Syntax validation failed!"
else
    echo "Terragrunt not available for syntax validation"
fi
