import type { AgentEvent } from './types';

type EventCallback = (event: AgentEvent) => void;

type Runtime = 'vibefloor' | 'browser';

const subscribers = new Map<string, Set<EventCallback>>();

let runtime: Runtime = 'browser';

function detectRuntime(): Runtime {
  if (typeof window !== 'undefined' && window.vibefloor) {
    return 'vibefloor';
  }
  return 'browser';
}

function handleIncomingEvent(event: AgentEvent): void {
  const typeCallbacks = subscribers.get(event.type);
  if (typeCallbacks) {
    typeCallbacks.forEach((cb) => cb(event));
  }
  // Also notify wildcard subscribers
  const wildcardCallbacks = subscribers.get('*');
  if (wildcardCallbacks) {
    wildcardCallbacks.forEach((cb) => cb(event));
  }
}

function onMessage(e: MessageEvent): void {
  if (e.data && typeof e.data === 'object' && 'type' in e.data) {
    handleIncomingEvent(e.data as AgentEvent);
  }
}

/**
 * Subscribe to agent events by type.
 * Use '*' to subscribe to all event types.
 */
export function subscribe(type: string, callback: EventCallback): void {
  if (!subscribers.has(type)) {
    subscribers.set(type, new Set());
  }
  subscribers.get(type)!.add(callback);
}

/**
 * Unsubscribe a previously registered callback.
 */
export function unsubscribe(type: string, callback: EventCallback): void {
  const typeCallbacks = subscribers.get(type);
  if (typeCallbacks) {
    typeCallbacks.delete(callback);
    if (typeCallbacks.size === 0) {
      subscribers.delete(type);
    }
  }
}

/**
 * Send a message to the Swift host (no-op in browser mode).
 */
export function sendToHost(msg: unknown): void {
  if (runtime === 'vibefloor' && window.vibefloor) {
    window.vibefloor.postMessage(msg);
  } else {
    console.log('[vibefloor-bridge] sendToHost (browser mode):', msg);
  }
}

/**
 * Simulate an incoming agent event. Useful for development and testing.
 */
export function simulateEvent(event: AgentEvent): void {
  handleIncomingEvent(event);
}

/**
 * Returns the detected runtime.
 */
export function getRuntime(): Runtime {
  return runtime;
}

/**
 * Initialize the bridge. Call once at app startup.
 */
export function initBridge(): void {
  runtime = detectRuntime();
  console.log(`[vibefloor-bridge] runtime: ${runtime}`);

  if (runtime === 'vibefloor') {
    window.addEventListener('message', onMessage);
    sendToHost({ type: 'ready' });
  } else {
    // Browser/dev mode: also listen for postMessage so simulateEvent
    // can work via window.postMessage for manual testing.
    window.addEventListener('message', onMessage);
    console.log(
      '[vibefloor-bridge] browser mode -- use simulateEvent() for testing',
    );
  }
}
