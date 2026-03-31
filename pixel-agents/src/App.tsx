import { useEffect } from 'react';
import { initBridge, getRuntime } from './vibefloorBridge';
import { startDevMode, stopDevMode } from './devMode';
import PixelCanvas from './PixelCanvas';
import SetupOverlay from './components/SetupOverlay';

function App() {
  useEffect(() => {
    initBridge();
    if (getRuntime() === 'browser') {
      startDevMode();
    }
    return () => stopDevMode();
  }, []);

  return (
    <div
      style={{
        width: '100vw',
        height: '100vh',
        overflow: 'hidden',
        background: '#1a1a2e',
      }}
    >
      <PixelCanvas />
      <SetupOverlay />
    </div>
  );
}

export default App;
