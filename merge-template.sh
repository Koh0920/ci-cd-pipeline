#!/bin/bash
set -e

# ディレクトリ定義を実際の場所に合わせる
TEMPLATE_DIR="./templates/react-vite"
USER_CODE_DIR="./user-code"
OUTPUT_DIR="./build"

echo "Starting merge process..."

# 出力ディレクトリが既にあれば削除
if [ -d "$OUTPUT_DIR" ]; then
  echo "Removing existing output directory: $OUTPUT_DIR"
  rm -rf "$OUTPUT_DIR"
fi

# テンプレートをコピー
echo "Copying template files..."
mkdir -p "$OUTPUT_DIR"
cp -r "$TEMPLATE_DIR"/. "$OUTPUT_DIR"/

# ユーザーコードを ./build/src に上書きコピー
if [ -d "$USER_CODE_DIR" ]; then
  echo "Merging user code into $OUTPUT_DIR/src..."
  cp -r "$USER_CODE_DIR"/* "$OUTPUT_DIR/src/"
else
  echo "No user code found in $USER_CODE_DIR. Skipping merge step."
fi

echo "Merge process complete. Merged files are in: $OUTPUT_DIR"
