#!/bin/bash
set -e

# 定義：テンプレート、ユーザーコード、出力ディレクトリ
TEMPLATE_DIR="./template"
USER_CODE_DIR="./user-code"
OUTPUT_DIR="./build"

echo "Starting merge process..."

# 既存の出力ディレクトリがあれば削除
if [ -d "$OUTPUT_DIR" ]; then
  echo "Removing existing output directory: $OUTPUT_DIR"
  rm -rf "$OUTPUT_DIR"
fi

# テンプレートディレクトリの内容を出力ディレクトリにコピー
echo "Copying template files..."
cp -r "$TEMPLATE_DIR" "$OUTPUT_DIR"

# ユーザーコードディレクトリが存在する場合、テンプレートのsrcに上書きコピー
if [ -d "$USER_CODE_DIR" ]; then
  echo "Merging user code into $OUTPUT_DIR/src..."
  cp -r "$USER_CODE_DIR"/* "$OUTPUT_DIR/src/"
else
  echo "No user code found in $USER_CODE_DIR. Skipping merge step."
fi

echo "Merge process complete. Merged files are in: $OUTPUT_DIR"
