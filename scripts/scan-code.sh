#!/bin/bash
set -e # エラーが発生したらスクリプトを終了 (ただし、grep が見つからない場合は 1 を返すので注意)

# --- 引数の定義 ---
# $1: Scan Target Directory (e.g., "./user-code")

TARGET_DIR="${1}"
SCAN_FAILED=0 # 0: Success, 1: Failed

# --- 引数チェック ---
if [ -z "$TARGET_DIR" ] || [ ! -d "$TARGET_DIR" ]; then
  echo "Usage: $0 <scan-target-dir>"
  echo "Error: Target directory '$TARGET_DIR' not found or not specified."
  exit 1
fi

echo "Starting code scan in directory: $TARGET_DIR"

# --- スキャン処理 ---

# ホワイトリストファイルのパス (スクリプトからの相対パス)
# ワークフローの実行ディレクトリはリポジトリルートなので、そこからのパスで指定
WHITELIST_FILE="./templates/node/whitelist.json"

# Node.js 組み込みモジュールリスト (主要なもの)
# 必要に応じて追加・削除してください
NODE_BUILTINS="fs path os http https url querystring stream util child_process crypto zlib events assert buffer process vm net tls dgram dns readline repl cluster domain punycode string_decoder tty"

echo "Checking for non-whitelisted or Node.js built-in module imports..."

# ホワイトリストを読み込む
if [ ! -f "$WHITELIST_FILE" ]; then
  echo "Error: Whitelist file not found at '$WHITELIST_FILE'"
  exit 1
fi
WHITELIST_MODULES=$(jq -r 'keys_unsorted | .[]' "$WHITELIST_FILE")
if [ $? -ne 0 ]; then
  echo "Error: Failed to parse whitelist file '$WHITELIST_FILE' with jq."
  exit 1
fi
echo "Whitelist loaded successfully."

# find と grep で import/require を抽出 (より多くのパターンに対応)
# - js/jsx/ts/tsx ファイルを対象
# - import ... from '...'
# - import '...'
# - import(...)
# - require(...)
# - export ... from '...'
find "$TARGET_DIR" -type f \( -name "*.js" -o -name "*.jsx" -o -name "*.ts" -o -name "*.tsx" \) -print0 | \
  xargs -0 grep -Eo \
  -e 'import\s+.*\s+from\s+["'\'']([^"'\'']+)["'\'']' \
  -e 'import\s+["'\'']([^"'\'']+)["'\'']' \
  -e 'import\(([^)]+)\)' \
  -e 'require\(([^)]+)\)' \
  -e 'export\s+.*\s+from\s+["'\'']([^"'\'']+)["'\'']' \
  > raw_imports.txt || true # 見つからなくてもエラーにしない

# 抽出したモジュール名を整形
# - import('module') や require('module') の括弧や引用符を除去
# - import ... from 'module' や export ... from 'module' からモジュール名のみ抽出
# - import 'module' からモジュール名のみ抽出
sed -E \
  -e 's/.*from[[:space:]]*["'\'']([^"'\'']+)["'\'']/\1/' \
  -e 's/import[[:space:]]*["'\'']([^"'\'']+)["'\'']/\1/' \
  -e 's/.*import\(([^)]+)\).*/\1/' \
  -e 's/.*require\(([^)]+)\).*/\1/' \
  -e 's/.*export[[:space:]]+.*[[:space:]]+from[[:space:]]*["'\'']([^"'\'']+)["'\'']/\1/' \
  -e 's/["'\'']//g' \
  raw_imports.txt | sort -u > found_modules.txt

rm raw_imports.txt

# 各モジュールをチェック
echo "Analyzing found modules..."
while IFS= read -r module; do
  # 空行やトリム後の空文字列はスキップ
  module=$(echo "$module" | xargs) # 前後の空白を除去
  [ -z "$module" ] && continue

  # 相対パス/絶対パスはOK
  if [[ "$module" == \.* ]] || [[ "$module" == \/* ]]; then
    # echo "  [OK] Local module: $module"
    continue
  fi

  # Node.js 組み込みモジュールはNG
  # Note: `node:` プレフィックスも考慮 (推奨されるインポート方法)
  module_name_no_prefix=$(echo "$module" | sed 's/^node://')
  if echo "$NODE_BUILTINS" | grep -qw "$module_name_no_prefix"; then
    echo "--------------------------------------------------"
    echo "Error: Node.js built-in module import detected: '$module'"
    echo "Node.js modules are not allowed in user code."
    echo "--------------------------------------------------"
    SCAN_FAILED=1
    continue # 他のエラーも検出するためループは続ける
  fi

  # ホワイトリストに含まれているかチェック
  # サブパス (例: 'react-dom/client') も考慮するため、前方一致でチェック
  IS_WHITELISTED=0
  while IFS= read -r whitelist_entry; do
    if [[ "$module" == "$whitelist_entry" ]] || [[ "$module" == "$whitelist_entry"/* ]]; then
      # echo "  [OK] Whitelisted module/subpath: $module (matches: $whitelist_entry)"
      IS_WHITELISTED=1
      break
    fi
  done <<< "$WHITELIST_MODULES"

  if [ "$IS_WHITELISTED" -eq 1 ]; then
    continue
  fi

  # 上記以外 (ホワイトリストにない外部モジュール) はNG
  echo "--------------------------------------------------"
  echo "Error: Non-whitelisted external module import detected: '$module'"
  echo "Only modules listed in the whitelist are allowed."
  echo "Allowed modules:"
  echo "$WHITELIST_MODULES" | sed 's/^/  - /'
  echo "--------------------------------------------------"
  SCAN_FAILED=1

done < found_modules.txt

rm found_modules.txt

if [ "$SCAN_FAILED" -eq 0 ]; then
    echo "Module import check passed."
fi

# 例1: 危険な可能性のある関数呼び出しを検出 (eval, Function constructor, setTimeout with string)
echo "Checking for potentially dangerous function calls..."
# find で対象ファイルを探し、grep でパターンマッチ
# -r: recursive, -n: line number, -I: ignore binary files, -E: extended regex
# || true を付けて grep が何も見つけなくてもスクリプトが終了しないようにする
DANGEROUS_CALLS=$(find "$TARGET_DIR" -type f \( -name "*.js" -o -name "*.jsx" -o -name "*.ts" -o -name "*.tsx" -o -name "*.html" \) -print0 | xargs -0 grep -nIE 'eval\(|new Function\(|setTimeout\s*\(\s*["'\'']' ) || true
if [ -n "$DANGEROUS_CALLS" ]; then
  echo "--------------------------------------------------"
  echo "Warning: Potentially dangerous function calls found:"
  echo "$DANGEROUS_CALLS"
  echo "--------------------------------------------------"
  # ポリシーに基づき、エラーとして扱う
  # 危険な関数呼び出しも引き続きエラーとして扱う
  SCAN_FAILED=1
fi

# 例2: 特定の機密情報パターンを検出 (簡易的な例)
echo "Checking for potential secrets (basic)..."
# AWS Key, Private Key header など
SECRETS=$(find "$TARGET_DIR" -type f -print0 | xargs -0 grep -nIE 'AKIA[0-9A-Z]{16}|-----BEGIN (RSA|OPENSSH|EC) PRIVATE KEY-----' ) || true
if [ -n "$SECRETS" ]; then
  echo "--------------------------------------------------"
  echo "Error: Potential secrets found in code:"
  echo "$SECRETS"
  echo "--------------------------------------------------"
  SCAN_FAILED=1 # これは明確にエラー
fi

# 例3: 外部への HTTP/HTTPS リクエストを探す (情報収集目的)
# echo "Checking for external HTTP(S) requests..."
# REQUESTS=$(find "$TARGET_DIR" -type f \( -name "*.js" -o -name "*.jsx" -o -name "*.ts" -o -name "*.tsx" \) -print0 | xargs -0 grep -nE 'fetch\s*\(\s*["'\''](http|https):' ) || true
# if [ -n "$REQUESTS" ]; then
#   echo "--------------------------------------------------"
#   echo "Info: External requests found:"
#   echo "$REQUESTS"
#   echo "--------------------------------------------------"
# fi

# --- 他のチェックを追加 ---
# 例: ESLint の実行 (事前に設定が必要)
# if [ -f "$TARGET_DIR/../.eslintrc.js" ]; then # .eslintrc.js がbuildディレクトリにある場合など
#   echo "Running ESLint..."
#   npx eslint "$TARGET_DIR" --quiet || SCAN_FAILED=1 # ESLint エラーがあれば失敗
# fi

# --- 最終結果 ---
if [ "$SCAN_FAILED" -eq 1 ]; then
  echo "Code scan finished: Issues found (marked as Error)."
  exit 1 # 問題が見つかったので非ゼロで終了
else
  echo "Code scan finished: No critical issues found."
  exit 0 # 問題なし
fi
