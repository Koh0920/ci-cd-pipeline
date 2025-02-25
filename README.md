# CI/CD Pipeline Repository

このリポジトリは、ユーザー投稿コードと固定テンプレート（React + Vite）を合成し、ビルド・デプロイを自動化するためのCI/CDパイプラインの実装を目的としています。

## ディレクトリ構成

- **template/**: React + Vite の基本テンプレート
- **merge-template.sh**: ユーザー投稿コードとテンプレートを合成するスクリプト
- （今後、GitHub Actionsのワークフロー定義などを追加予定）

## 使い方

1. ユーザー投稿コードは `user-code/` ディレクトリに配置（例: APIから取得して出力）
2. `merge-template.sh` を実行すると、テンプレートとユーザーコードが合成され、`build/` ディレクトリに結果が出力されます。

