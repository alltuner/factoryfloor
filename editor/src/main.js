import { monaco, configService, postToSwift } from './shared-init.js'

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

  // Force a layout pass (call after reparenting the WKWebView into a new container).
  layout() {
    editor.layout()
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
