// Main render loop: draws a compact office scene sized for a ~200px tall panel.
// Layout-driven: uses TileMap + OfficeLayout for positioning when available.

import type { AgentManager } from './AgentManager';
import type { SpriteEngine } from './SpriteEngine';
import type { TileMap } from './TileMap';
import type { OfficeLayout } from './OfficeLayout';
import { MatrixEffect } from './MatrixEffect';
import { BubbleRenderer } from './BubbleRenderer';

const ZOOM = 3;
const TILE_SIZE = 16;
const LABEL_FONT = '10px monospace';
const LABEL_COLOR = '#e0e0e0';
const LABEL_SHADOW = '#000000';

// Wall: just 1 tile row to save vertical space
const WALL_ROWS = 1;

// Floor tile
const FLOOR_TILE_INDEX = 2;

// Layout: designed for ~200px panel height
const CONTENT_TOP = TILE_SIZE * ZOOM * WALL_ROWS; // 48px

// Legacy hardcoded positions (used when no TileMap/OfficeLayout provided)
const CHAR_Y = CONTENT_TOP + 20;
const CHAR_SITTING_Y = CONTENT_TOP + 14;
const DESK_Y = CHAR_Y + 52;
const PC_Y = DESK_Y - 28;
const CHAIR_Y = CHAR_SITTING_Y - 16;
const MAX_WORKSTATIONS = 5;
const WORKSTATION_SPACING = 160;
const WORKSTATION_BASE_X = 80;

export class OfficeRenderer {
  private canvas: HTMLCanvasElement;
  private ctx: CanvasRenderingContext2D;
  private sprites: SpriteEngine;
  private agentManager: AgentManager;
  private tileMap: TileMap | null;
  private layout: OfficeLayout | null;
  private rafId: number | null = null;
  private lastTime = 0;
  private running = false;

  constructor(
    canvas: HTMLCanvasElement,
    sprites: SpriteEngine,
    agentManager: AgentManager,
    tileMap?: TileMap,
    layout?: OfficeLayout,
  ) {
    this.canvas = canvas;
    this.ctx = canvas.getContext('2d')!;
    this.sprites = sprites;
    this.agentManager = agentManager;
    this.tileMap = tileMap ?? null;
    this.layout = layout ?? null;
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

    ctx.fillStyle = '#2a2a3e';
    ctx.fillRect(0, 0, w, h);

    this.drawWall(w);
    this.drawFloor(w, h);
    this.drawWallDecorations(w);

    if (this.tileMap && this.layout) {
      this.drawLayoutDriven(ctx);
    } else {
      this.drawLegacy(ctx, w, h);
    }
  }

  // Layout-driven rendering: positions come from TileMap + OfficeLayout
  private drawLayoutDriven(ctx: CanvasRenderingContext2D): void {
    const tileMap = this.tileMap!;
    const layout = this.layout!;

    // Sort furniture by tile row for correct depth ordering (back-to-front)
    const sortedFurniture = [...layout.furniture].sort((a, b) => {
      if (a.tile[1] !== b.tile[1]) return a.tile[1] - b.tile[1];
      return a.tile[0] - b.tile[0];
    });

    // Collect agents sorted by tileY for depth ordering
    const agents = this.agentManager.getAgents();

    // Build a set of occupied+working PC tiles for on/off state
    const activePcTiles = new Set<string>();
    for (const agent of agents) {
      const sm = agent.stateMachine;
      const isWorking = sm.state === 'type' || sm.state === 'read';
      if (isWorking) {
        const seat = layout.getSeat(agent.id);
        if (seat) {
          activePcTiles.add(`${seat.pcTile[0]},${seat.pcTile[1]}`);
        }
      }
    }

    // Interleave furniture and agents by row for proper depth
    // Group: draw all items for each row, furniture first then agents
    const maxRow = layout.rows;
    for (let row = 0; row < maxRow; row++) {
      // Draw furniture for this row
      for (const item of sortedFurniture) {
        if (item.tile[1] !== row) continue;
        let spriteKey = item.spriteKey;

        // PC on/off: use pc_off when seat is not actively working
        if (item.type === 'pc') {
          const pcKey = `${item.tile[0]},${item.tile[1]}`;
          if (!activePcTiles.has(pcKey)) {
            spriteKey = 'pc_off';
          }
        }

        const img = this.sprites.getFurniture(spriteKey) ?? this.sprites.getFurniture(item.spriteKey);
        if (!img) continue;
        const pos = tileMap.tileToPixel(item.tile[0], item.tile[1]);
        this.sprites.drawFurniture(ctx, img, pos.x, pos.y, ZOOM);
      }

      // Draw agents at this row
      for (const agent of agents) {
        if (agent.tileY !== row) continue;
        const sm = agent.stateMachine;
        const isWorking = sm.state === 'type' || sm.state === 'read';

        // Only draw chair when agent is actively working at the desk
        if (isWorking && agent.targetSeat !== null) {
          const seat = layout.getSeat(agent.id);
          if (seat) {
            const chairImg = this.sprites.getFurniture('chair_back');
            if (chairImg) {
              const chairPos = tileMap.tileToPixel(seat.chairTile[0], seat.chairTile[1]);
              // Position chair behind (below) the agent sprite — chair back peeks out below
              this.sprites.drawFurniture(ctx, chairImg, chairPos.x, chairPos.y + 16 * ZOOM, ZOOM);
            }
          }
        }

        // Draw character at pixel position (with matrix effect if active)
        if (agent.matrixState) {
          MatrixEffect.draw(ctx, this.sprites, agent, ZOOM);
        } else {
          this.sprites.drawCharacter(
            ctx,
            agent.palette,
            sm.direction,
            sm.getCurrentFrame(),
            agent.pixelX,
            agent.pixelY,
            ZOOM,
          );
        }

        // Label above character
        this.drawLabel(ctx, agent.name, agent.pixelX + (16 * ZOOM) / 2, agent.pixelY - 4);

        // Bubble above agent
        if (agent.bubbleState) {
          const agentCenterX = agent.pixelX + (16 * ZOOM) / 2;
          const agentTopY = agent.pixelY - 4; // above label
          BubbleRenderer.draw(ctx, agent.bubbleState, agentCenterX, agentTopY, ZOOM);
        }
      }
    }

    // Draw any agents beyond the layout rows (e.g. walking off-grid)
    for (const agent of agents) {
      if (agent.tileY >= 0 && agent.tileY < maxRow) continue;
      const sm = agent.stateMachine;
      if (agent.matrixState) {
        MatrixEffect.draw(ctx, this.sprites, agent, ZOOM);
      } else {
        this.sprites.drawCharacter(
          ctx,
          agent.palette,
          sm.direction,
          sm.getCurrentFrame(),
          agent.pixelX,
          agent.pixelY,
          ZOOM,
        );
      }
      this.drawLabel(ctx, agent.name, agent.pixelX + (16 * ZOOM) / 2, agent.pixelY - 4);

      // Bubble above agent
      if (agent.bubbleState) {
        const agentCenterX = agent.pixelX + (16 * ZOOM) / 2;
        const agentTopY = agent.pixelY - 4;
        BubbleRenderer.draw(ctx, agent.bubbleState, agentCenterX, agentTopY, ZOOM);
      }
    }
  }

  // Legacy rendering: hardcoded workstation positions (backward compat)
  private drawLegacy(ctx: CanvasRenderingContext2D, w: number, h: number): void {
    const agents = this.agentManager.getAgents();
    const numStations = Math.max(agents.length, 1);

    for (let i = 0; i < Math.min(numStations, MAX_WORKSTATIONS); i++) {
      const sx = WORKSTATION_BASE_X + i * WORKSTATION_SPACING;
      const agent = agents[i];
      const isWorking = agent && (agent.stateMachine.state === 'type' || agent.stateMachine.state === 'read');

      // Layer 1: Chair (behind character)
      if (isWorking) {
        const chairImg = this.sprites.getFurniture('chair_back');
        if (chairImg) {
          this.sprites.drawFurniture(ctx, chairImg, sx + 8, CHAIR_Y, ZOOM);
        }
      }

      // Layer 2: PC on desk (behind character, to the right side)
      if (isWorking) {
        const pcImg = this.sprites.getPcImage();
        if (pcImg) {
          this.sprites.drawFurniture(ctx, pcImg, sx + 40, PC_Y, ZOOM);
        }
      }

      // Layer 3: Character (in front of PC)
      if (agent) {
        const sm = agent.stateMachine;
        const cy = isWorking ? CHAR_SITTING_Y : CHAR_Y;

        this.sprites.drawCharacter(ctx, agent.palette, sm.direction, sm.getCurrentFrame(), sx, cy, ZOOM);

        // Label above character
        this.drawLabel(ctx, agent.name, sx + (16 * ZOOM) / 2, cy - 4);

        // Bubble above agent
        if (agent.bubbleState) {
          const agentCenterX = sx + (16 * ZOOM) / 2;
          const agentTopY = cy - 4;
          BubbleRenderer.draw(ctx, agent.bubbleState, agentCenterX, agentTopY, ZOOM);
        }
      }

      // Layer 4: Desk (always visible, in front of character legs)
      const deskImg = this.sprites.getDeskImage();
      if (deskImg) {
        this.sprites.drawFurniture(ctx, deskImg, sx - 8, DESK_Y, ZOOM);
      }
    }

    this.drawFloorDecorations(w, h);
  }

  private drawWall(w: number): void {
    const ctx = this.ctx;
    const wallTile = this.sprites.getFurniture('wall');
    const wallH = CONTENT_TOP;

    if (wallTile) {
      ctx.imageSmoothingEnabled = false;
      const tw = wallTile.width * ZOOM;
      const th = wallTile.height * ZOOM;
      for (let y = 0; y < wallH; y += th) {
        for (let x = 0; x < w; x += tw) {
          ctx.drawImage(wallTile, x, y, tw, th);
        }
      }
    } else {
      ctx.fillStyle = '#3a3a5c';
      ctx.fillRect(0, 0, w, wallH);
    }

    // Baseboard
    ctx.fillStyle = '#555577';
    ctx.fillRect(0, wallH - 2, w, 2);
  }

  private drawFloor(w: number, h: number): void {
    const tile = this.sprites.getFloorTile(FLOOR_TILE_INDEX) ?? this.sprites.getFloorTile(0);
    if (!tile) return;

    const ctx = this.ctx;
    ctx.imageSmoothingEnabled = false;
    const tw = tile.width * ZOOM;
    const th = tile.height * ZOOM;

    for (let y = CONTENT_TOP; y < h; y += th) {
      for (let x = 0; x < w; x += tw) {
        ctx.drawImage(tile, x, y, tw, th);
      }
    }
  }

  private drawWallDecorations(_w: number): void {
    const ctx = this.ctx;
    const clock = this.sprites.getFurniture('clock');
    if (clock) {
      this.sprites.drawFurniture(ctx, clock, 16, CONTENT_TOP - clock.height * ZOOM + 4, ZOOM);
    }

    // Large painting centered above boss desk area (col 7-8)
    if (this.tileMap) {
      const largePainting = this.sprites.getFurniture('large_painting');
      if (largePainting) {
        const bossX = this.tileMap.tileToPixel(7, 0).x;
        this.sprites.drawFurniture(ctx, largePainting, bossX, CONTENT_TOP - largePainting.height * ZOOM + 4, ZOOM);
      }
    } else {
      const smallPainting = this.sprites.getFurniture('small_painting');
      if (smallPainting) {
        this.sprites.drawFurniture(ctx, smallPainting, 400 - (smallPainting.width * ZOOM) / 2, CONTENT_TOP - smallPainting.height * ZOOM + 4, ZOOM);
      }
    }
  }

  private drawFloorDecorations(w: number, _h: number): void {
    const ctx = this.ctx;
    const cactus = this.sprites.getFurniture('cactus');
    if (cactus) {
      this.sprites.drawFurniture(ctx, cactus, w - 50, CONTENT_TOP + 4, ZOOM);
    }

    const pot = this.sprites.getFurniture('pot');
    if (pot) {
      this.sprites.drawFurniture(ctx, pot, 16, CONTENT_TOP + 50, ZOOM);
    }
  }

  private drawLabel(ctx: CanvasRenderingContext2D, text: string, cx: number, y: number): void {
    ctx.font = LABEL_FONT;
    ctx.textAlign = 'center';
    ctx.textBaseline = 'bottom';
    ctx.fillStyle = LABEL_SHADOW;
    ctx.fillText(text, cx + 1, y + 1);
    ctx.fillStyle = LABEL_COLOR;
    ctx.fillText(text, cx, y);
  }
}
