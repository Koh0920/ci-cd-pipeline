#!/bin/bash
set -e # エラーが発生したらスクリプトを終了

# --- 引数の定義 ---
# $1: Template Type (e.g., "react-vite", "react-tailwind-vite", "html", "vanilla")
# $2: User Code Directory (e.g., "./user-code")
# $3: Output Build Directory (e.g., "./build")

TEMPLATE_TYPE="${1}"
USER_CODE_DIR="${2}"
OUTPUT_DIR="${3}"

# --- 引数チェック ---
if [ -z "$TEMPLATE_TYPE" ] || [ -z "$USER_CODE_DIR" ] || [ -z "$OUTPUT_DIR" ]; then
  echo "Usage: $0 <template-type> <user-code-dir> <output-dir>"
  exit 1
fi

# --- テンプレートディレクトリの決定 ---
# ここでは node/ 以下のみを想定。必要に応じて他の言語パスも追加
TEMPLATE_BASE_DIR="./templates/node"
TEMPLATE_DIR="${TEMPLATE_BASE_DIR}/${TEMPLATE_TYPE}"

if [ ! -d "$TEMPLATE_DIR" ]; then
  echo "Error: Template directory not found for type '$TEMPLATE_TYPE' at '$TEMPLATE_DIR'"
  exit 1
fi

echo "Starting merge process for template type: $TEMPLATE_TYPE"
echo "Template Source: $TEMPLATE_DIR"
echo "User Code Source: $USER_CODE_DIR"
echo "Output Directory: $OUTPUT_DIR"

# --- マージ処理 ---
# 出力ディレクトリが既にあれば削除して再作成
if [ -d "$OUTPUT_DIR" ]; then
  echo "Removing existing output directory: $OUTPUT_DIR"
  rm -rf "$OUTPUT_DIR"
fi
echo "Creating output directory: $OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

# テンプレートをコピー (-a はアーカイブモード: パーミッション、タイムスタンプ保持)
echo "Copying template files from $TEMPLATE_DIR to $OUTPUT_DIR..."
cp -a "$TEMPLATE_DIR"/. "$OUTPUT_DIR"/

# ユーザーコードディレクトリが存在する場合のみマージ
if [ -d "$USER_CODE_DIR" ]; then
  # テンプレートタイプに応じてマージ先ディレクトリを決定
  MERGE_TARGET_DIR=""
  case "$TEMPLATE_TYPE" in
    "react-vite" | "react-tailwind-vite")
      # React系テンプレートは src ディレクトリにマージ
      MERGE_TARGET_DIR="${OUTPUT_DIR}/src"
      if [ ! -d "$MERGE_TARGET_DIR" ]; then
        echo "Warning: Merge target directory '$MERGE_TARGET_DIR' does not exist in the template. Creating it."
        mkdir -p "$MERGE_TARGET_DIR"
      fi
      echo "Merging user code from $USER_CODE_DIR into $MERGE_TARGET_DIR (React template)..."
      ;;
    "html" | "vanilla")
      # 静的テンプレートは出力ディレクトリ直下にマージ
      MERGE_TARGET_DIR="${OUTPUT_DIR}"
      echo "Merging user code from $USER_CODE_DIR into $MERGE_TARGET_DIR (Static template)..."
      ;;
    *)
      # 未知のテンプレートタイプの場合はエラーにするか、デフォルトの挙動を決める
      echo "Warning: Unknown template type '$TEMPLATE_TYPE' for user code merge. Defaulting to merge into output root."
      MERGE_TARGET_DIR="${OUTPUT_DIR}"
      ;;
  esac

  # ユーザーコードを決定したマージ先にコピー (上書き)
  # ドットファイルも含めてコピーするために find と cpio を使う (より堅牢)
  # find "$USER_CODE_DIR" -mindepth 1 -maxdepth 1 -print0 | cpio -pdm0 "$MERGE_TARGET_DIR"/
  # または、よりシンプルな cp を使う (ドットファイルは別途コピーが必要な場合がある)
  cp -a "$USER_CODE_DIR"/. "$MERGE_TARGET_DIR"/
  # ドットファイルがコピーされない場合があるので明示的にコピー (例: .env など)
  find "$USER_CODE_DIR" -maxdepth 1 -name '.*' -exec cp -a {} "$MERGE_TARGET_DIR"/ \; 2>/dev/null || true

else
  echo "Warning: User code directory '$USER_CODE_DIR' not found. Skipping user code merge step."
fi

echo "Merge process complete. Merged project is ready in: $OUTPUT_DIR"

ls -R ./user-code

exit 0
