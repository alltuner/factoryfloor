// Manages multiple pixel agents and routes events to their state machines.

import type { AgentEvent } from '../types';
import { AgentStateMachine, toolToState } from './AgentStateMachine';
import type { AgentState } from './AgentStateMachine';
import type { Direction } from './SpriteEngine';

export interface Agent {
  id: string;
  name: string;
  palette: number;
  stateMachine: AgentStateMachine;
  x: number;
  y: number;
}

const AGENT_SPACING = 80;
const BASE_X = 60;
const BASE_Y = 100;

let nextPalette = 0;

export class AgentManager {
  private agents: Map<string, Agent> = new Map();

  createAgent(id: string, name: string, palette?: number): Agent {
    if (this.agents.has(id)) {
      return this.agents.get(id)!;
    }

    const p = palette ?? nextPalette++ % 6;
    const index = this.agents.size;
    const agent: Agent = {
      id,
      name,
      palette: p,
      stateMachine: new AgentStateMachine(),
      x: BASE_X + index * AGENT_SPACING,
      y: BASE_Y,
    };
    this.agents.set(id, agent);
    return agent;
  }

  removeAgent(id: string): void {
    this.agents.delete(id);
  }

  updateAll(dt: number): void {
    for (const agent of this.agents.values()) {
      agent.stateMachine.update(dt);
    }
  }

  getAgents(): Agent[] {
    return Array.from(this.agents.values()).sort((a, b) => a.y - b.y);
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
        this.createAgent(event.agentId, event.name ?? 'Agent', event.palette);
        break;
      }
      case 'agentRemoved': {
        this.removeAgent(event.agentId);
        break;
      }
      case 'agentToolStart': {
        const agent = this.agents.get(event.agentId);
        if (agent && event.tool) {
          const newState: AgentState = toolToState(event.tool);
          agent.stateMachine.transition(newState);
        }
        break;
      }
      case 'agentToolDone': {
        const agent = this.agents.get(event.agentId);
        if (agent) {
          agent.stateMachine.scheduleIdle();
        }
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
    }
  }
}

// Export Direction and AgentState for convenience
export type { Direction, AgentState };
