import { monaco, configService, postToSwift } from './shared-init.js'

// --- Stacked inline diff editors ---
// Each changed file gets its own diff editor instance, auto-sized to content.
// The page itself scrolls — individual editors do not.

const container = document.getElementById('container')
const emptyState = document.getElementById('empty-state')

// Active diff editors: [{ section, editor, originalModel, modifiedModel }]
let activeDiffs = []

// Line height in pixels — used for height calculation.
// Must match Monaco's lineHeight (default ~19px for 13px font).
const LINE_HEIGHT = 19
const HEADER_HEIGHT = 37 // .diff-header height
const MIN_EDITOR_HEIGHT = 60
const PADDING_LINES = 2

// Disposables for annotation zone listeners (cleaned up in clearDiffs)
let activeDisposables = []

// --- Reveal control ---
// Keep the page hidden (opacity: 0 via .loading class) until all diff editors
// have computed their diffs. This prevents the jarring flash of unstyled content
// (raw text without diff colors/folding) that occurs when Monaco is visible
// before diff computation finishes.
let revealed = false
let revealTimer = null

function reveal() {
  if (revealed) return
  revealed = true
  if (revealTimer) { clearTimeout(revealTimer); revealTimer = null }
  document.body.classList.remove('loading')
  postToSwift({ type: 'contentReady' })
}

function statusLabel(status) {
  switch (status) {
    case 'A': return 'A'
    case 'M': return 'M'
    case 'D': return 'D'
    case 'R': return 'R'
    default: return 'M'
  }
}

function statusClass(status) {
  switch (status) {
    case 'A': return 'added'
    case 'M': return 'modified'
    case 'D': return 'deleted'
    case 'R': return 'renamed'
    default: return 'modified'
  }
}

function formatFilePath(filePath) {
  const lastSlash = filePath.lastIndexOf('/')
  if (lastSlash === -1) return filePath
  const dir = filePath.substring(0, lastSlash + 1)
  const name = filePath.substring(lastSlash + 1)
  return `<span class="dir">${dir}</span>${name}`
}

function calculateEditorHeight(originalText, modifiedText) {
  const origLines = originalText ? originalText.split('\n').length : 0
  const modLines = modifiedText ? modifiedText.split('\n').length : 0
  // Use the larger of the two + padding for diff decorations
  const lines = Math.max(origLines, modLines) + PADDING_LINES
  return Math.max(lines * LINE_HEIGHT, MIN_EDITOR_HEIGHT)
}

function clearDiffs() {
  for (const d of activeDisposables) {
    if (d.disconnect) d.disconnect()
    if (d.dispose) d.dispose()
  }
  activeDisposables = []
  for (const diff of activeDiffs) {
    diff.editor.dispose()
    diff.originalModel.dispose()
    diff.modifiedModel.dispose()
  }
  activeDiffs = []
  // Remove all children except the empty-state placeholder
  for (const child of Array.from(container.children)) {
    if (child !== emptyState) child.remove()
  }
}

/**
 * Set the files to display diffs for.
 * @param {Array<{filePath: string, status: string, languageId: string, originalText: string, modifiedText: string}>} files
 */
function setFiles(files, reviewGuide) {
  // Reset reveal state and re-apply loading mask (hides content during rendering)
  revealed = false
  if (revealTimer) { clearTimeout(revealTimer); revealTimer = null }
  document.body.classList.add('loading')

  clearDiffs()

  if (!files || files.length === 0) {
    emptyState.classList.add('visible')
    reveal()
    return
  }
  emptyState.classList.remove('visible')

  // Track pending diff computations — reveal only when all complete
  let pendingCount = files.length

  // Safety timeout: reveal after 5s even if some diffs haven't completed
  revealTimer = setTimeout(() => {
    if (!revealed) reveal()
  }, 5000)

  // Render review guide summary at the top (scrolls with content)
  if (reviewGuide && reviewGuide.title) {
    const summary = document.createElement('div')
    summary.className = 'review-summary'
    const title = document.createElement('p')
    title.className = 'review-title'
    title.textContent = reviewGuide.title
    summary.appendChild(title)
    if (reviewGuide.summary) {
      const body = document.createElement('p')
      body.className = 'review-body'
      body.textContent = reviewGuide.summary
      summary.appendChild(body)
    }
    container.appendChild(summary)
  }

  for (const file of files) {
    const section = document.createElement('div')
    section.className = 'diff-section'

    // File header
    const header = document.createElement('div')
    header.className = 'diff-header'
    header.innerHTML = `
      <span class="status-badge ${statusClass(file.status)}">${statusLabel(file.status)}</span>
      <span class="file-path">${formatFilePath(file.filePath)}</span>
    `
    if (file.reason) {
      const reason = document.createElement('span')
      reason.className = 'review-reason'
      reason.textContent = file.reason
      header.appendChild(reason)
    }
    section.appendChild(header)

    // Editor container
    const editorContainer = document.createElement('div')
    editorContainer.className = 'diff-editor-container'
    const height = calculateEditorHeight(file.originalText, file.modifiedText)
    editorContainer.style.height = `${height}px`
    section.appendChild(editorContainer)

    container.appendChild(section)

    // Create models
    const originalModel = monaco.editor.createModel(
      file.originalText || '',
      file.languageId || 'plaintext'
    )
    const modifiedModel = monaco.editor.createModel(
      file.modifiedText || '',
      file.languageId || 'plaintext'
    )

    // Create inline diff editor
    const diffEditor = monaco.editor.createDiffEditor(editorContainer, {
      automaticLayout: true,
      renderSideBySide: false,
      readOnly: true,
      originalEditable: false,
      enableSplitViewResizing: false,
      wordWrap: 'on',
      minimap: { enabled: false },
      fontSize: 13,
      fontFamily: 'Menlo, monospace',
      lineNumbers: 'on',
      scrollBeyondLastLine: false,
      renderOverviewRuler: false,
      scrollbar: {
        vertical: 'hidden',
        horizontal: 'auto',
        verticalScrollbarSize: 0,
        horizontalScrollbarSize: 8,
        useShadows: false,
        alwaysConsumeMouseWheel: false,
        handleMouseWheel: false
      },
      overviewRulerLanes: 0,
      hideCursorInOverviewRuler: true,
      stickyScroll: { enabled: false },
      padding: { top: 4, bottom: 4 },
      renderIndicators: true,
      renderMarginRevertIcon: false,
      hideUnchangedRegions: { enabled: true }
    })

    diffEditor.setModel({
      original: originalModel,
      modified: modifiedModel
    })

    // Add annotations and resize after diff computation completes
    diffEditor.onDidUpdateDiff(() => {
      if (file.annotations && file.annotations.length > 0) {
        addAnnotationZones(diffEditor, file.annotations, editorContainer)
      }
      resizeDiffEditor(diffEditor, editorContainer)

      pendingCount--
      if (pendingCount <= 0) {
        reveal()
      }
    })

    activeDiffs.push({
      section,
      editor: diffEditor,
      originalModel,
      modifiedModel
    })
  }
}

/**
 * Resize a diff editor container to fit its content (no scrollbar needed).
 */
function resizeDiffEditor(diffEditor, editorContainer) {
  const modifiedEditor = diffEditor.getModifiedEditor()
  // contentHeight gives the exact pixel height of the content
  const contentHeight = modifiedEditor.getContentHeight()
  const newHeight = Math.max(contentHeight + 8, MIN_EDITOR_HEIGHT)
  editorContainer.style.height = `${newHeight}px`
  diffEditor.layout()
}

// --- Annotation view zones ---

const COMMENT_SVG = '<svg viewBox="0 0 16 16" xmlns="http://www.w3.org/2000/svg"><path d="M2.5 2A1.5 1.5 0 001 3.5v8A1.5 1.5 0 002.5 13h2.382l1.447 2.171a.75.75 0 001.242 0L9.018 13H13.5a1.5 1.5 0 001.5-1.5v-8A1.5 1.5 0 0013.5 2h-11zM4 6.25a.75.75 0 01.75-.75h6.5a.75.75 0 010 1.5h-6.5A.75.75 0 014 6.25zm.75 2.25a.75.75 0 000 1.5h4.5a.75.75 0 000-1.5h-4.5z"/></svg>'

function createAnnotationNode(bodyText) {
  // Monaco sets position:absolute, width:100%, and explicit height on the
  // domNode passed to addZone. Use an outer shell that Monaco can style
  // freely, with the actual annotation content inside it.
  const shell = document.createElement('div')

  const inner = document.createElement('div')
  inner.className = 'annotation-zone'
  inner.style.display = 'grid'
  inner.style.gridTemplateColumns = '14px 1fr'
  inner.style.gap = '8px'
  inner.style.alignItems = 'start'
  inner.style.margin = '0'

  const icon = document.createElement('div')
  icon.className = 'annotation-icon'
  icon.innerHTML = COMMENT_SVG
  inner.appendChild(icon)

  const content = document.createElement('div')
  content.className = 'annotation-content'
  content.style.minWidth = '0'

  const paragraphs = bodyText.split(/\n\n+/)
  for (const para of paragraphs) {
    const p = document.createElement('p')
    p.textContent = para.trim()
    if (p.textContent) content.appendChild(p)
  }

  inner.appendChild(content)
  shell.appendChild(inner)
  return shell
}

function addAnnotationZones(diffEditor, annotations, editorContainer) {
  const modifiedEditor = diffEditor.getModifiedEditor()
  const zoneEntries = []
  const decorations = []

  for (const annotation of annotations) {
    if (!annotation.body) continue
    const afterLine = annotation.lines
      ? annotation.lines[1]
      : (annotation.line || 1)
    zoneEntries.push({ afterLine, annotation })

    if (annotation.lines && annotation.lines.length === 2) {
      decorations.push({
        range: new monaco.Range(
          annotation.lines[0], 1,
          annotation.lines[1], Number.MAX_SAFE_INTEGER
        ),
        options: {
          className: 'annotation-highlight',
          isWholeLine: true
        }
      })
    }
  }

  if (zoneEntries.length === 0) return

  if (decorations.length > 0) {
    modifiedEditor.createDecorationsCollection(decorations)
  }

  let zoneIds = []

  // Build (or rebuild) all annotation zones at the current editor width.
  // Measures each domNode off-screen at the correct width, then creates
  // zones with accurate heights. Called on initial render and on resize.
  function buildZones() {
    const editorWidth = modifiedEditor.getLayoutInfo().contentWidth || 600

    const measure = document.createElement('div')
    measure.style.cssText =
      `position:absolute;visibility:hidden;top:-9999px;left:0;width:${editorWidth}px;pointer-events:none;`
    document.body.appendChild(measure)

    const zones = zoneEntries.map(({ afterLine, annotation }) => {
      const domNode = createAnnotationNode(annotation.body)
      measure.appendChild(domNode)
      // Measure the inner annotation node, not the shell (Monaco overrides shell height)
      const inner = domNode.firstElementChild
      const h = inner ? inner.offsetHeight : domNode.offsetHeight
      measure.removeChild(domNode)
      return { afterLine, domNode, height: Math.max(h + 4, 28) }
    })

    document.body.removeChild(measure)

    modifiedEditor.changeViewZones(accessor => {
      for (const id of zoneIds) accessor.removeZone(id)
      zoneIds = zones.map(({ afterLine, domNode, height }) =>
        accessor.addZone({
          afterLineNumber: afterLine,
          heightInPx: height,
          domNode,
          suppressMouseDown: true,
          showInHiddenAreas: true
        })
      )
    })

    resizeDiffEditor(diffEditor, editorContainer)
  }

  buildZones()

  // Rebuild when editor width changes (window resize → text reflow).
  // Debounced: during active resize, annotations stay visible at their current
  // heights (text inside reflows naturally). Zones rebuild once resize settles.
  let lastWidth = modifiedEditor.getLayoutInfo().contentWidth
  let resizeTimer = null
  const layoutDisposable = modifiedEditor.onDidLayoutChange((info) => {
    if (Math.abs(info.contentWidth - lastWidth) > 1) {
      lastWidth = info.contentWidth
      if (resizeTimer) clearTimeout(resizeTimer)
      resizeTimer = setTimeout(buildZones, 200)
    }
  })
  activeDisposables.push(layoutDisposable)
  activeDisposables.push({ dispose() { if (resizeTimer) clearTimeout(resizeTimer) } })
}

window.diffAPI = {
  setFiles,

  clear() {
    clearDiffs()
    emptyState.classList.add('visible')
    reveal()
  },

  setTheme(isDark) {
    configService.updateValue('workbench.colorTheme', isDark ? 'Dark Modern' : 'Light Modern')
    document.documentElement.style.colorScheme = isDark ? 'dark' : 'light'
  },

  layout() {
    for (const diff of activeDiffs) {
      diff.editor.layout()
    }
  }
}

// Signal readiness to Swift (JS API available, but content not yet rendered)
postToSwift({ type: 'ready' })
