import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
import fs from "fs";
import path from "path";
import { fileURLToPath } from "url"; // ES Moduleでパスを取得するために追加

// ES Moduleで現在のディレクトリパスを取得
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// ホワイトリストファイルを読み込む関数
function loadWhitelist() {
  try {
    // vite.config.js が build ディレクトリにコピーされることを想定し、
    // 同じ階層にある whitelist.json を参照する
    const whitelistPath = path.resolve(__dirname, "whitelist.json");
    // ビルド環境では whitelist.json が存在しない可能性があるため、存在チェックを追加
    if (!fs.existsSync(whitelistPath)) {
      console.warn(
        `Whitelist file not found at ${whitelistPath}. Proceeding without external modules.`
      );
      return []; // ホワイトリストが見つからない場合は空を返す
    }
    const whitelistContent = fs.readFileSync(whitelistPath, "utf-8");
    const whitelist = JSON.parse(whitelistContent);
    return Object.keys(whitelist);
  } catch (error) {
    console.error("Error loading or parsing whitelist.json:", error);
    // エラー時もビルドを続行させるため空配列を返す
    return [];
  }
}

const whitelistedModules = loadWhitelist();
// ログ出力を条件付きにする（デバッグ時以外は不要な場合）
if (whitelistedModules.length > 0) {
  console.log("Whitelisted modules (external):", whitelistedModules);
}

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
