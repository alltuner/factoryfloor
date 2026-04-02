// MatrixEffect: column-by-column pixel reveal/hide effect for agent spawn/despawn.
// Works on 16x32 pixel character sprites.

import type { SpriteEngine } from './SpriteEngine';
import type { Agent } from './AgentManager';


const CHAR_H = 32;
const DEFAULT_DURATION = 0.3;
const TOTAL_COLUMNS = 16;

// Green tint for leading edge overlay
const TINT_COLOR = '#00FF41';

export interface MatrixState {
  type: 'reveal' | 'hide';
  progress: number; // 0.0 to 1.0
  duration: number; // seconds
  columnsRevealed: number; // 0-16
}

export class MatrixEffect {
  static createReveal(duration?: number): MatrixState {
    return {
      type: 'reveal',
      progress: 0,
      duration: duration ?? DEFAULT_DURATION,
      columnsRevealed: 0,
    };
  }

  static createHide(duration?: number): MatrixState {
    return {
      type: 'hide',
      progress: 0,
      duration: duration ?? DEFAULT_DURATION,
      columnsRevealed: TOTAL_COLUMNS,
    };
  }

  /** Advance the effect. Returns true if still active, false if complete. */
  static update(state: MatrixState, dt: number): boolean {
    state.progress = Math.min(state.progress + dt / state.duration, 1.0);

    if (state.type === 'reveal') {
      state.columnsRevealed = Math.round(state.progress * TOTAL_COLUMNS);
    } else {
      // Hide: columns go from 16 down to 0
      state.columnsRevealed = Math.round((1 - state.progress) * TOTAL_COLUMNS);
    }

    return state.progress < 1.0;
  }

  /**
   * Draw a character with the matrix effect applied.
   * Uses clip-based column masking to avoid getImageData (which fails on
   * cross-origin tainted canvases in WKWebView file:// mode).
   */
  static draw(
    ctx: CanvasRenderingContext2D,
    sprites: SpriteEngine,
    agent: Agent,
    zoom: number,
  ): void {
    const state = agent.matrixState;
    if (!state) return;

    const sm = agent.stateMachine;
    const cols = state.columnsRevealed;
    if (cols <= 0) return;

    const colW = zoom; // each source pixel column = 1 * zoom screen pixels
    const revealW = cols * colW;

    ctx.save();
    ctx.imageSmoothingEnabled = false;

    // Clip to revealed columns only
    ctx.beginPath();
    ctx.rect(agent.pixelX, agent.pixelY, revealW, CHAR_H * zoom);
    ctx.clip();

    // Draw the full character (clipped to revealed region)
    sprites.drawCharacter(
      ctx,
      agent.palette,
      sm.direction,
      sm.getCurrentFrame(),
      agent.pixelX,
      agent.pixelY,
      zoom,
    );

    // Green tint overlay on leading edge (2 columns)
    if (cols < TOTAL_COLUMNS) {
      const edgeCols = Math.min(2, cols);
      const edgeX = agent.pixelX + (cols - edgeCols) * colW;
      const edgeW = edgeCols * colW;
      ctx.globalAlpha = 0.4;
      ctx.fillStyle = TINT_COLOR;
      ctx.fillRect(edgeX, agent.pixelY, edgeW, CHAR_H * zoom);
      ctx.globalAlpha = 1;
    }

    ctx.restore();
  }
}
