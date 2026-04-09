import { initialize, getService } from '@codingame/monaco-vscode-api'
import { IExtensionResourceLoaderService } from '@codingame/monaco-vscode-api/vscode/vs/platform/extensionResourceLoader/common/extensionResourceLoader.service'
import { IConfigurationService } from '@codingame/monaco-vscode-api/vscode/vs/platform/configuration/common/configuration.service'
import { FileAccess } from '@codingame/monaco-vscode-api/vscode/vs/base/common/network'
import getTextmateServiceOverride from '@codingame/monaco-vscode-textmate-service-override'
import getThemeServiceOverride from '@codingame/monaco-vscode-theme-service-override'
import getLanguagesServiceOverride from '@codingame/monaco-vscode-languages-service-override'

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
// TextMate runs grammar tokenization in a Web Worker using oniguruma WASM.
// The editor worker handles diff computation, word completion, etc.
window.MonacoEnvironment = {
  getWorker(_, label) {
    if (label === 'TextMateWorker') {
      return new Worker(
        new URL(
          '@codingame/monaco-vscode-textmate-service-override/worker',
          import.meta.url
        ),
        { type: 'module' }
      )
    }
    return new Worker(
      new URL(
        'monaco-editor/esm/vs/editor/editor.worker.js',
        import.meta.url
      ),
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
  scrollbar: {
    verticalScrollbarSize: 10,
    horizontalScrollbarSize: 10
  },
  padding: { top: 8 }
})

// --- Multi-model management ---
// One model per open file, keyed by UUID string from Swift.
// Switching tabs calls editor.setModel() — instant, preserves undo history.
const models = new Map()
let activeModelId = null
let contentChangedListener = null

window.editorAPI = {
  // Create or update a model and switch the editor to it.
  openFile(modelId, text, languageId) {
    let model = models.get(modelId)
    if (!model) {
      model = monaco.editor.createModel(text, languageId)
      models.set(modelId, model)
    } else {
      model.setValue(text)
      monaco.editor.setModelLanguage(model, languageId)
    }
    // Switch editor to this model
    if (contentChangedListener) contentChangedListener.dispose()
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
  closeModel(modelId) {
    const model = models.get(modelId)
    if (model) {
      model.dispose()
      models.delete(modelId)
    }
    if (activeModelId === modelId) {
      activeModelId = null
    }
  },

  // Focus the editor.
  focus() {
    editor.focus()
  }
}

// Signal readiness to Swift
postToSwift({ type: 'ready' })
