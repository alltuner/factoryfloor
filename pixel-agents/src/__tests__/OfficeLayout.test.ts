import { describe, it, expect, beforeEach } from 'vitest';
import { OfficeLayout } from '../engine/OfficeLayout';
import { TileMap } from '../engine/TileMap';

describe('OfficeLayout', () => {
  let layout: OfficeLayout;

  beforeEach(() => {
    layout = new OfficeLayout();
  });

  describe('constants', () => {
    it('has 16 cols, 5 rows, tileSize 16, zoom 3', () => {
      expect(layout.cols).toBe(16);
      expect(layout.rows).toBe(5);
      expect(layout.tileSize).toBe(16);
      expect(layout.zoom).toBe(3);
    });

    it('has spawnTile at [0, 2]', () => {
      expect(layout.spawnTile).toEqual([0, 2]);
    });
  });

  describe('seats', () => {
    it('has 5 seats', () => {
      const seats = layout.getSeats();
      expect(seats).toHaveLength(5);
    });

    it('each seat has id, chairTile, deskTile, pcTile, facing, isBoss', () => {
      const seats = layout.getSeats();
      for (const seat of seats) {
        expect(seat.id).toBeTypeOf('number');
        expect(seat.chairTile).toHaveLength(2);
        expect(seat.deskTile).toHaveLength(2);
        expect(seat.pcTile).toHaveLength(2);
        expect(seat.facing).toBeDefined();
        expect(seat.isBoss).toBeTypeOf('boolean');
        expect(seat.occupied).toBe(false);
        expect(seat.agentId).toBeNull();
      }
    });

    it('seat 0 is the boss seat at center position', () => {
      const seats = layout.getSeats();
      const s0 = seats[0];
      expect(s0.isBoss).toBe(true);
      expect(s0.chairTile).toEqual([8, 4]);
      expect(s0.deskTile).toEqual([7, 3]);
      expect(s0.pcTile).toEqual([8, 3]);
    });

    it('has exactly one boss seat', () => {
      const seats = layout.getSeats();
      const bossSeats = seats.filter(s => s.isBoss);
      expect(bossSeats).toHaveLength(1);
    });
  });

  describe('claimSeat / releaseSeat', () => {
    it('claimSeat with reserveBoss claims the boss seat', () => {
      const seat = layout.claimSeat('main-agent', true);
      expect(seat).not.toBeNull();
      expect(seat!.isBoss).toBe(true);
      expect(seat!.agentId).toBe('main-agent');
    });

    it('claimSeat without reserveBoss skips the boss seat', () => {
      const seat = layout.claimSeat('sub-agent');
      expect(seat).not.toBeNull();
      expect(seat!.isBoss).toBe(false);
    });

    it('claims different seats for different agents', () => {
      const s1 = layout.claimSeat('agent-1');
      const s2 = layout.claimSeat('agent-2');
      expect(s1).not.toBeNull();
      expect(s2).not.toBeNull();
      expect(s1!.id).not.toBe(s2!.id);
    });

    it('returns null when all seats are taken', () => {
      layout.claimSeat('boss', true);
      for (let i = 0; i < 4; i++) {
        layout.claimSeat(`agent-${i}`);
      }
      const result = layout.claimSeat('agent-extra');
      expect(result).toBeNull();
    });

    it('subagent falls back to boss seat if all sub seats are taken', () => {
      for (let i = 0; i < 4; i++) {
        layout.claimSeat(`agent-${i}`);
      }
      // Boss seat is still free, should fall back to it
      const seat = layout.claimSeat('agent-overflow');
      expect(seat).not.toBeNull();
      expect(seat!.isBoss).toBe(true);
    });

    it('releases a seat by agent id', () => {
      layout.claimSeat('agent-1');
      layout.releaseSeat('agent-1');
      const seats = layout.getSeats();
      const releasedSeat = seats.find(s => s.agentId === 'agent-1');
      expect(releasedSeat).toBeUndefined();
    });

    it('released seat can be claimed again', () => {
      const s1 = layout.claimSeat('agent-1');
      layout.releaseSeat('agent-1');
      const s2 = layout.claimSeat('agent-2');
      expect(s2!.id).toBe(s1!.id);
    });

    it('getSeat returns the seat for a given agent', () => {
      layout.claimSeat('agent-1');
      const seat = layout.getSeat('agent-1');
      expect(seat).not.toBeNull();
      expect(seat!.agentId).toBe('agent-1');
    });

    it('getSeat returns null for unknown agent', () => {
      expect(layout.getSeat('nobody')).toBeNull();
    });

    it('isSeatOccupied works correctly', () => {
      layout.claimSeat('agent-1');
      const seats = layout.getSeats();
      const claimed = seats.find(s => s.agentId === 'agent-1')!;
      expect(layout.isSeatOccupied(claimed.id)).toBe(true);
      expect(layout.isSeatOccupied(seats[seats.length - 1].id === claimed.id ? seats[0].id : seats[seats.length - 1].id)).toBe(false);
    });
  });

  describe('furniture', () => {
    it('has furniture items', () => {
      expect(layout.furniture.length).toBeGreaterThan(0);
    });

    it('each furniture item has type, tile, spriteKey, blocksMovement', () => {
      for (const item of layout.furniture) {
        expect(item.type).toBeDefined();
        expect(item.tile).toHaveLength(2);
        expect(item.spriteKey).toBeTypeOf('string');
        expect(item.blocksMovement).toBeTypeOf('boolean');
      }
    });

    it('has meeting area furniture (coffee and sofa)', () => {
      const coffee = layout.furniture.find(f => f.type === 'coffee');
      const sofa = layout.furniture.find(f => f.type === 'sofa');
      expect(coffee).toBeDefined();
      expect(sofa).toBeDefined();
    });
  });

  describe('initBlockedTiles', () => {
    it('blocks wall tiles and furniture that blocks movement', () => {
      const tileMap = new TileMap(layout.cols, layout.rows, layout.tileSize, layout.zoom);
      layout.initBlockedTiles(tileMap);

      // Row 0 (wall) should be blocked
      for (let c = 0; c < layout.cols; c++) {
        expect(tileMap.isWalkable(c, 0)).toBe(false);
      }

      // Desk tiles should be blocked
      const seats = layout.getSeats();
      for (const seat of seats) {
        expect(tileMap.isWalkable(seat.deskTile[0], seat.deskTile[1])).toBe(false);
      }

      // Chair tiles should be walkable (agents sit there)
      for (const seat of seats) {
        expect(tileMap.isWalkable(seat.chairTile[0], seat.chairTile[1])).toBe(true);
      }

      // Spawn tile should be walkable
      expect(tileMap.isWalkable(layout.spawnTile[0], layout.spawnTile[1])).toBe(true);
    });
  });

  describe('wanderTargets', () => {
    it('has wander targets', () => {
      expect(layout.wanderTargets.length).toBeGreaterThan(0);
    });

    it('each target has tile and label', () => {
      for (const target of layout.wanderTargets) {
        expect(target.tile).toHaveLength(2);
        expect(target.label).toBeTypeOf('string');
      }
    });

    it('all wander targets are on walkable tiles', () => {
      const tileMap = new TileMap(layout.cols, layout.rows, layout.tileSize, layout.zoom);
      layout.initBlockedTiles(tileMap);
      for (const target of layout.wanderTargets) {
        expect(
          tileMap.isWalkable(target.tile[0], target.tile[1]),
          `wander target "${target.label}" at [${target.tile}] should be walkable`,
        ).toBe(true);
      }
    });
  });

  describe('tile walkability validations', () => {
    let tileMap: TileMap;

    beforeEach(() => {
      tileMap = new TileMap(layout.cols, layout.rows, layout.tileSize, layout.zoom);
      layout.initBlockedTiles(tileMap);
    });

    it('all 5 seat chairTiles are on walkable tiles after initBlockedTiles', () => {
      const seats = layout.getSeats();
      expect(seats).toHaveLength(5);
      for (const seat of seats) {
        expect(
          tileMap.isWalkable(seat.chairTile[0], seat.chairTile[1]),
          `chair for seat ${seat.id} at [${seat.chairTile}] should be walkable`,
        ).toBe(true);
      }
    });

    it('spawnTile is walkable', () => {
      expect(tileMap.isWalkable(layout.spawnTile[0], layout.spawnTile[1])).toBe(true);
    });

    it('each seat chairTile is adjacent to at least one walkable tile', () => {
      const seats = layout.getSeats();
      const dirs: [number, number][] = [[0, -1], [1, 0], [0, 1], [-1, 0]];
      for (const seat of seats) {
        const [col, row] = seat.chairTile;
        const hasWalkableNeighbor = dirs.some(
          ([dc, dr]) => tileMap.isWalkable(col + dc, row + dr),
        );
        expect(
          hasWalkableNeighbor,
          `chair for seat ${seat.id} at [${seat.chairTile}] should have at least one walkable neighbor`,
        ).toBe(true);
      }
    });

    it('a path exists from spawnTile to each chairTile', () => {
      const seats = layout.getSeats();
      for (const seat of seats) {
        const path = tileMap.findPath(layout.spawnTile, seat.chairTile);
        expect(
          path.length,
          `path from spawn to seat ${seat.id} chair at [${seat.chairTile}] should exist`,
        ).toBeGreaterThan(0);
      }
    });

    it('a path exists from spawnTile to each wander target', () => {
      for (const target of layout.wanderTargets) {
        const path = tileMap.findPath(layout.spawnTile, target.tile);
        expect(
          path.length,
          `path from spawn to wander target "${target.label}" at [${target.tile}] should exist`,
        ).toBeGreaterThan(0);
      }
    });

    it('seat-to-PC mapping via getSeatForPc returns correct seat', () => {
      const seats = layout.getSeats();
      for (const seat of seats) {
        const found = layout.getSeatForPc(seat.pcTile[0], seat.pcTile[1]);
        expect(found).not.toBeNull();
        expect(found!.id).toBe(seat.id);
      }
    });

    it('getSeatForPc returns null for non-PC tile', () => {
      expect(layout.getSeatForPc(0, 0)).toBeNull();
    });
  });
});
