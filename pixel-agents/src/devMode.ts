import { getRuntime, simulateEvent } from './vibefloorBridge';
import type { AgentEvent } from './types';

const TOOLS = ['Read', 'Edit', 'Write', 'Bash', 'Grep', 'Glob'] as const;

const AGENT_PRESETS = [
  { name: 'Alice', palette: 0 },
  { name: 'Bob', palette: 2 },
  { name: 'Charlie', palette: 4 },
  { name: 'Diana', palette: 1 },
  { name: 'Eve', palette: 3 },
  { name: 'Frank', palette: 5 },
];

const activeAgents = new Map<string, string>(); // id -> name
const busyAgents = new Set<string>(); // agents currently using a tool

let toolCycleInterval: ReturnType<typeof setInterval> | null = null;
let agentChurnInterval: ReturnType<typeof setInterval> | null = null;
let running = false;

function randomItem<T>(arr: readonly T[]): T {
  return arr[Math.floor(Math.random() * arr.length)];
}

function randomBetween(min: number, max: number): number {
  return Math.floor(Math.random() * (max - min + 1)) + min;
}

let nextAgentId = 1;

function createAgent(name?: string, palette?: number): string {
  const id = `dev-agent-${nextAgentId++}`;
  const preset =
    name && palette !== undefined
      ? { name, palette }
      : randomItem(AGENT_PRESETS);

  activeAgents.set(id, preset.name);

  const event: AgentEvent = {
    type: 'agentCreated',
    agentId: id,
    name: preset.name,
    palette: preset.palette,
  };
  simulateEvent(event);
  console.log(`[dev-mode] created agent ${preset.name} (${id})`);
  return id;
}

function removeAgent(agentId: string): void {
  const name = activeAgents.get(agentId);
  activeAgents.delete(agentId);
  busyAgents.delete(agentId);

  simulateEvent({ type: 'agentRemoved', agentId });
  console.log(`[dev-mode] removed agent ${name ?? agentId}`);
}

function startToolCycle(): void {
  if (activeAgents.size === 0) return;

  // Pick a random non-busy agent
  const available = [...activeAgents.keys()].filter(
    (id) => !busyAgents.has(id),
  );
  if (available.length === 0) return;

  const agentId = randomItem(available);
  const tool = randomItem(TOOLS);

  busyAgents.add(agentId);
  simulateEvent({ type: 'agentToolStart', agentId, tool });

  // Complete the tool after 1-3 seconds
  const duration = randomBetween(1000, 3000);
  setTimeout(() => {
    if (!running) return;
    busyAgents.delete(agentId);
    simulateEvent({ type: 'agentToolDone', agentId, tool });

    // Occasionally send a status update after tool completes
    if (Math.random() < 0.4) {
      const status = Math.random() < 0.5 ? 'thinking' : 'idle';
      setTimeout(() => {
        if (!running || !activeAgents.has(agentId)) return;
        simulateEvent({ type: 'agentStatus', agentId, status });
      }, randomBetween(300, 800));
    }
  }, duration);
}

function agentChurn(): void {
  if (activeAgents.size <= 1) {
    // Always keep at least one agent; add one
    createAgent();
    return;
  }

  if (Math.random() < 0.5 && activeAgents.size < 5) {
    // Add an agent
    createAgent();
  } else {
    // Remove a random agent
    const ids = [...activeAgents.keys()];
    const target = randomItem(ids);
    removeAgent(target);
  }
}

/**
 * Start dev mode with mock agent simulation.
 * Only activates when runtime is 'browser'.
 */
export function startDevMode(): void {
  if (getRuntime() !== 'browser') {
    console.log('[dev-mode] skipped -- not in browser runtime');
    return;
  }

  if (running) {
    console.log('[dev-mode] already running');
    return;
  }

  running = true;
  console.log('[dev-mode] starting mock agent simulation');

  // Create initial agents with a small stagger
  const initialCount = randomBetween(2, 3);
  for (let i = 0; i < initialCount; i++) {
    const preset = AGENT_PRESETS[i];
    setTimeout(() => {
      if (!running) return;
      createAgent(preset.name, preset.palette);
    }, i * 500);
  }

  // Start tool usage cycles every 2-5 seconds
  toolCycleInterval = setInterval(
    () => startToolCycle(),
    randomBetween(2000, 5000),
  );

  // Agent churn every 30 seconds
  agentChurnInterval = setInterval(() => agentChurn(), 30_000);
}

/**
 * Stop dev mode and clean up all intervals.
 */
export function stopDevMode(): void {
  if (!running) return;

  running = false;
  console.log('[dev-mode] stopping mock agent simulation');

  if (toolCycleInterval) {
    clearInterval(toolCycleInterval);
    toolCycleInterval = null;
  }
  if (agentChurnInterval) {
    clearInterval(agentChurnInterval);
    agentChurnInterval = null;
  }

  // Remove all simulated agents
  for (const agentId of [...activeAgents.keys()]) {
    removeAgent(agentId);
  }
}
