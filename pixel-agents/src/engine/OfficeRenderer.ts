// Main render loop: draws tiled floor, furniture, agents, and name labels.

import type { SpriteEngine } from './SpriteEngine';
import type { AgentManager } from './AgentManager';

const ZOOM = 3;
const LABEL_FONT = '10px monospace';
const LABEL_COLOR = '#e0e0e0';
const LABEL_SHADOW = '#000000';
const LABEL_OFFSET_Y = -4;

// Furniture offsets relative to agent position (in zoomed pixels)
const DESK_OFFSET_X = -8;
const DESK_OFFSET_Y = 56;
const PC_OFFSET_X = 4;
const PC_OFFSET_Y = 20;

export class OfficeRenderer {
  private canvas: HTMLCanvasElement;
  private ctx: CanvasRenderingContext2D;
  private sprites: SpriteEngine;
  private agentManager: AgentManager;
  private rafId: number | null = null;
  private lastTime = 0;
  private running = false;

  constructor(
    canvas: HTMLCanvasElement,
    sprites: SpriteEngine,
    agentManager: AgentManager,
  ) {
    this.canvas = canvas;
    this.ctx = canvas.getContext('2d')!;
    this.sprites = sprites;
    this.agentManager = agentManager;
  }

  start(): void {
    if (this.running) return;
    this.running = true;
    this.lastTime = performance.now();
    this.resize();
    this.rafId = requestAnimationFrame((t) => this.loop(t));
  }

  stop(): void {
    this.running = false;
    if (this.rafId !== null) {
      cancelAnimationFrame(this.rafId);
      this.rafId = null;
    }
  }

  resize(): void {
    const dpr = window.devicePixelRatio || 1;
    const parent = this.canvas.parentElement;
    const w = parent ? parent.clientWidth : window.innerWidth;
    const h = parent ? parent.clientHeight : window.innerHeight;
    this.canvas.width = w * dpr;
    this.canvas.height = h * dpr;
    this.canvas.style.width = `${w}px`;
    this.canvas.style.height = `${h}px`;
    this.ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
  }

  private loop(time: number): void {
    if (!this.running) return;

    const dt = Math.min((time - this.lastTime) / 1000, 0.1);
    this.lastTime = time;

    this.agentManager.updateAll(dt);
    this.draw();

    this.rafId = requestAnimationFrame((t) => this.loop(t));
  }

  private draw(): void {
    const ctx = this.ctx;
    const parent = this.canvas.parentElement;
    const w = parent ? parent.clientWidth : window.innerWidth;
    const h = parent ? parent.clientHeight : window.innerHeight;

    // Clear
    ctx.fillStyle = '#1a1a2e';
    ctx.fillRect(0, 0, w, h);

    // Draw tiled floor
    this.drawFloor(w, h);

    // Draw agents sorted by y for depth ordering
    const agents = this.agentManager.getAgents();
    for (const agent of agents) {
      const sm = agent.stateMachine;
      const isAtDesk = sm.state === 'type' || sm.state === 'read';

      // Draw desk and PC behind agent if at desk
      if (isAtDesk) {
        const deskImg = this.sprites.getDeskImage();
        if (deskImg) {
          this.sprites.drawFurniture(
            ctx,
            deskImg,
            agent.x + DESK_OFFSET_X,
            agent.y + DESK_OFFSET_Y,
            ZOOM,
          );
        }
        const pcImg = this.sprites.getPcImage();
        if (pcImg) {
          this.sprites.drawFurniture(
            ctx,
            pcImg,
            agent.x + PC_OFFSET_X,
            agent.y + PC_OFFSET_Y,
            ZOOM,
          );
        }
      }

      // Draw character sprite
      this.sprites.drawCharacter(
        ctx,
        agent.palette,
        sm.direction,
        sm.getCurrentFrame(),
        agent.x,
        agent.y,
        ZOOM,
      );

      // Draw name label above character
      this.drawLabel(ctx, agent.name, agent.x + (16 * ZOOM) / 2, agent.y + LABEL_OFFSET_Y);
    }
  }

  private drawFloor(w: number, h: number): void {
    const tile = this.sprites.getFloorTile();
    if (!tile) return;

    const ctx = this.ctx;
    ctx.imageSmoothingEnabled = false;
    const tw = tile.width * ZOOM;
    const th = tile.height * ZOOM;

    for (let y = 0; y < h; y += th) {
      for (let x = 0; x < w; x += tw) {
        ctx.drawImage(tile, x, y, tw, th);
      }
    }
  }

  private drawLabel(
    ctx: CanvasRenderingContext2D,
    text: string,
    cx: number,
    y: number,
  ): void {
    ctx.font = LABEL_FONT;
    ctx.textAlign = 'center';
    ctx.textBaseline = 'bottom';

    // Shadow for readability
    ctx.fillStyle = LABEL_SHADOW;
    ctx.fillText(text, cx + 1, y + 1);

    ctx.fillStyle = LABEL_COLOR;
    ctx.fillText(text, cx, y);
  }
}
