import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
import fs from "fs"; // Node.js fs モジュールをインポート
import path from "path"; // Node.js path モジュールをインポート

// ホワイトリストファイルを読み込む関数
function loadWhitelist() {
  try {
    // スクリプトの実行場所からの相対パスで whitelist.json を見つける
    // 通常、vite.config.js はプロジェクトルートにあるので、そこからの相対パス
    const whitelistPath = path.resolve(__dirname, "../whitelist.json");
    const whitelistContent = fs.readFileSync(whitelistPath, "utf-8");
    const whitelist = JSON.parse(whitelistContent);
    // キー (モジュール名) のリストを返す
    return Object.keys(whitelist);
  } catch (error) {
    console.error("Error loading whitelist.json:", error);
    // エラーが発生した場合は空のリストを返し、ビルドは続行するが external は設定されない
    // または、ここでビルドを失敗させることも検討できる
    // throw new Error('Failed to load whitelist.json for build configuration.');
    return [];
  }
}

const whitelistedModules = loadWhitelist();
console.log("Whitelisted modules (external):", whitelistedModules);

// https://vite.dev/config/
export default defineConfig({
  plugins: [react()],
  base: "./", // 生成されるアセットへのパスを相対パスにする
  build: {
    rollupOptions: {
      // ホワイトリストに含まれるモジュールを外部依存として扱う
      external: whitelistedModules,
      output: {
        // 外部依存のグローバル変数名を指定する場合 (通常 Import Map を使う場合は不要)
        // globals: {
        //   'react': 'React',
        //   'react-dom': 'ReactDOM',
        //   // ... 他のホワイトリストモジュール
        // }
      },
    },
  },
});
