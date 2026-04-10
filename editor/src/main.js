import { initialize, getService } from '@codingame/monaco-vscode-api'
import { IExtensionResourceLoaderService } from '@codingame/monaco-vscode-api/vscode/vs/platform/extensionResourceLoader/common/extensionResourceLoader.service'
import { IConfigurationService } from '@codingame/monaco-vscode-api/vscode/vs/platform/configuration/common/configuration.service'
import { FileAccess } from '@codingame/monaco-vscode-api/vscode/vs/base/common/network'
import getTextmateServiceOverride from '@codingame/monaco-vscode-textmate-service-override'
import getThemeServiceOverride from '@codingame/monaco-vscode-theme-service-override'
import getLanguagesServiceOverride from '@codingame/monaco-vscode-languages-service-override'
import { MenuRegistry, MenuId } from '@codingame/monaco-vscode-api/vscode/vs/platform/actions/common/actions'

// --- Capture extension resource URL mappings ---
// FileAccess.uriToBrowserUri() uses a ResourceMap internally, but the URI lookup
// can fail when the theme service constructs a new URI object (different reference).
// We capture the mappings ourselves in a simple string-keyed Map.
// This MUST run before the extension imports so the map is populated.
const extensionResourceUrls = new Map()
const origRegister = FileAccess.registerStaticBrowserUri.bind(FileAccess)
FileAccess.registerStaticBrowserUri = function (uri, browserUri) {
  extensionResourceUrls.set(uri.toString(), browserUri.toString(true))
  return origRegister(uri, browserUri)
}

// Dynamic imports so they run AFTER the monkey-patch above.
// Static imports would evaluate before the module body.
await import('@codingame/monaco-vscode-all-language-default-extensions')
await import('@codingame/monaco-vscode-theme-defaults-default-extension')

// --- JS ↔ Swift bridge ---
function postToSwift(msg) {
  window.webkit?.messageHandlers?.editor?.postMessage(msg)
}

// Forward uncaught errors to Swift for debugging
window.onerror = (msg, src, line, col, err) => {
  postToSwift({ type: 'error', message: `${msg} (${src}:${line}:${col})` })
}
window.onunhandledrejection = (e) => {
  postToSwift({ type: 'error', message: `Unhandled rejection: ${e.reason}` })
}

// --- Worker setup ---
// Each language feature runs its own Web Worker for IntelliSense.
// TextMate runs grammar tokenization in a separate worker using oniguruma WASM.
// The editor worker handles diff computation, word completion, etc.
window.MonacoEnvironment = {
  getWorker(_, label) {
    if (label === 'TextMateWorker') {
      return new Worker(
        new URL('@codingame/monaco-vscode-textmate-service-override/worker', import.meta.url),
        { type: 'module' }
      )
    }
    if (label === 'typescript' || label === 'javascript') {
      return new Worker(
        new URL('@codingame/monaco-vscode-standalone-typescript-language-features/worker', import.meta.url),
        { type: 'module' }
      )
    }
    if (label === 'css' || label === 'scss' || label === 'less') {
      return new Worker(
        new URL('@codingame/monaco-vscode-standalone-css-language-features/worker', import.meta.url),
        { type: 'module' }
      )
    }
    if (label === 'html' || label === 'handlebars' || label === 'razor') {
      return new Worker(
        new URL('@codingame/monaco-vscode-standalone-html-language-features/worker', import.meta.url),
        { type: 'module' }
      )
    }
    if (label === 'json') {
      return new Worker(
        new URL('@codingame/monaco-vscode-standalone-json-language-features/worker', import.meta.url),
        { type: 'module' }
      )
    }
    return new Worker(
      new URL('monaco-editor/esm/vs/editor/editor.worker.js', import.meta.url),
      { type: 'module' }
    )
  }
}

// --- Extension resource loader for WKWebView ---
// The default readExtensionResource is "unsupported". We provide a simple
// implementation that resolves extension-file:// URIs to ff-resource:// URLs
// using our captured mapping, then fetches via the WKURLSchemeHandler.
class ExtensionResourceLoader {
  _serviceBrand = undefined
  supportsExtensionGalleryResources = false

  async readExtensionResource(uri) {
    const uriStr = uri.toString()
    const mappedUrl = extensionResourceUrls.get(uriStr)
    if (!mappedUrl) {
      throw new Error(`No resource mapping for ${uriStr}`)
    }
    const response = await fetch(mappedUrl)
    if (!response.ok) {
      throw new Error(`Failed to load ${uriStr}: ${response.status}`)
    }
    return response.text()
  }

  async getExtensionGalleryResourceURL() {
    return undefined
  }

  getExtensionGalleryRequestHeaders() {
    return {}
  }

  async isExtensionGalleryResource() {
    return false
  }
}

// --- Initialize VS Code services ---
// MUST be called once, BEFORE creating any editor instance.
// Uses full VS Code service overrides for TextMate grammars and themes.
// Resources are served via WKURLSchemeHandler (ff-resource://) so fetch() works.
await initialize({
  ...getTextmateServiceOverride(),
  ...getThemeServiceOverride(),
  ...getLanguagesServiceOverride(),
  [IExtensionResourceLoaderService.toString()]: new ExtensionResourceLoader()
}, undefined, {
  // initialColorTheme sets the dark appearance immediately at construction time.
  // configurationDefaults is NOT wired into the config system in standalone mode,
  // so we also force the theme via configurationService after init.
  initialColorTheme: { themeType: 'dark' }
})

// Force the dark theme via the configuration service.
// configurationDefaults doesn't work in @codingame/monaco-vscode-api standalone mode
// because DefaultConfiguration.getConfigurationDefaultOverrides() is never overridden.
const configService = await getService(IConfigurationService)
await configService.updateValue('workbench.colorTheme', 'Dark Modern')

// Import monaco AFTER initialize()
const monaco = await import('monaco-editor')

// Block Monarch tokenizer registration from standalone language features.
// Their setupMode() is lazy (called via onLanguage when the first model for
// that language is created) and registers a Monarch tokenizer via
// setTokensProvider. This conflicts with the TextMate tokenizer: the
// registration fires handleChange → todo_resetTokenization before the
// TextMate grammar is loaded, crashing _toBinaryTokens. Since TextMate
// handles all syntax highlighting, we no-op setTokensProvider entirely.
// The TextMate service uses setEncodedTokensProvider (different API).
monaco.languages.setTokensProvider = () => ({ dispose() {} })

// Standalone language features — must be imported AFTER initialize() so the
// VS Code service overrides (TextMate, themes, languages) are in place.
// These restore IntelliSense (completions, hover, diagnostics) without
// needing the full extension host.
await import('@codingame/monaco-vscode-standalone-typescript-language-features')
await import('@codingame/monaco-vscode-standalone-json-language-features')
await import('@codingame/monaco-vscode-standalone-css-language-features')
await import('@codingame/monaco-vscode-standalone-html-language-features')

// --- Create editor ---
const editor = monaco.editor.create(document.getElementById('editor'), {
  value: '',
  language: 'plaintext',
  automaticLayout: true,
  minimap: { enabled: false },
  fontSize: 13,
  fontFamily: 'Menlo, monospace',
  wordWrap: 'on',
  scrollBeyondLastLine: false,
  overviewRulerLanes: 0,
  hideCursorInOverviewRuler: true,
  cursorBlinking: 'smooth',
  smoothScrolling: true,
  scrollbar: {
    verticalScrollbarSize: 8,
    horizontalScrollbarSize: 8,
    vertical: 'auto',
    horizontal: 'auto',
    useShadows: false
  },
  padding: { top: 8 }
})

// Disable Quick Open (Cmd+P) — file search is not supported in this editor
editor.addCommand(monaco.KeyMod.CtrlCmd | monaco.KeyCode.KeyP, () => {})

// Disable Command Palette (F1 / Cmd+Shift+P) — not supported in this editor
editor.addCommand(monaco.KeyCode.F1, () => {})
editor.addCommand(monaco.KeyMod.CtrlCmd | monaco.KeyMod.Shift | monaco.KeyCode.KeyP, () => {})

// Remove "Command Palette..." from the right-click context menu
const origGetMenuItems = MenuRegistry.getMenuItems
MenuRegistry.getMenuItems = function (id) {
  const items = origGetMenuItems.call(this, id)
  if (id === MenuId.EditorContext) {
    return items.filter(item => !item.command || item.command.id !== 'workbench.action.showCommands')
  }
  return items
}

// --- Multi-model management ---
// One model per open file, keyed by UUID string from Swift.
// Switching tabs calls editor.setModel() — instant, preserves undo history.
const models = new Map()
// Deduplication: one Monaco model per file path, shared across tabs.
// Prevents the TypeScript language service from seeing duplicate declarations.
const fileModels = new Map()
let activeModelId = null
let contentChangedListener = null

window.editorAPI = {
  // Create or update a model and switch the editor to it.
  // filePath gives the model a file:// URI so the TypeScript worker can
  // resolve imports between open files and infer file types from the path.
  openFile(modelId, text, languageId, filePath) {
    // Dispose listener BEFORE setValue() so the old listener doesn't
    // catch it and send a false dirty event to Swift.
    if (contentChangedListener) contentChangedListener.dispose()
    contentChangedListener = null

    let model = models.get(modelId)
    if (!model) {
      // Reuse existing model for the same file (e.g. same file in two tabs).
      // Uses our own map instead of monaco.editor.getModel(uri) which can fail
      // with VS Code service overrides, creating duplicate models that confuse
      // the TypeScript language service ("Duplicate identifier" errors).
      if (filePath) model = fileModels.get(filePath)
      if (!model) {
        const uri = filePath ? monaco.Uri.file(filePath) : undefined
        model = monaco.editor.createModel(text, languageId, uri)
        if (filePath) fileModels.set(filePath, model)
      }
      models.set(modelId, model)
    } else {
      model.setValue(text)
      monaco.editor.setModelLanguage(model, languageId)
    }
    editor.setModel(model)
    activeModelId = modelId
    // Track dirty state via version IDs
    model._cleanVersionId = model.getAlternativeVersionId()
    contentChangedListener = model.onDidChangeContent(() => {
      const dirty = model.getAlternativeVersionId() !== model._cleanVersionId
      postToSwift({ type: 'contentChanged', modelId, dirty })
    })
    editor.focus()
  },

  // Switch to an existing model (tab switch, no content reload).
  switchModel(modelId) {
    const model = models.get(modelId)
    if (!model) return
    if (contentChangedListener) contentChangedListener.dispose()
    editor.setModel(model)
    activeModelId = modelId
    contentChangedListener = model.onDidChangeContent(() => {
      const dirty = model.getAlternativeVersionId() !== model._cleanVersionId
      postToSwift({ type: 'contentChanged', modelId, dirty })
    })
    editor.focus()
  },

  // Get content from any model (not just the active one).
  getContent(modelId) {
    const model = models.get(modelId)
    return model ? model.getValue() : null
  },

  // Mark a model as clean (after save).
  markClean(modelId) {
    const model = models.get(modelId)
    if (model) {
      model._cleanVersionId = model.getAlternativeVersionId()
    }
  },

  // Dispose a model (tab closed).
  // Only actually disposes the Monaco model if no other tab references it,
  // since multiple tabs can share a model when they open the same file.
  closeModel(modelId) {
    const model = models.get(modelId)
    models.delete(modelId)
    if (activeModelId === modelId) {
      activeModelId = null
    }
    if (model) {
      let stillReferenced = false
      for (const m of models.values()) {
        if (m === model) { stillReferenced = true; break }
      }
      if (!stillReferenced) {
        model.dispose()
        for (const [path, m] of fileModels) {
          if (m === model) { fileModels.delete(path); break }
        }
      }
    }
  },

  // Focus the editor.
  focus() {
    editor.focus()
  },

  // Switch between light and dark theme.
  setTheme(isDark) {
    configService.updateValue('workbench.colorTheme', isDark ? 'Dark Modern' : 'Light Modern')
    document.documentElement.style.colorScheme = isDark ? 'dark' : 'light'
  }
}

// Signal readiness to Swift
postToSwift({ type: 'ready' })

// Yield to the event loop so WebKit paints the themed content before revealing.
setTimeout(() => document.body.classList.remove('loading'))
