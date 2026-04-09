import { defineConfig } from 'vite'

export default defineConfig({
  base: './',
  build: {
    target: 'esnext',
    outDir: '../Resources/MonacoEditor',
    emptyOutDir: true
  },
  worker: {
    format: 'es'
  },
  plugins: [{
    // REQUIRED: VS Code CSS modules use constructable stylesheets.
    // WKWebView may handle these differently. This plugin forces
    // CSS from @codingame/monaco-vscode-* to be inlined as strings.
    name: 'load-vscode-css-as-string',
    enforce: 'pre',
    async resolveId(source, importer, options) {
      if (!source.endsWith('.css') || source.endsWith('?inline')) return
      const resolved = await this.resolve(source, importer, { ...options, skipSelf: true })
      if (resolved?.id.match(
        /node_modules\/(@codingame\/monaco-vscode|vscode|monaco-editor).*\.css$/
      )) {
        return { ...resolved, id: resolved.id + '?inline' }
      }
    }
  }]
})
