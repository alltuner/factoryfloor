import { describe, it, expect } from 'vitest';
import { AgentStateMachine, toolToState } from '../engine/AgentStateMachine';

describe('toolToState', () => {
  it('maps "Edit" to "type"', () => {
    expect(toolToState('Edit')).toBe('type');
  });

  it('maps "Read" to "read"', () => {
    expect(toolToState('Read')).toBe('read');
  });

  it('maps "Bash" to "type"', () => {
    expect(toolToState('Bash')).toBe('type');
  });

  it('maps "Grep" to "read"', () => {
    expect(toolToState('Grep')).toBe('read');
  });

  it('maps "Write" to "type"', () => {
    expect(toolToState('Write')).toBe('type');
  });

  it('maps "Glob" to "read"', () => {
    expect(toolToState('Glob')).toBe('read');
  });

  it('maps "WebFetch" to "read"', () => {
    expect(toolToState('WebFetch')).toBe('read');
  });

  it('maps unknown tools to "type" as default', () => {
    expect(toolToState('UnknownTool')).toBe('type');
  });
});

describe('AgentStateMachine', () => {
  it('starts in idle state', () => {
    const sm = new AgentStateMachine();
    expect(sm.state).toBe('idle');
  });

  it('starts with direction "down"', () => {
    const sm = new AgentStateMachine();
    expect(sm.direction).toBe('down');
  });

  it('getCurrentFrame returns 1 for idle (single-frame anim)', () => {
    const sm = new AgentStateMachine();
    expect(sm.getCurrentFrame()).toBe(1);
  });

  describe('transition', () => {
    it('transitions to "type" state', () => {
      const sm = new AgentStateMachine();
      sm.transition('type');
      expect(sm.state).toBe('type');
    });

    it('transitions to "read" state', () => {
      const sm = new AgentStateMachine();
      sm.transition('read');
      expect(sm.state).toBe('read');
    });

    it('transitions to "walk" state', () => {
      const sm = new AgentStateMachine();
      sm.transition('walk');
      expect(sm.state).toBe('walk');
    });

    it('sets direction to "down" for type and read states', () => {
      const sm = new AgentStateMachine();
      sm.direction = 'up';
      sm.transition('type');
      expect(sm.direction).toBe('down');

      sm.direction = 'left';
      sm.transition('read');
      expect(sm.direction).toBe('down');
    });

    it('does not change direction for walk state', () => {
      const sm = new AgentStateMachine();
      sm.direction = 'up';
      sm.transition('walk');
      expect(sm.direction).toBe('up');
    });
  });

  describe('frame cycling', () => {
    it('advances frames for "type" state (frames [3,4], duration 0.3)', () => {
      const sm = new AgentStateMachine();
      sm.transition('type');
      expect(sm.getCurrentFrame()).toBe(3); // frameIndex 0 -> frame 3

      sm.update(0.3); // triggers frame advance
      expect(sm.getCurrentFrame()).toBe(4); // frameIndex 1 -> frame 4

      sm.update(0.3); // wraps around
      expect(sm.getCurrentFrame()).toBe(3); // frameIndex 0 -> frame 3
    });

    it('advances frames for "walk" state (frames [0,1,2,1], duration 0.15)', () => {
      const sm = new AgentStateMachine();
      sm.transition('walk');
      expect(sm.getCurrentFrame()).toBe(0); // index 0

      sm.update(0.15);
      expect(sm.getCurrentFrame()).toBe(1); // index 1

      sm.update(0.15);
      expect(sm.getCurrentFrame()).toBe(2); // index 2

      sm.update(0.15);
      expect(sm.getCurrentFrame()).toBe(1); // index 3

      sm.update(0.15);
      expect(sm.getCurrentFrame()).toBe(0); // wraps to index 0
    });

    it('idle state does not advance frames (single frame)', () => {
      const sm = new AgentStateMachine();
      expect(sm.getCurrentFrame()).toBe(1);
      sm.update(5.0); // lots of time passes
      expect(sm.getCurrentFrame()).toBe(1);
    });
  });

  describe('scheduleIdle (return to idle after tool done)', () => {
    it('returns to idle after delay', () => {
      const sm = new AgentStateMachine();
      sm.transition('type');
      expect(sm.state).toBe('type');

      sm.scheduleIdle();

      // Not yet idle — delay is 0.5s
      sm.update(0.3);
      expect(sm.state).toBe('type');

      // After enough time, should be idle
      sm.update(0.3);
      expect(sm.state).toBe('idle');
    });

    it('cancels scheduled idle on new transition', () => {
      const sm = new AgentStateMachine();
      sm.transition('type');
      sm.scheduleIdle();

      sm.update(0.2);
      // Transition to a new state before idle kicks in
      sm.transition('read');
      expect(sm.state).toBe('read');

      sm.update(1.0); // well past the original delay
      expect(sm.state).toBe('read'); // should NOT have gone to idle
    });
  });
});
