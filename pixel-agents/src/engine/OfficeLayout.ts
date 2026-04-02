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
  type: 'desk' | 'pc' | 'chair' | 'whiteboard' | 'coffee' | 'plant' | 'sofa';
  tile: TileCoord;
  spriteKey: string;
  blocksMovement: boolean;
}

export interface WanderTarget {
  tile: TileCoord;
  label: string;
}

// Layout diagram (16 cols × 5 rows):
//   Col:  0  1  2  3  4  5  6  7  8  9  10 11 12 13 14 15
// Row 0: [W] [W] [W] [W] [W] [W] [W] [W] [W] [W] [W] [W] [W] [W] [W] [W]   wall
// Row 1: [.] [D1][PC][.] [D2][PC][CF][.] [.] [SF][.] [D3][PC][.] [D4][PC]   subagent desks + meeting area
// Row 2: [>] [.][C1][.] [.][C2][.] [.] [.] [.] [.] [.][C3][.] [.][C4]       corridor + subagent chairs
// Row 3: [.] [.] [.] [.] [.][PL][.][D0*][PC][.][PL][.] [.] [.] [.][PL]      boss desk + flanking plants
// Row 4: [.] [.] [.] [.] [.] [.] [.] [.][C0*][.] [.] [.] [.] [.] [.] [.]   boss chair
// D0*/C0* = Boss (Claude main agent), facing up toward meeting area
// D1-D4 = Subagent desks (2 left, 2 right)
// CF = Coffee, SF = Sofa (meeting/break area in center of row 1)

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
  // Subagent desks — 2 left, 2 right (block movement)
  { type: 'desk', tile: [1, 1],  spriteKey: 'desk_front', blocksMovement: true },
  { type: 'desk', tile: [4, 1],  spriteKey: 'desk_front', blocksMovement: true },
  { type: 'desk', tile: [11, 1], spriteKey: 'desk_front', blocksMovement: true },
  { type: 'desk', tile: [14, 1], spriteKey: 'desk_front', blocksMovement: true },

  // Boss desk (center, row 3)
  { type: 'desk', tile: [7, 3],  spriteKey: 'desk_front', blocksMovement: true },

  // PCs on desks (block movement)
  { type: 'pc', tile: [2, 1],  spriteKey: 'pc_on', blocksMovement: true },
  { type: 'pc', tile: [5, 1],  spriteKey: 'pc_on', blocksMovement: true },
  { type: 'pc', tile: [12, 1], spriteKey: 'pc_on', blocksMovement: true },
  { type: 'pc', tile: [15, 1], spriteKey: 'pc_on', blocksMovement: true },
  { type: 'pc', tile: [8, 3],  spriteKey: 'pc_on', blocksMovement: true },

  // Meeting area — coffee machine + sofa (center of row 1)
  { type: 'coffee', tile: [6, 1], spriteKey: 'coffee', blocksMovement: true },
  { type: 'sofa',   tile: [9, 1], spriteKey: 'sofa_front', blocksMovement: true },

  // Plants framing boss area + corner decoration
  { type: 'plant', tile: [5, 4],  spriteKey: 'plant', blocksMovement: true },
  { type: 'plant', tile: [10, 4], spriteKey: 'plant', blocksMovement: true },
  { type: 'plant', tile: [15, 3], spriteKey: 'plant', blocksMovement: true },
];

const WANDER_TARGETS: WanderTarget[] = [
  { tile: [7, 2],  label: 'meeting' },   // corridor in front of meeting area
  { tile: [3, 3],  label: 'left_hall' },  // open area left side
  { tile: [12, 3], label: 'right_hall' }, // open area right side
  { tile: [3, 4],  label: 'lounge' },     // open area bottom-left
];

export class OfficeLayout {
  readonly cols = 16;
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
}
