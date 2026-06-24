// robot.game.sound.js

const SoundSystem = (function() {
  let audioCtx = null;

  // Timestamps to track the last time a sound was played
  const lastPlayed = {
    "fire": 0,
    "explosion": 0 // Example for future sounds
  };

  // Delays (in milliseconds) to prevent overwhelming the output
  const delays = {
    "fire": 80,      // Rapid fire allows a short delay
    "explosion": 300 // Longer delay for bigger sounds
  };

  // Lazy initialization of the AudioContext (browsers require user interaction first)
  function initCtx() {
    if (!audioCtx) {
      audioCtx = new (window.AudioContext || window.webkitAudioContext)();
    }
    if (audioCtx.state === 'suspended') {
      audioCtx.resume();
    }
  }

  // --------------------------------------------------
  // PRIVATE GATING METHOD
  // --------------------------------------------------
  function _gateSound(soundName) {
    const now = Date.now();
    const delay = delays[soundName] || 100;
    const last = lastPlayed[soundName] || 0;

    // Only play if enough time has passed since the last trigger
    if (now - last > delay) {
      lastPlayed[soundName] = now;

      // if-else if-else structure for literal strings as requested
      if (soundName === "fire") {
        _fire();
      } else if (soundName === "explosion") {
        // _explosion(); // Future integration
      } else {
        console.warn("Unknown sound type:", soundName);
      }
    }
  }

  // --------------------------------------------------
  // PRIVATE ACTUAL SOUND METHODS
  // --------------------------------------------------
  function _fire() {
    initCtx();

    const osc = audioCtx.createOscillator();
    const gain = audioCtx.createGain();

    osc.connect(gain);
    gain.connect(audioCtx.destination);

    // Create a retro "pew" laser sound using a square wave and pitch drop
    osc.type = 'square';
    osc.frequency.setValueAtTime(600, audioCtx.currentTime);
    osc.frequency.exponentialRampToValueAtTime(100, audioCtx.currentTime + 0.1);

    // Keep volume low and create a quick fade-out
    gain.gain.setValueAtTime(0.05, audioCtx.currentTime);
    gain.gain.exponentialRampToValueAtTime(0.001, audioCtx.currentTime + 0.1);

    osc.start();
    osc.stop(audioCtx.currentTime + 0.1);
  }

  // --------------------------------------------------
  // PUBLIC API
  // --------------------------------------------------
  return {
    fire: function() {
      _gateSound("fire");
    }
  };
})();
