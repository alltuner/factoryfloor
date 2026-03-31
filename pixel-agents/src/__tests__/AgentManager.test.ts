import { describe, it, expect, beforeEach } from 'vitest';
import { AgentManager } from '../engine/AgentManager';
import type { AgentEvent } from '../types';

describe('AgentManager', () => {
  let manager: AgentManager;

  beforeEach(() => {
    manager = new AgentManager();
  });

  describe('createAgent / removeAgent', () => {
    it('creates an agent and adds it to the collection', () => {
      const agent = manager.createAgent('a1', 'Alice');
      expect(manager.size).toBe(1);
      expect(agent.id).toBe('a1');
      expect(agent.name).toBe('Alice');
    });

    it('returns existing agent if id already exists', () => {
      const first = manager.createAgent('a1', 'Alice');
      const second = manager.createAgent('a1', 'Bob');
      expect(first).toBe(second);
      expect(manager.size).toBe(1);
    });

    it('removes an agent', () => {
      manager.createAgent('a1', 'Alice');
      expect(manager.size).toBe(1);

      manager.removeAgent('a1');
      expect(manager.size).toBe(0);
      expect(manager.getAgent('a1')).toBeUndefined();
    });

    it('removeAgent is a no-op for unknown id', () => {
      manager.removeAgent('nonexistent');
      expect(manager.size).toBe(0);
    });
  });

  describe('auto-palette assignment', () => {
    it('assigns unique palettes to different agents', () => {
      const a1 = manager.createAgent('a1', 'Alice');
      const a2 = manager.createAgent('a2', 'Bob');
      const a3 = manager.createAgent('a3', 'Charlie');

      const palettes = [a1.palette, a2.palette, a3.palette];
      // All palettes should be distinct
      expect(new Set(palettes).size).toBe(3);
    });

    it('respects explicit palette override', () => {
      const agent = manager.createAgent('a1', 'Alice', 5);
      expect(agent.palette).toBe(5);
    });
  });

  describe('getAgents', () => {
    it('returns agents sorted by y position', () => {
      const a1 = manager.createAgent('a1', 'Alice');
      const a2 = manager.createAgent('a2', 'Bob');
      a1.y = 200;
      a2.y = 50;

      const sorted = manager.getAgents();
      expect(sorted[0].id).toBe('a2');
      expect(sorted[1].id).toBe('a1');
    });
  });

  describe('handleEvent — event routing', () => {
    it('routes agentCreated event to create an agent', () => {
      const event: AgentEvent = {
        type: 'agentCreated',
        agentId: 'a1',
        name: 'Alice',
        palette: 2,
      };
      manager.handleEvent(event);

      expect(manager.size).toBe(1);
      const agent = manager.getAgent('a1');
      expect(agent).toBeDefined();
      expect(agent!.name).toBe('Alice');
      expect(agent!.palette).toBe(2);
    });

    it('routes agentRemoved event to remove an agent', () => {
      manager.createAgent('a1', 'Alice');
      manager.handleEvent({ type: 'agentRemoved', agentId: 'a1' });
      expect(manager.size).toBe(0);
    });

    it('routes agentToolStart event to transition state machine', () => {
      manager.createAgent('a1', 'Alice');
      manager.handleEvent({
        type: 'agentToolStart',
        agentId: 'a1',
        tool: 'Edit',
      });

      const agent = manager.getAgent('a1');
      expect(agent!.stateMachine.state).toBe('type');
    });

    it('routes agentToolDone event to schedule idle', () => {
      manager.createAgent('a1', 'Alice');
      manager.handleEvent({
        type: 'agentToolStart',
        agentId: 'a1',
        tool: 'Grep',
      });

      const agent = manager.getAgent('a1');
      expect(agent!.stateMachine.state).toBe('read');

      manager.handleEvent({ type: 'agentToolDone', agentId: 'a1' });

      // After enough time, agent returns to idle
      agent!.stateMachine.update(1.0);
      expect(agent!.stateMachine.state).toBe('idle');
    });

    it('routes agentStatus "walking" event to walk state', () => {
      manager.createAgent('a1', 'Alice');
      manager.handleEvent({
        type: 'agentStatus',
        agentId: 'a1',
        status: 'walking',
      });

      const agent = manager.getAgent('a1');
      expect(agent!.stateMachine.state).toBe('walk');
    });

    it('ignores events for unknown agent ids', () => {
      // Should not throw
      manager.handleEvent({
        type: 'agentToolStart',
        agentId: 'unknown',
        tool: 'Edit',
      });
      expect(manager.size).toBe(0);
    });
  });

  describe('updateAll', () => {
    it('updates all agent state machines', () => {
      manager.createAgent('a1', 'Alice');
      manager.createAgent('a2', 'Bob');

      const a1 = manager.getAgent('a1')!;
      const a2 = manager.getAgent('a2')!;

      a1.stateMachine.transition('type');
      a2.stateMachine.transition('walk');

      // Both should advance frames after update
      manager.updateAll(0.3);

      // type: frames [3,4] at 0.3s -> one advance -> frame 4
      expect(a1.stateMachine.getCurrentFrame()).toBe(4);
      // walk: frames [0,1,2,1] at 0.15s -> 0.3s in one update call = 1 advance -> frame 1
      expect(a2.stateMachine.getCurrentFrame()).toBe(1);
    });
  });
});
