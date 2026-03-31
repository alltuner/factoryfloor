import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

export default defineConfig({
  plugins: [react()],
  base: './',
  build: {
    outDir: 'dist',
    // WKWebView loads from file:// — crossorigin attributes cause CORS failures
    crossOriginLoading: false,
    // Avoid modulepreload which also uses crossorigin
    modulePreload: false,
    rollupOptions: {
      output: {
        // Single file, no code splitting — simpler for WKWebView
        manualChunks: undefined,
      },
    },
  },
});
