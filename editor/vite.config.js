import { defineConfig } from 'vite'
import { resolve } from 'path'

export default defineConfig({
  base: './',
  build: {
    target: 'esnext',
    outDir: '../Resources/MonacoEditor',
    emptyOutDir: true,
    // Disable modulePreload — its wrapper factory destructures dynamic import results
    // incorrectly, breaking modules like _virtual/main that export namespace objects.
    // Preloading is unnecessary for a local bundle served from disk.
    modulePreload: false,
    rollupOptions: {
      input: {
        index: resolve(__dirname, 'index.html'),
        diff: resolve(__dirname, 'diff.html')
      }
    }
  },
  worker: {
    format: 'es'
  },
  plugins: [{
    // WKWebView loads from file:// via loadFileURL. The crossorigin attribute
    // on <link rel="stylesheet"> triggers CORS checks that fail on file:// URLs.
    name: 'strip-crossorigin',
    enforce: 'post',
    transformIndexHtml(html) {
      return html.replace(/ crossorigin/g, '')
    }
  }, {
    // Vite wraps dynamic import() in a factory that destructures named exports.
    // For _virtual/main (which exports { default, main }), Vite incorrectly
    // destructures applyStateStackDiff and INITIAL as top-level exports when
    // they're actually nested under the 'main' namespace. Fix: replace the
    // broken factory with one that returns the raw module, preserving the
    // .then(n => n.main) that correctly extracts the namespace.
    name: 'fix-vscode-textmate-import',
    renderChunk(code) {
      if (!code.includes('applyStateStackDiff')) return
      // Vite wraps dynamic import() in __vitePreload which destructures named exports.
      // For _virtual/main (exports { default, main }), this breaks because
      // applyStateStackDiff/INITIAL are nested under 'main', not top-level.
      // Fix: replace the broken factory with one that returns the raw module.
      const re = /__vitePreload\(\s*async\s*\(\)\s*=>\s*\{\s*const\s*\{[\s\S]*?applyStateStackDiff[\s\S]*?\}\s*=\s*await import\(\s*'([^']+)'\s*\)[\s\S]*?\}[\s\S]*?import\.meta\.url\s*\)/g
      return code.replace(re, 'import(\'$1\')')
    }
  }]
})
