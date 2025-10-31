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

# 使用增强的 jq 命令生成 HCL 内容
generate_hcl_from_json() {
    local json_params="$1"
    
    echo "$json_params" | jq -r 'to_entries | map(
        if .value | type == "object" then
        "\(.key) = {\n" +
        (.value | to_entries | map("  \"\(.key)\" = \"\(.value)\"") | join("\n")) +
        "\n}"
        elif .value | type == "array" then
        if .value[0] | type == "object" then
        "\(.key) = [\n" +
        (.value | map(
        "{ " +
        (. | to_entries | map("\"\(.key)\" = \"\(.value)\"") | join(", ")) +
        " }"
        ) | join(",\n")) +
        "\n]"
        else
        "\(.key)=\(.value | @json)"
        end
        else
        "\(.key)=\(if .value | type == "string" then "\"\(.value)\"" else .value | @json end)"
        end
    ) | .[]'
}

# 生成新的 inputs 内容
HCL_CONTENT=$(generate_hcl_from_json "$JSON_PARAMS")

if [ $? -ne 0 ] || [ -z "$HCL_CONTENT" ]; then
    echo "Error: Failed to generate HCL content from JSON"
    exit 1
fi

echo "Generated HCL content:"
echo "$HCL_CONTENT"

# 使用 awk 替换或添加 inputs 块
awk -v hcl_content="$HCL_CONTENT" '
BEGIN {
    # 将多行 HCL 内容转换为数组
    split(hcl_content, lines, "\n")
    in_inputs = 0
    inputs_depth = 0
    found_inputs = 0
    output_done = 0
}

/^inputs = \{/ {
    in_inputs = 1
    inputs_depth = 1
    # 开始输出新的 inputs 块
    print "inputs = {"
    # 输出生成的 HCL 内容
    for (i in lines) {
        print lines[i]
    }
    found_inputs = 1
    next
}

in_inputs && /\{/ {
    inputs_depth++
    next
}

in_inputs && /\}/ {
    inputs_depth--
    if (inputs_depth == 0) {
        in_inputs = 0
        # 确保在 inputs 块结束后继续处理其他内容
        if (!output_done) {
            print "}"
            output_done = 1
        }
    }
    next
}

!in_inputs {
    if (!found_inputs && !output_done) {
        # 如果没有找到现有的 inputs 块，在文件末尾添加
        if (FNR == 1) {
            # 如果是文件开始，先输出文件内容
            print
        } else {
            # 保存当前行，等处理完再决定
            buffer[FNR] = $0
        }
    } else {
        print
    }
}

END {
    if (!found_inputs) {
        # 在文件末尾添加新的 inputs 块
        print ""
        print "inputs = {"
        for (i in lines) {
            print lines[i]
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
cd "$(dirname "$TERRAGRUNT_FILE")"
if command -v terragrunt &> /dev/null; then
    terragrunt hcl format --check "$(basename "$TERRAGRUNT_FILE")" && echo "Syntax validation passed!" || echo "Syntax validation failed!"
fi
