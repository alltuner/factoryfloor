// React component that hosts the pixel agents canvas and wires up the engine.

import { useEffect, useRef } from 'react';
import { SpriteEngine } from './engine/SpriteEngine';
import { AgentManager } from './engine/AgentManager';
import { OfficeRenderer } from './engine/OfficeRenderer';
import { subscribe, unsubscribe } from './vibefloorBridge';
import type { AgentEvent } from './types';

export default function PixelCanvas() {
  const canvasRef = useRef<HTMLCanvasElement>(null);

  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;

    const sprites = new SpriteEngine();
    const agentManager = new AgentManager();
    let renderer: OfficeRenderer | null = null;

    // Event handler for bridge events
    const handleEvent = (event: AgentEvent) => {
      agentManager.handleEvent(event);
    };

    // Resize handler
    const handleResize = () => {
      renderer?.resize();
    };

    // Initialize
    sprites.loadAll().then(() => {
      if (!canvas) return;
      renderer = new OfficeRenderer(canvas, sprites, agentManager);
      renderer.start();
    });

    // Subscribe to all bridge events
    subscribe('*', handleEvent);
    window.addEventListener('resize', handleResize);

    return () => {
      renderer?.stop();
      unsubscribe('*', handleEvent);
      window.removeEventListener('resize', handleResize);
    };
  }, []);

  return (
    <canvas
      ref={canvasRef}
      style={{
        display: 'block',
        width: '100%',
        height: '100%',
      }}
    />
  );
}
