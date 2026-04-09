import { initialize } from '@codingame/monaco-vscode-api'
import getTextmateServiceOverride from '@codingame/monaco-vscode-textmate-service-override'
import getThemeServiceOverride from '@codingame/monaco-vscode-theme-service-override'
import getLanguagesServiceOverride from '@codingame/monaco-vscode-languages-service-override'

// All 54 language TextMate grammars (auto-register on import)
import '@codingame/monaco-vscode-all-language-default-extensions'
// VS Code Dark+/Light+ themes
import '@codingame/monaco-vscode-theme-defaults-default-extension'

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

// --- Initialize VS Code services ---
// MUST be called once, BEFORE creating any editor instance.
await initialize({
  ...getTextmateServiceOverride(),
  ...getThemeServiceOverride(),
  ...getLanguagesServiceOverride()
})

// Import monaco AFTER initialize()
const monaco = await import('monaco-editor')

// --- Create editor ---
const editor = monaco.editor.create(document.getElementById('editor'), {
  value: '',
  language: 'plaintext',
  theme: 'Default Dark+',
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

// --- JS ↔ Swift bridge ---
function postToSwift(msg) {
  window.webkit?.messageHandlers?.editor?.postMessage(msg)
}

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

  // Apply a custom theme. themeData must be a Monaco IStandaloneThemeData object.
  setTheme(themeData) {
    monaco.editor.defineTheme('ghostty', themeData)
    monaco.editor.setTheme('ghostty')
  },

  // Focus the editor.
  focus() {
    editor.focus()
  }
}

// Signal readiness to Swift
postToSwift({ type: 'ready' })
