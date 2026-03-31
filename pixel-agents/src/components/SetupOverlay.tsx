import { useEffect, useState, useCallback, useRef } from 'react';
import { subscribe, unsubscribe } from '../vibefloorBridge';
import type { AgentEvent } from '../types';

interface SetupState {
  visible: boolean;
  step: string;
  progress: number;
  fadingOut: boolean;
}

const FADE_OUT_MS = 600;

export default function SetupOverlay() {
  const [state, setState] = useState<SetupState>({
    visible: false,
    step: '',
    progress: 0,
    fadingOut: false,
  });
  const fadeTimer = useRef<ReturnType<typeof setTimeout> | null>(null);

  const handleSetupProgress = useCallback((event: AgentEvent) => {
    if (event.type !== 'setupProgress') return;

    if (fadeTimer.current) {
      clearTimeout(fadeTimer.current);
      fadeTimer.current = null;
    }

    if (event.done) {
      setState((prev) => ({
        ...prev,
        step: event.step ?? prev.step,
        progress: 1,
        fadingOut: true,
      }));
      fadeTimer.current = setTimeout(() => {
        setState({ visible: false, step: '', progress: 0, fadingOut: false });
      }, FADE_OUT_MS);
    } else {
      setState({
        visible: true,
        step: event.step ?? '',
        progress: event.progress ?? 0,
        fadingOut: false,
      });
    }
  }, []);

  useEffect(() => {
    subscribe('setupProgress', handleSetupProgress);
    return () => {
      unsubscribe('setupProgress', handleSetupProgress);
      if (fadeTimer.current) clearTimeout(fadeTimer.current);
    };
  }, [handleSetupProgress]);

  if (!state.visible && !state.fadingOut) return null;

  const barWidthPercent = Math.round(state.progress * 100);

  return (
    <div style={{ ...styles.overlay, opacity: state.fadingOut ? 0 : 1 }}>
      <div style={styles.card}>
        <div style={styles.title}>SETTING UP</div>
        <div style={styles.stepText}>{state.step}</div>
        <div style={styles.barTrack}>
          <div
            style={{
              ...styles.barFill,
              width: `${barWidthPercent}%`,
            }}
          />
        </div>
        <div style={styles.percent}>{barWidthPercent}%</div>
      </div>
    </div>
  );
}

const styles: Record<string, React.CSSProperties> = {
  overlay: {
    position: 'fixed',
    inset: 0,
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: 'rgba(10, 10, 20, 0.75)',
    zIndex: 1000,
    transition: `opacity ${FADE_OUT_MS}ms ease-out`,
    imageRendering: 'pixelated',
  },
  card: {
    background: '#1a1a2e',
    border: '4px solid #e2e2e2',
    boxShadow:
      '4px 4px 0px #000, inset -2px -2px 0px #333, inset 2px 2px 0px #444',
    padding: '24px 32px',
    minWidth: 280,
    maxWidth: 360,
    textAlign: 'center' as const,
    fontFamily: '"Press Start 2P", "Courier New", monospace',
    color: '#e2e2e2',
  },
  title: {
    fontSize: 12,
    letterSpacing: 2,
    marginBottom: 16,
    color: '#7fdbca',
  },
  stepText: {
    fontSize: 9,
    marginBottom: 14,
    minHeight: 14,
    color: '#c4c4c4',
    overflow: 'hidden',
    textOverflow: 'ellipsis',
    whiteSpace: 'nowrap' as const,
  },
  barTrack: {
    height: 16,
    background: '#0a0a14',
    border: '2px solid #555',
    boxShadow: 'inset 1px 1px 0px #000',
    position: 'relative' as const,
    overflow: 'hidden',
  },
  barFill: {
    height: '100%',
    background: '#7fdbca',
    boxShadow: 'inset 0 -2px 0 rgba(0,0,0,0.25)',
    transition: 'width 0.3s ease',
  },
  percent: {
    fontSize: 8,
    marginTop: 8,
    color: '#888',
  },
};
