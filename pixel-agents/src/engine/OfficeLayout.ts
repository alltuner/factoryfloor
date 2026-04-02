// Office layout defining seat positions, furniture, and blocked tiles.
// Layout is a 16x5 tile grid with a centered boss workstation.

import type { TileMap, TileCoord } from './TileMap';
import type { Direction } from './SpriteEngine';

export interface Seat {
  id: number;
  chairTile: TileCoord;
  deskTile: TileCoord;
  pcTile: TileCoord;
  facing: Direction;
  isBoss: boolean;
  occupied: boolean;
  agentId: string | null;
}

export interface FurnitureItem {
  type: 'desk' | 'pc' | 'chair' | 'whiteboard' | 'coffee' | 'plant' | 'sofa' | 'bookshelf' | 'bin' | 'cactus' | 'pot' | 'table' | 'bench';
  tile: TileCoord;
  spriteKey: string;
  blocksMovement: boolean;
}

export interface FloorZone {
  colStart: number;
  colEnd: number;   // inclusive
  rowStart: number;
  rowEnd: number;    // inclusive
  tileIndex: number;
  tint?: string;     // semi-transparent RGBA color overlay (e.g. 'rgba(139,90,43,0.18)')
}

export interface WanderTarget {
  tile: TileCoord;
  label: string;
}

// Layout diagram (16 cols × 5 rows):
//   Col:  0  1  2  3  4  5  6  7  8  9  10 11 12 13 14 15
// Row 0: [W][BS][BS][W][BS][BS][W] [W] [W] [W] [W] [W][BS][BS][W][BS]  wall + bookshelves
// Row 1: [.][D1][PC][BN][D2][PC][CF][.] [.][SF][.] [BN][D3][PC][.][D4][PC]  desks + bins + meeting
// Row 2: [>] [.][C1][.] [.][C2][.] [.] [.] [.] [.] [.][C3][.] [.][C4]      corridor + chairs
// Row 3: [CA][.] [.] [.][PL][.] [.][D0*][PC][.] [.][PL][.] [.] [.][PL]     boss desk + plants
// Row 4: [PT][.] [.] [.] [.] [.] [.] [.][C0*][.] [.] [.] [.] [.] [.] [.]  boss chair + pot
//
// D0*/C0* = Boss (Claude main agent), facing up toward meeting area
// D1-D4 = Subagent desks (2 left, 2 right)
// CF = Coffee, SF = Sofa, BS = Bookshelf, BN = Bin, CA = Cactus, PT = Pot, PL = Plant
//
// Floor zones: wood planks (work), checkerboard (boss), tile grid (meeting), plain (corridor)

const SEATS: Omit<Seat, 'occupied' | 'agentId'>[] = [
  // Boss seat (center, row 3-4) — reserved for main Claude agent
  { id: 0, chairTile: [8, 4],  deskTile: [7, 3],  pcTile: [8, 3],  facing: 'up', isBoss: true },
  // Subagent seats: left-near, left-far, right-near, right-far
  { id: 1, chairTile: [2, 2],  deskTile: [1, 1],  pcTile: [2, 1],  facing: 'up', isBoss: false },
  { id: 2, chairTile: [5, 2],  deskTile: [4, 1],  pcTile: [5, 1],  facing: 'up', isBoss: false },
  { id: 3, chairTile: [12, 2], deskTile: [11, 1], pcTile: [12, 1], facing: 'up', isBoss: false },
  { id: 4, chairTile: [15, 2], deskTile: [14, 1], pcTile: [15, 1], facing: 'up', isBoss: false },
];

const FURNITURE: FurnitureItem[] = [
  // === Bookshelves on wall (row 0, already blocked) ===
  { type: 'bookshelf', tile: [1, 0],  spriteKey: 'double_bookshelf', blocksMovement: true },
  { type: 'bookshelf', tile: [4, 0],  spriteKey: 'double_bookshelf', blocksMovement: true },
  { type: 'bookshelf', tile: [12, 0], spriteKey: 'double_bookshelf', blocksMovement: true },
  { type: 'bookshelf', tile: [15, 0], spriteKey: 'bookshelf', blocksMovement: true },

  // === Subagent desks — 2 left, 2 right ===
  { type: 'desk', tile: [1, 1],  spriteKey: 'desk_front', blocksMovement: true },
  { type: 'desk', tile: [4, 1],  spriteKey: 'desk_front', blocksMovement: true },
  { type: 'desk', tile: [11, 1], spriteKey: 'desk_front', blocksMovement: true },
  { type: 'desk', tile: [14, 1], spriteKey: 'desk_front', blocksMovement: true },

  // Boss desk (center, row 3)
  { type: 'desk', tile: [7, 3],  spriteKey: 'desk_front', blocksMovement: true },

  // === PCs on desks ===
  { type: 'pc', tile: [2, 1],  spriteKey: 'pc_on', blocksMovement: true },
  { type: 'pc', tile: [5, 1],  spriteKey: 'pc_on', blocksMovement: true },
  { type: 'pc', tile: [12, 1], spriteKey: 'pc_on', blocksMovement: true },
  { type: 'pc', tile: [15, 1], spriteKey: 'pc_on', blocksMovement: true },
  { type: 'pc', tile: [8, 3],  spriteKey: 'pc_on', blocksMovement: true },

  // === Meeting area — coffee cup + sofa ===
  { type: 'coffee', tile: [6, 2], spriteKey: 'coffee', blocksMovement: false },
  { type: 'sofa',   tile: [9, 1], spriteKey: 'sofa_front', blocksMovement: true },

  // === Bins ===
  { type: 'bin', tile: [7, 1],  spriteKey: 'bin', blocksMovement: false },
  { type: 'bin', tile: [17, 2], spriteKey: 'bin', blocksMovement: false },

  // === Plants framing boss area (row 3, not row 4 — clear walk path) ===
  { type: 'plant', tile: [4, 3],  spriteKey: 'plant', blocksMovement: true },
  { type: 'plant', tile: [11, 3], spriteKey: 'plant', blocksMovement: true },
  { type: 'plant', tile: [15, 3], spriteKey: 'plant_2', blocksMovement: true },

  // === Corner accents ===
  { type: 'cactus', tile: [0, 3], spriteKey: 'cactus', blocksMovement: true },
  { type: 'pot',    tile: [0, 4], spriteKey: 'pot', blocksMovement: false },
];

const WANDER_TARGETS: WanderTarget[] = [
  { tile: [7, 2],  label: 'meeting' },   // corridor in front of meeting area
  { tile: [3, 3],  label: 'left_hall' },  // open area left side
  { tile: [12, 3], label: 'right_hall' }, // open area right side
  { tile: [3, 4],  label: 'lounge' },     // open area bottom-left
];

// Floor zones: base tile + color tint overlays create distinct visual areas
// Inspired by pixel office references: warm wood for work, cool carpet for boss
const FLOOR_ZONES: FloorZone[] = [
  // Work area left — warm amber tint (brown wood flooring)
  { colStart: 0, colEnd: 6, rowStart: 1, rowEnd: 2, tileIndex: 5, tint: 'rgba(120,75,30,0.42)' },
  // Work area right — same warm tint
  { colStart: 11, colEnd: 16, rowStart: 1, rowEnd: 2, tileIndex: 5, tint: 'rgba(120,75,30,0.42)' },
  // Meeting/break zone center — warm neutral
  { colStart: 7, colEnd: 10, rowStart: 1, rowEnd: 2, tileIndex: 3, tint: 'rgba(150,110,50,0.25)' },
  // Boss zone — cool blue carpet
  { colStart: 5, colEnd: 10, rowStart: 3, rowEnd: 4, tileIndex: 3, tint: 'rgba(35,70,110,0.40)' },
];

const DEFAULT_FLOOR_TILE = 2;

export class OfficeLayout {
  readonly cols = 17;
  readonly rows = 5;
  readonly tileSize = 16;
  readonly zoom = 3;
  readonly spawnTile: TileCoord = [0, 2];
  readonly furniture: FurnitureItem[] = FURNITURE;
  readonly wanderTargets: WanderTarget[] = WANDER_TARGETS;

  private seats: Seat[];

  constructor() {
    this.seats = SEATS.map((s) => ({
      ...s,
      occupied: false,
      agentId: null,
    }));
  }

  initBlockedTiles(tileMap: TileMap): void {
    // Block entire wall row
    for (let c = 0; c < this.cols; c++) {
      tileMap.block(c, 0);
    }

    // Block furniture that blocks movement
    for (const item of this.furniture) {
      if (item.blocksMovement) {
        tileMap.block(item.tile[0], item.tile[1]);
      }
    }

    // Desk+PC sprites visually extend ~2 tiles right of the desk.
    // Block the tile right of each PC so agents don't walk through the visual footprint.
    for (const item of this.furniture) {
      if (item.type === 'pc') {
        tileMap.block(item.tile[0] + 1, item.tile[1]);
      }
    }
  }

  claimSeat(agentId: string, reserveBoss = false): Seat | null {
    let seat: Seat | undefined;
    if (reserveBoss) {
      // Main agent gets the boss seat
      seat = this.seats.find((s) => s.isBoss && !s.occupied);
    } else {
      // Subagents skip the boss seat
      seat = this.seats.find((s) => !s.isBoss && !s.occupied);
    }
    // Fallback: any free seat
    if (!seat) {
      seat = this.seats.find((s) => !s.occupied);
    }
    if (!seat) return null;
    seat.occupied = true;
    seat.agentId = agentId;
    return seat;
  }

  releaseSeat(agentId: string): void {
    const seat = this.seats.find((s) => s.agentId === agentId);
    if (seat) {
      seat.occupied = false;
      seat.agentId = null;
    }
  }

  getSeat(agentId: string): Seat | null {
    return this.seats.find((s) => s.agentId === agentId) ?? null;
  }

  getSeats(): Seat[] {
    return this.seats;
  }

  isSeatOccupied(seatId: number): boolean {
    const seat = this.seats.find((s) => s.id === seatId);
    return seat?.occupied ?? false;
  }

  getSeatForPc(col: number, row: number): Seat | null {
    return this.seats.find((s) => s.pcTile[0] === col && s.pcTile[1] === row) ?? null;
  }

  /** Return the floor tile index for a given tile coordinate (for zone-based rendering). */
  getFloorTileIndex(col: number, row: number): number {
    for (const zone of FLOOR_ZONES) {
      if (col >= zone.colStart && col <= zone.colEnd &&
          row >= zone.rowStart && row <= zone.rowEnd) {
        return zone.tileIndex;
      }
    }
    return DEFAULT_FLOOR_TILE;
  }

  /** Return the color tint for a floor zone, or null for no tint. */
  getFloorTint(col: number, row: number): string | null {
    for (const zone of FLOOR_ZONES) {
      if (col >= zone.colStart && col <= zone.colEnd &&
          row >= zone.rowStart && row <= zone.rowEnd) {
        return zone.tint ?? null;
      }
    }
    return null;
  }
}
