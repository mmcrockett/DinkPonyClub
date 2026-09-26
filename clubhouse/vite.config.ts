import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
import { fileURLToPath } from "node:url";
export default defineConfig({
  plugins: [react()],
  resolve: { alias: { "@": fileURLToPath(new URL(".", import.meta.url)) } },
  build: {
    outDir: "../public/clubhouse-assets",
    emptyOutDir: true,
    rollupOptions: {
      input: "main.tsx",
      output: {
        entryFileNames: "clubhouse.js",
        assetFileNames: "clubhouse.[ext]",
      },
    },
  },
});
