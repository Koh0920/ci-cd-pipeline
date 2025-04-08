#!/bin/bash
set -e # エラーが発生したらスクリプトを終了

# --- 引数の定義 ---
# $1: Check Target Directory (e.g., "./build/dist" or "./user-code")
# $2: Max Size in Bytes (e.g., 8388608 for 8MB)

TARGET_DIR="${1}"
MAX_SIZE_BYTES="${2}"

# --- 引数チェック ---
if [ -z "$TARGET_DIR" ] || [ ! -d "$TARGET_DIR" ]; then
  echo "Usage: $0 <target-dir> <max-size-bytes>"
  echo "Error: Target directory '$TARGET_DIR' not found or not specified."
  exit 1
fi

if ! [[ "$MAX_SIZE_BYTES" =~ ^[0-9]+$ ]]; then
  echo "Usage: $0 <target-dir> <max-size-bytes>"
  echo "Error: Max size '$MAX_SIZE_BYTES' is not a valid integer."
  exit 1
fi

echo "Starting size check for directory: $TARGET_DIR"
echo "Max allowed size: $MAX_SIZE_BYTES bytes"

# --- サイズチェック ---
# du -sb: ディレクトリの合計サイズをバイト単位で表示 (-s: 合計, -b: バイト)
ACTUAL_SIZE_BYTES=$(du -sb "$TARGET_DIR" | cut -f1)

if [ -z "$ACTUAL_SIZE_BYTES" ]; then
  echo "Error: Could not determine the size of directory '$TARGET_DIR'."
  exit 1
fi

echo "Actual directory size: $ACTUAL_SIZE_BYTES bytes"

# --- 比較と結果判定 ---
if [[ "$ACTUAL_SIZE_BYTES" -gt "$MAX_SIZE_BYTES" ]]; then
  # サイズ超過
  # 人間が読みやすい形式でも表示 (例: MB)
  MAX_SIZE_MB=$(echo "scale=2; $MAX_SIZE_BYTES / 1024 / 1024" | bc)
  ACTUAL_SIZE_MB=$(echo "scale=2; $ACTUAL_SIZE_BYTES / 1024 / 1024" | bc)
  echo "--------------------------------------------------"
  echo "Error: Artifact size limit exceeded!"
  echo "  Actual size: $ACTUAL_SIZE_BYTES bytes (~${ACTUAL_SIZE_MB} MB)"
  echo "  Limit:       $MAX_SIZE_BYTES bytes (~${MAX_SIZE_MB} MB)"
  echo "--------------------------------------------------"
  exit 1 # 非ゼロで終了
else
  # 制限内
  echo "Artifact size is within the limit."
  exit 0 # ゼロで終了
fi
