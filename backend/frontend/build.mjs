import { build } from "esbuild";
import { copyFile } from "node:fs/promises";

// Fixed asset names match the API's explicit static-file allowlist.
await build({
  entryPoints: ["src/main.tsx"],
  bundle: true,
  minify: true,
  sourcemap: false,
  target: ["es2022"],
  format: "esm",
  outfile: "../key_service/web/app.js",
  legalComments: "inline",
  define: { "process.env.NODE_ENV": '"production"' },
});
await build({
  entryPoints: ["src/theme-init.ts"],
  bundle: true,
  minify: true,
  target: ["es2022"],
  format: "iife",
  outfile: "../key_service/web/theme.js",
});
await Promise.all([
  copyFile("src/style.css", "../key_service/web/style.css"),
  copyFile("index.html", "../key_service/web/index.html"),
  copyFile("icon.svg", "../key_service/web/icon.svg"),
]);
