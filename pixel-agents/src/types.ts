// Agent events sent from Swift to JS
export interface AgentEvent {
  type:
    | 'agentCreated'
    | 'agentRemoved'
    | 'agentStatus'
    | 'agentToolStart'
    | 'agentToolDone'
    | 'setupProgress';
  agentId: string;
  name?: string;
  palette?: number;
  status?: string;
  tool?: string;
  // setupProgress fields
  step?: string;
  progress?: number;
  done?: boolean;
}

// Window augmentation for the vibefloor bridge
declare global {
  interface Window {
    vibefloor?: {
      postMessage: (msg: unknown) => void;
    };
  }
}

export {};
