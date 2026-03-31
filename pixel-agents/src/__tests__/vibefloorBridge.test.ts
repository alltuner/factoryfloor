import { describe, it, expect, vi } from 'vitest';
import {
  subscribe,
  unsubscribe,
  simulateEvent,
} from '../vibefloorBridge';
import type { AgentEvent } from '../types';

// The bridge module uses a module-level Map for subscribers.
// We need to clean up between tests by unsubscribing callbacks.

describe('vibefloorBridge', () => {
  describe('subscribe / unsubscribe', () => {
    it('subscribe adds a callback that receives matching events', () => {
      const cb = vi.fn();
      subscribe('agentCreated', cb);

      const event: AgentEvent = {
        type: 'agentCreated',
        agentId: 'a1',
        name: 'Alice',
      };
      simulateEvent(event);

      expect(cb).toHaveBeenCalledTimes(1);
      expect(cb).toHaveBeenCalledWith(event);

      // cleanup
      unsubscribe('agentCreated', cb);
    });

    it('subscribe does not fire callback for non-matching event types', () => {
      const cb = vi.fn();
      subscribe('agentRemoved', cb);

      simulateEvent({
        type: 'agentCreated',
        agentId: 'a1',
      });

      expect(cb).not.toHaveBeenCalled();

      unsubscribe('agentRemoved', cb);
    });

    it('unsubscribe removes only the specified callback', () => {
      const cb1 = vi.fn();
      const cb2 = vi.fn();
      subscribe('agentToolStart', cb1);
      subscribe('agentToolStart', cb2);

      unsubscribe('agentToolStart', cb1);

      simulateEvent({
        type: 'agentToolStart',
        agentId: 'a1',
        tool: 'Edit',
      });

      expect(cb1).not.toHaveBeenCalled();
      expect(cb2).toHaveBeenCalledTimes(1);

      unsubscribe('agentToolStart', cb2);
    });

    it('unsubscribe is a no-op for an unknown type', () => {
      const cb = vi.fn();
      // Should not throw
      unsubscribe('nonExistent', cb);
    });
  });

  describe('simulateEvent', () => {
    it('triggers correct type subscribers', () => {
      const cbCreate = vi.fn();
      const cbRemove = vi.fn();
      subscribe('agentCreated', cbCreate);
      subscribe('agentRemoved', cbRemove);

      simulateEvent({ type: 'agentCreated', agentId: 'a1' });

      expect(cbCreate).toHaveBeenCalledTimes(1);
      expect(cbRemove).not.toHaveBeenCalled();

      unsubscribe('agentCreated', cbCreate);
      unsubscribe('agentRemoved', cbRemove);
    });
  });

  describe('wildcard subscriber', () => {
    it('receives all event types', () => {
      const wildcard = vi.fn();
      subscribe('*', wildcard);

      simulateEvent({ type: 'agentCreated', agentId: 'a1' });
      simulateEvent({ type: 'agentRemoved', agentId: 'a2' });
      simulateEvent({ type: 'agentToolStart', agentId: 'a3', tool: 'Bash' });

      expect(wildcard).toHaveBeenCalledTimes(3);

      unsubscribe('*', wildcard);
    });

    it('wildcard fires alongside type-specific subscriber', () => {
      const wildcard = vi.fn();
      const specific = vi.fn();
      subscribe('*', wildcard);
      subscribe('agentToolDone', specific);

      simulateEvent({ type: 'agentToolDone', agentId: 'a1' });

      expect(wildcard).toHaveBeenCalledTimes(1);
      expect(specific).toHaveBeenCalledTimes(1);

      unsubscribe('*', wildcard);
      unsubscribe('agentToolDone', specific);
    });
  });
});
