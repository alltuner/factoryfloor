// Manages multiple pixel agents and routes events to their state machines.

import type { AgentEvent } from '../types';
import { AgentStateMachine, toolToState } from './AgentStateMachine';
import type { AgentState } from './AgentStateMachine';
import type { Direction } from './SpriteEngine';
import type { TileMap, TileCoord } from './TileMap';
import type { OfficeLayout } from './OfficeLayout';
import { MatrixEffect } from './MatrixEffect';
import type { MatrixState } from './MatrixEffect';
import { BubbleRenderer } from './BubbleRenderer';
import type { BubbleState } from './BubbleRenderer';

export interface Agent {
  id: string;
  name: string;
  palette: number;
  stateMachine: AgentStateMachine;
  x: number;
  y: number;
  lastEventTime: number; // timestamp of last event (performance.now())
  // Tile-based positioning (only populated when TileMap/OfficeLayout are provided)
  tileX: number;
  tileY: number;
  pixelX: number;
  pixelY: number;
  path: TileCoord[] | null;
  pathIndex: number;
  targetSeat: number | null;
  walkSpeed: number; // pixels per second (default 144 = 48px * 3 zoom = 1 tile/sec)
  matrixState: MatrixState | null;
  bubbleState: BubbleState | null;
  // Phase 4: Idle behaviors
  idleTimer: number;
  idleThreshold: number;
  idleBehavior: 'headTurn' | 'fidget' | null;
  idleBehaviorTimer: number;
  idleBehaviorDuration: number;
  savedDirection: Direction | null;
  // Phase 4: Wander
  wanderState: 'going' | 'pausing' | 'returning' | null;
  wanderPauseTimer: number;
  wanderReturnTile: TileCoord | null;
  // Phase 4: Choreography
  choreographyActive: boolean;
  choreographyPhase: number; // 0 = not in choreography
  choreographyTarget: TileCoord | null;
  choreographyTimer: number;
  eventBuffer: AgentEvent[];
  parentAgentId: string | null;
  pendingSubagent: { id: string; name: string; palette?: number; parentAgentId: string } | null;
}

const AGENT_SPACING = 160;
const BASE_X = 80;
const BASE_Y = 50;
const DEFAULT_WALK_SPEED = 144; // 48px * zoom 3 = 1 tile/sec screen speed
const SAFETY_TIMEOUT_MS = 30_000; // 30 seconds without events → force idle

let nextPalette = 0;

export class AgentManager {
  private agents: Map<string, Agent> = new Map();
  private tileMap: TileMap | null;
  private layout: OfficeLayout | null;

  constructor(tileMap?: TileMap, layout?: OfficeLayout) {
    this.tileMap = tileMap ?? null;
    this.layout = layout ?? null;
  }

  createAgent(id: string, name: string, palette?: number, isBoss = false): Agent {
    if (this.agents.has(id)) {
      return this.agents.get(id)!;
    }

    const p = palette ?? nextPalette++ % 6;
    const index = this.agents.size;

    // Determine spawn position based on whether tile system is available
    let tileX = 0;
    let tileY = 0;
    let pixelX = BASE_X + index * AGENT_SPACING;
    let pixelY = BASE_Y;
    let path: TileCoord[] | null = null;
    let pathIndex = 0;
    let targetSeat: number | null = null;

    if (this.tileMap && this.layout) {
      const spawn = this.layout.spawnTile;
      tileX = spawn[0];
      tileY = spawn[1];
      const spawnPixel = this.tileMap.tileToPixel(tileX, tileY);
      pixelX = spawnPixel.x;
      pixelY = spawnPixel.y;

      // Claim a seat and compute path to it
      const seat = this.layout.claimSeat(id, isBoss);
      if (seat) {
        targetSeat = seat.id;
        const computedPath = this.tileMap.findPath(spawn, seat.chairTile);
        if (computedPath.length > 0) {
          path = computedPath;
          pathIndex = 1; // index 0 is the current position (spawn)
        }
      }
    }

    const agent: Agent = {
      id,
      name,
      palette: p,
      stateMachine: new AgentStateMachine(),
      x: pixelX,
      y: pixelY,
      lastEventTime: performance.now(),
      tileX,
      tileY,
      pixelX,
      pixelY,
      path,
      pathIndex,
      targetSeat,
      walkSpeed: DEFAULT_WALK_SPEED,
      matrixState: null,
      bubbleState: null,
      // Phase 4: Idle behaviors
      idleTimer: 0,
      idleThreshold: 5 + Math.random() * 15,
      idleBehavior: null,
      idleBehaviorTimer: 0,
      idleBehaviorDuration: 0,
      savedDirection: null,
      // Phase 4: Wander
      wanderState: null,
      wanderPauseTimer: 0,
      wanderReturnTile: null,
      // Phase 4: Choreography
      choreographyActive: false,
      choreographyPhase: 0,
      choreographyTarget: null,
      choreographyTimer: 0,
      eventBuffer: [],
      parentAgentId: null,
      pendingSubagent: null,
    };

    // If tile system is available, start with a spawn reveal effect
    if (this.tileMap) {
      agent.matrixState = MatrixEffect.createReveal();
      agent.stateMachine.transition('spawning');
    } else if (path && path.length > 1) {
      // Legacy: no tile system, start walking immediately
      agent.stateMachine.transition('walk');
    }

    this.agents.set(id, agent);
    return agent;
  }

  removeAgent(id: string): void {
    const agent = this.agents.get(id);
    if (!agent) {
      // Agent doesn't exist, just release seat
      if (this.layout) this.layout.releaseSeat(id);
      return;
    }

    if (this.tileMap && agent.stateMachine.state !== 'despawning') {
      // Start despawn animation instead of immediate removal
      agent.stateMachine.transition('despawning');
      agent.matrixState = MatrixEffect.createHide();
      agent.path = null; // Stop any walk in progress
    } else {
      // No tile system or already despawning: remove immediately
      this.forceRemoveAgent(id);
    }
  }

  private forceRemoveAgent(id: string): void {
    if (this.layout) {
      this.layout.releaseSeat(id);
    }
    this.agents.delete(id);
  }

  updateAll(dt: number): void {
    const now = performance.now();
    const toRemove: string[] = [];

    for (const agent of this.agents.values()) {
      // Matrix effect (spawn/despawn animation)
      if (agent.matrixState) {
        const active = MatrixEffect.update(agent.matrixState, dt);
        if (!active) {
          const wasType = agent.matrixState.type;
          agent.matrixState = null;
          if (wasType === 'reveal') {
            // Spawn complete: start walking to seat
            if (agent.path && agent.path.length > 1) {
              agent.stateMachine.transition('walk');
            } else {
              agent.stateMachine.transition('idle');
            }
            // Replay buffered events after spawn completes
            this.replayEventBuffer(agent);
          } else if (wasType === 'hide') {
            // Despawn complete: mark for removal
            toRemove.push(agent.id);
          }
        }
        // Skip walk/timeout processing during matrix effect
        agent.stateMachine.update(dt);
        continue;
      }

      // Choreography phase processing
      if (agent.choreographyActive && agent.choreographyPhase > 0) {
        this.updateChoreography(agent, dt);
      }

      // Wander sub-phase processing
      if (agent.wanderState) {
        this.updateWander(agent, dt);
      }

      // Walk interpolation
      if (this.tileMap && agent.path && agent.pathIndex < agent.path.length) {
        this.walkStep(agent, dt);
      }

      // Idle micro-behavior update (also runs during active micro-behaviors like fidget/headTurn)
      if ((agent.stateMachine.state === 'idle' || agent.idleBehavior !== null) && !agent.choreographyActive && !agent.wanderState) {
        this.updateIdleBehavior(agent, dt);
      }

      agent.stateMachine.update(dt);

      // Update bubble state
      if (agent.bubbleState) {
        const bubbleActive = BubbleRenderer.update(agent.bubbleState, dt);
        if (!bubbleActive) {
          agent.bubbleState = null;
        }
      }

      // Safety timeout: if agent has been non-idle for >30s without events, force idle
      // Does NOT apply to spawning/despawning/briefing/reporting states
      const nonTimeoutStates: AgentState[] = ['idle', 'walk', 'spawning', 'despawning', 'briefing', 'reporting'];
      if (
        !nonTimeoutStates.includes(agent.stateMachine.state) &&
        now - agent.lastEventTime > SAFETY_TIMEOUT_MS
      ) {
        agent.stateMachine.transition('idle');
      }
    }

    // Actually remove agents that finished despawn
    for (const id of toRemove) {
      this.forceRemoveAgent(id);
    }
  }

  private walkStep(agent: Agent, dt: number): void {
    if (!this.tileMap || !agent.path || agent.pathIndex >= agent.path.length) return;

    const target = agent.path[agent.pathIndex];
    const targetPixel = this.tileMap.tileToPixel(target[0], target[1]);
    const dx = targetPixel.x - agent.pixelX;
    const dy = targetPixel.y - agent.pixelY;
    const dist = Math.sqrt(dx * dx + dy * dy);
    const step = agent.walkSpeed * dt;

    if (step >= dist) {
      // Snap to target tile
      agent.pixelX = targetPixel.x;
      agent.pixelY = targetPixel.y;
      agent.tileX = target[0];
      agent.tileY = target[1];
      agent.x = agent.pixelX;
      agent.y = agent.pixelY;
      agent.pathIndex++;

      // Update walk direction based on movement (before checking path completion)
      if (dist > 0.01) {
        if (Math.abs(dx) > Math.abs(dy)) {
          agent.stateMachine.direction = dx > 0 ? 'right' : 'left';
        } else {
          agent.stateMachine.direction = dy > 0 ? 'down' : 'up';
        }
      }

      // Check if path is complete
      if (agent.pathIndex >= agent.path.length) {
        agent.path = null;

        // Wander: handle sub-phase transitions on path complete
        if (agent.wanderState === 'going') {
          agent.wanderState = 'pausing';
          agent.wanderPauseTimer = 2 + Math.random() * 2; // 2-4s pause
          agent.stateMachine.transition('idle'); // idle frame during pause
          return;
        }
        if (agent.wanderState === 'returning') {
          agent.wanderState = null;
          agent.wanderReturnTile = null;
          // Set facing direction from seat
          if (this.layout && agent.targetSeat !== null) {
            const seat = this.layout.getSeats().find(s => s.id === agent.targetSeat);
            if (seat) {
              agent.stateMachine.direction = seat.facing;
            }
          }
          agent.stateMachine.transition('idle');
          return;
        }

        // Choreography: handle phase transitions on path complete
        if (agent.choreographyActive && agent.choreographyPhase > 0) {
          // Don't transition to idle — choreography update handles it
          return;
        }

        // Normal walk completion: set facing direction from seat
        if (this.layout && agent.targetSeat !== null) {
          const seat = this.layout.getSeats().find(s => s.id === agent.targetSeat);
          if (seat) {
            agent.stateMachine.direction = seat.facing;
          }
        }
        agent.stateMachine.transition('idle');
      }
    } else {
      // Interpolate toward target
      agent.pixelX += (dx / dist) * step;
      agent.pixelY += (dy / dist) * step;
      agent.x = agent.pixelX;
      agent.y = agent.pixelY;

      // Update walk direction based on movement
      if (dist > 0.01) {
        if (Math.abs(dx) > Math.abs(dy)) {
          agent.stateMachine.direction = dx > 0 ? 'right' : 'left';
        } else {
          agent.stateMachine.direction = dy > 0 ? 'down' : 'up';
        }
      }
    }
  }

  // --- Phase 4: Idle micro-behaviors ---

  private updateIdleBehavior(agent: Agent, dt: number): void {
    // If an idle behavior is active, update it
    if (agent.idleBehavior) {
      agent.idleBehaviorTimer += dt;
      if (agent.idleBehaviorTimer >= agent.idleBehaviorDuration) {
        // Behavior complete: restore state
        if (agent.idleBehavior === 'headTurn' && agent.savedDirection) {
          agent.stateMachine.direction = agent.savedDirection;
        }
        if (agent.idleBehavior === 'fidget') {
          agent.stateMachine.transition('idle');
        }
        agent.idleBehavior = null;
        agent.savedDirection = null;
        agent.idleTimer = 0;
        agent.idleThreshold = 5 + Math.random() * 15;
      }
      return;
    }

    // Increment idle timer
    agent.idleTimer += dt;

    if (agent.idleTimer >= agent.idleThreshold) {
      // Time for a micro-behavior
      const roll = Math.random();
      if (roll < 0.3 && this.tileMap && this.layout) {
        // 30% chance: wander
        this.startWander(agent);
      } else if (roll < 0.65) {
        // 35% chance: head turn
        agent.idleBehavior = 'headTurn';
        agent.idleBehaviorTimer = 0;
        agent.idleBehaviorDuration = 2 + Math.random(); // 2-3s
        agent.savedDirection = agent.stateMachine.direction;
        const dirs: Direction[] = ['up', 'down', 'left', 'right'];
        const otherDirs = dirs.filter(d => d !== agent.stateMachine.direction);
        agent.stateMachine.direction = otherDirs[Math.floor(Math.random() * otherDirs.length)];
      } else {
        // 35% chance: fidget
        agent.idleBehavior = 'fidget';
        agent.idleBehaviorTimer = 0;
        agent.idleBehaviorDuration = 1 + Math.random(); // 1-2s
        agent.stateMachine.transition('wandering'); // uses walk frames for fidget
      }

      // If we didn't start wandering, reset idle timer here
      if (!agent.wanderState) {
        agent.idleTimer = 0;
      }
    }
  }

  // --- Phase 4: Wander ---

  private startWander(agent: Agent): void {
    if (!this.tileMap || !this.layout) return;

    const seatTile: TileCoord = [agent.tileX, agent.tileY];

    // Find walkable tiles within 2 Manhattan distance, or pick from wanderTargets
    const candidates: TileCoord[] = [];

    // Nearby tiles
    for (let dx = -2; dx <= 2; dx++) {
      for (let dy = -2; dy <= 2; dy++) {
        if (dx === 0 && dy === 0) continue;
        if (Math.abs(dx) + Math.abs(dy) > 2) continue;
        const tx = agent.tileX + dx;
        const ty = agent.tileY + dy;
        if (this.tileMap.isWalkable(tx, ty)) {
          candidates.push([tx, ty]);
        }
      }
    }

    // Also add nearby wander targets
    for (const wt of this.layout.wanderTargets) {
      const mdist = Math.abs(wt.tile[0] - agent.tileX) + Math.abs(wt.tile[1] - agent.tileY);
      if (mdist <= 4 && this.tileMap.isWalkable(wt.tile[0], wt.tile[1])) {
        candidates.push(wt.tile);
      }
    }

    if (candidates.length === 0) {
      // Can't wander, just reset
      agent.idleTimer = 0;
      agent.idleThreshold = 5 + Math.random() * 15;
      return;
    }

    const target = candidates[Math.floor(Math.random() * candidates.length)];
    const path = this.tileMap.findPath(seatTile, target);

    if (path.length <= 1) {
      agent.idleTimer = 0;
      agent.idleThreshold = 5 + Math.random() * 15;
      return;
    }

    agent.wanderState = 'going';
    agent.wanderReturnTile = seatTile;
    agent.path = path;
    agent.pathIndex = 1;
    agent.stateMachine.transition('wandering');
    agent.idleTimer = 0;
  }

  private updateWander(agent: Agent, dt: number): void {
    if (agent.wanderState === 'pausing') {
      agent.wanderPauseTimer -= dt;
      if (agent.wanderPauseTimer <= 0) {
        // Return to seat
        if (this.tileMap && agent.wanderReturnTile) {
          const returnPath = this.tileMap.findPath(
            [agent.tileX, agent.tileY],
            agent.wanderReturnTile,
          );
          if (returnPath.length > 1) {
            agent.wanderState = 'returning';
            agent.path = returnPath;
            agent.pathIndex = 1;
            agent.stateMachine.transition('wandering');
          } else {
            // Already at seat or no path
            agent.wanderState = null;
            agent.wanderReturnTile = null;
            agent.stateMachine.transition('idle');
          }
        } else {
          agent.wanderState = null;
          agent.wanderReturnTile = null;
          agent.stateMachine.transition('idle');
        }
      }
    }
    // 'going' and 'returning' are handled by walkStep + path completion
  }

  private interruptWander(agent: Agent): void {
    agent.wanderState = null;
    agent.path = null;
    agent.wanderPauseTimer = 0;
    // Snap back to seat
    if (this.tileMap && agent.wanderReturnTile) {
      const pixel = this.tileMap.tileToPixel(agent.wanderReturnTile[0], agent.wanderReturnTile[1]);
      agent.tileX = agent.wanderReturnTile[0];
      agent.tileY = agent.wanderReturnTile[1];
      agent.pixelX = pixel.x;
      agent.pixelY = pixel.y;
      agent.x = pixel.x;
      agent.y = pixel.y;
    }
    agent.wanderReturnTile = null;
    // Restore seat facing
    if (this.layout && agent.targetSeat !== null) {
      const seat = this.layout.getSeats().find(s => s.id === agent.targetSeat);
      if (seat) {
        agent.stateMachine.direction = seat.facing;
      }
    }
  }

  // --- Phase 4: Choreography ---

  private updateChoreography(agent: Agent, dt: number): void {
    // Parent choreography: spawn subagent sequence
    // Phase 1: walking to spawn area (handled by walkStep, check arrival)
    if (agent.choreographyPhase === 1) {
      // Walking to spawn area — wait for path completion
      if (!agent.path) {
        // Arrived at spawn area — spawn the subagent
        agent.choreographyPhase = 2;
        agent.choreographyTimer = 0;

        // Spawn the pending subagent
        if (agent.pendingSubagent) {
          const sub = agent.pendingSubagent;
          const subAgent = this.createAgent(sub.id, sub.name, sub.palette);
          subAgent.parentAgentId = sub.parentAgentId;
          agent.pendingSubagent = null;
        }

        // Show briefing bubble
        agent.stateMachine.transition('briefing');
        agent.bubbleState = BubbleRenderer.show('briefing', 1.5);
      }
    }
    // Phase 2: showing briefing bubble (wait for timer)
    else if (agent.choreographyPhase === 2) {
      agent.choreographyTimer += dt;
      if (agent.choreographyTimer >= 1.5) {
        // Walk back to seat
        agent.choreographyPhase = 3;
        if (this.tileMap && this.layout && agent.targetSeat !== null) {
          const seat = this.layout.getSeats().find(s => s.id === agent.targetSeat);
          if (seat) {
            const returnPath = this.tileMap.findPath(
              [agent.tileX, agent.tileY],
              seat.chairTile,
            );
            if (returnPath.length > 1) {
              agent.path = returnPath;
              agent.pathIndex = 1;
              agent.stateMachine.transition('walk');
            } else {
              // Already at seat
              agent.choreographyPhase = 0;
              agent.choreographyActive = false;
              agent.stateMachine.transition('idle');
              this.replayEventBuffer(agent);
            }
          }
        } else {
          agent.choreographyPhase = 0;
          agent.choreographyActive = false;
          agent.stateMachine.transition('idle');
          this.replayEventBuffer(agent);
        }
      }
    }
    // Phase 3: walking back to seat (handled by walkStep, check arrival)
    else if (agent.choreographyPhase === 3) {
      if (!agent.path) {
        // Arrived back at seat
        agent.choreographyPhase = 0;
        agent.choreographyActive = false;
        // Set facing direction from seat
        if (this.layout && agent.targetSeat !== null) {
          const seat = this.layout.getSeats().find(s => s.id === agent.targetSeat);
          if (seat) {
            agent.stateMachine.direction = seat.facing;
          }
        }
        agent.stateMachine.transition('idle');
        this.replayEventBuffer(agent);
      }
    }

    // Subagent reporting choreography
    // Phase 10: walking to parent (handled by walkStep)
    else if (agent.choreographyPhase === 10) {
      if (!agent.path) {
        // Arrived near parent — show reporting bubble
        agent.choreographyPhase = 11;
        agent.choreographyTimer = 0;
        agent.stateMachine.transition('reporting');
        agent.bubbleState = BubbleRenderer.show('reporting', 1.5);
      }
    }
    // Phase 11: showing reporting bubble
    else if (agent.choreographyPhase === 11) {
      agent.choreographyTimer += dt;
      if (agent.choreographyTimer >= 1.5) {
        // Start despawn
        agent.choreographyPhase = 12;
        agent.stateMachine.transition('despawning');
        agent.matrixState = MatrixEffect.createHide();
        agent.path = null;
      }
    }
    // Phase 12: despawning (handled by matrix effect in main loop)
  }

  private startSubagentSpawnChoreography(parentAgent: Agent, subagentInfo: { id: string; name: string; palette?: number; parentAgentId: string }): void {
    parentAgent.choreographyActive = true;
    parentAgent.choreographyPhase = 1;
    parentAgent.choreographyTimer = 0;
    parentAgent.pendingSubagent = subagentInfo;

    // Walk parent to spawn tile area
    if (this.tileMap && this.layout) {
      const spawnTile = this.layout.spawnTile;
      // Walk to a tile adjacent to spawn (1 tile away)
      const adjacentTile: TileCoord = [spawnTile[0] + 1, spawnTile[1]];
      const walkable = this.tileMap.isWalkable(adjacentTile[0], adjacentTile[1]) ? adjacentTile : spawnTile;
      const path = this.tileMap.findPath([parentAgent.tileX, parentAgent.tileY], walkable);
      if (path.length > 1) {
        parentAgent.path = path;
        parentAgent.pathIndex = 1;
        parentAgent.stateMachine.transition('walk');
        parentAgent.choreographyTarget = walkable;
      } else {
        // Already near spawn, go directly to phase 2
        parentAgent.choreographyPhase = 2;
        parentAgent.choreographyTimer = 0;
        // Spawn subagent immediately
        const subAgent = this.createAgent(subagentInfo.id, subagentInfo.name, subagentInfo.palette);
        subAgent.parentAgentId = subagentInfo.parentAgentId;
        parentAgent.pendingSubagent = null;
        parentAgent.stateMachine.transition('briefing');
        parentAgent.bubbleState = BubbleRenderer.show('briefing', 1.5);
      }
    }
  }

  private startSubagentDespawnChoreography(subagent: Agent): void {
    const parentAgent = subagent.parentAgentId ? this.agents.get(subagent.parentAgentId) : null;

    subagent.choreographyActive = true;

    if (parentAgent && this.tileMap) {
      // Walk toward parent's seat (adjacent tile)
      const parentSeat = this.layout?.getSeat(parentAgent.id);
      if (parentSeat) {
        // Find an adjacent walkable tile to parent's chair
        const pTile = parentSeat.chairTile;
        const adjacents: TileCoord[] = [[pTile[0]-1, pTile[1]], [pTile[0]+1, pTile[1]], [pTile[0], pTile[1]-1], [pTile[0], pTile[1]+1]];
        let targetTile: TileCoord | null = null;
        for (const adj of adjacents) {
          if (this.tileMap.isWalkable(adj[0], adj[1])) {
            targetTile = adj;
            break;
          }
        }

        if (targetTile) {
          const path = this.tileMap.findPath([subagent.tileX, subagent.tileY], targetTile);
          if (path.length > 1) {
            subagent.choreographyPhase = 10;
            subagent.path = path;
            subagent.pathIndex = 1;
            subagent.stateMachine.transition('walk');
            return;
          }
        }
      }
    }

    // Parent doesn't exist or no path: despawn at current position
    subagent.choreographyPhase = 11;
    subagent.choreographyTimer = 0;
    subagent.stateMachine.transition('reporting');
    subagent.bubbleState = BubbleRenderer.show('reporting', 1.5);
  }

  private replayEventBuffer(agent: Agent): void {
    if (agent.eventBuffer.length === 0) return;
    const events = agent.eventBuffer.splice(0);
    for (const event of events) {
      this.applyToolEvent(agent, event);
    }
  }

  private applyToolEvent(agent: Agent, event: AgentEvent): void {
    switch (event.type) {
      case 'agentToolStart': {
        agent.lastEventTime = performance.now();
        agent.idleTimer = 0;
        if (event.tool) {
          const newState: AgentState = toolToState(event.tool);
          agent.stateMachine.transition(newState);
          agent.bubbleState = BubbleRenderer.show(
            event.error ? 'error' : BubbleRenderer.iconForTool(event.tool),
          );
        }
        break;
      }
      case 'agentToolDone': {
        agent.lastEventTime = performance.now();
        agent.idleTimer = 0;
        agent.stateMachine.transition('idle');
        agent.bubbleState = BubbleRenderer.show(event.error ? 'error' : 'done', 1.5);
        break;
      }
      case 'agentWaiting': {
        agent.lastEventTime = performance.now();
        agent.idleTimer = 0;
        agent.stateMachine.transition('wait');
        agent.bubbleState = BubbleRenderer.show('wait');
        break;
      }
    }
  }

  private isNonInterruptible(agent: Agent): boolean {
    return (
      agent.choreographyActive ||
      agent.stateMachine.state === 'spawning' ||
      agent.stateMachine.state === 'despawning'
    );
  }

  getAgents(): Agent[] {
    return Array.from(this.agents.values()).sort((a, b) => {
      // When tile system is available, sort by tileY then tileX for stability
      if (this.tileMap) {
        if (a.tileY !== b.tileY) return a.tileY - b.tileY;
        return a.tileX - b.tileX;
      }
      // Legacy: sort by pixel y
      return a.y - b.y;
    });
  }

  getAgent(id: string): Agent | undefined {
    return this.agents.get(id);
  }

  get size(): number {
    return this.agents.size;
  }

  handleEvent(event: AgentEvent): void {
    switch (event.type) {
      case 'agentCreated': {
        if (event.parentAgentId) {
          // Subagent creation: trigger choreography on parent
          const parent = this.agents.get(event.parentAgentId);
          if (parent && !parent.choreographyActive) {
            this.startSubagentSpawnChoreography(parent, {
              id: event.agentId,
              name: event.name ?? 'Agent',
              palette: event.palette,
              parentAgentId: event.parentAgentId,
            });
          } else {
            // Parent busy or doesn't exist: create subagent directly
            const subAgent = this.createAgent(event.agentId, event.name ?? 'Agent', event.palette);
            subAgent.parentAgentId = event.parentAgentId;
          }
        } else {
          // Main agent: reserve boss seat
          this.createAgent(event.agentId, event.name ?? 'Agent', event.palette, true);
        }
        break;
      }
      case 'agentRemoved': {
        const agent = this.agents.get(event.agentId);
        if (agent && agent.parentAgentId && this.tileMap) {
          // Subagent removal: trigger reporting choreography
          this.startSubagentDespawnChoreography(agent);
        } else {
          this.removeAgent(event.agentId);
        }
        break;
      }
      case 'agentToolStart': {
        // Auto-create agent if it doesn't exist yet (hook events may arrive before agentCreated)
        let agent = this.agents.get(event.agentId);
        if (!agent) {
          const bossTaken = this.layout?.getSeats().some(s => s.isBoss && s.occupied) ?? false;
          agent = this.createAgent(event.agentId, event.name ?? event.agentId, event.palette, !bossTaken);
        }

        // Event buffering: non-interruptible states buffer events
        if (this.isNonInterruptible(agent)) {
          agent.eventBuffer.push(event);
          return;
        }

        // Interruptible wander: snap back to seat, apply immediately
        if (agent.wanderState) {
          this.interruptWander(agent);
        }

        agent.lastEventTime = performance.now();
        agent.idleTimer = 0;
        if (event.tool) {
          const newState: AgentState = toolToState(event.tool);
          agent.stateMachine.transition(newState);
          agent.bubbleState = BubbleRenderer.show(
            event.error ? 'error' : BubbleRenderer.iconForTool(event.tool),
          );
        }
        break;
      }
      case 'agentToolDone': {
        const agent = this.agents.get(event.agentId);
        if (agent) {
          if (this.isNonInterruptible(agent)) {
            agent.eventBuffer.push(event);
            return;
          }
          if (agent.wanderState) {
            this.interruptWander(agent);
          }
          agent.lastEventTime = performance.now();
          agent.idleTimer = 0;
          agent.stateMachine.transition('idle');
          agent.bubbleState = BubbleRenderer.show(event.error ? 'error' : 'done', 1.5);
        }
        break;
      }
      case 'agentIdle': {
        const agent = this.agents.get(event.agentId);
        if (agent) {
          agent.lastEventTime = performance.now();
          agent.idleTimer = 0;
          agent.stateMachine.transition('idle');
        }
        break;
      }
      case 'agentWaiting': {
        // Auto-create agent if it doesn't exist yet (same pattern as agentToolStart)
        let agent = this.agents.get(event.agentId);
        if (!agent) {
          const bossTaken = this.layout?.getSeats().some(s => s.isBoss && s.occupied) ?? false;
          agent = this.createAgent(event.agentId, event.name ?? event.agentId, event.palette, !bossTaken);
        }

        if (this.isNonInterruptible(agent)) {
          agent.eventBuffer.push(event);
          return;
        }
        if (agent.wanderState) {
          this.interruptWander(agent);
        }

        agent.lastEventTime = performance.now();
        agent.idleTimer = 0;
        agent.stateMachine.transition('wait');
        agent.bubbleState = BubbleRenderer.show('wait');
        break;
      }
      case 'agentStatus': {
        // Could be used for walk or other status updates in the future.
        const agent = this.agents.get(event.agentId);
        if (agent && event.status === 'walking') {
          agent.stateMachine.transition('walk');
        }
        break;
      }
      case 'setupProgress': {
        const SETUP_ID = '__setup__';
        if (event.done) {
          const agent = this.agents.get(SETUP_ID);
          if (agent) {
            agent.stateMachine.transition('walk');
            setTimeout(() => this.removeAgent(SETUP_ID), 1500);
          }
        } else {
          if (!this.agents.has(SETUP_ID)) {
            this.createAgent(SETUP_ID, 'Setup', 3);
          }
          const agent = this.agents.get(SETUP_ID)!;
          // Alternate between type and read to look busy
          const state = (event.progress ?? 0) > 0.5 ? 'read' : 'type';
          agent.stateMachine.transition(state);
        }
        break;
      }
    }
  }
}

// Export Direction and AgentState for convenience
export type { Direction, AgentState };
