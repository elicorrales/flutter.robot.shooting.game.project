// robot.game.sound.dart
// Wraps audioplayers. The original synthesized a square-wave "pew" with the Web
// Audio API; that exact sweep (600->100 Hz, 0.1s) has been pre-rendered into
// assets/pew.wav, and we play it here. The 80ms gate from the original
// SoundSystem is preserved so rapid fire doesn't spam the mixer.

import 'package:audioplayers/audioplayers.dart';

class SoundSystem {
  static final AudioPlayer _player = AudioPlayer()
    ..setPlayerMode(PlayerMode.lowLatency)
    ..setReleaseMode(ReleaseMode.stop);

  static final Map<String, int> _lastPlayed = {'fire': 0, 'explosion': 0};
  static const Map<String, int> _delays = {'fire': 80, 'explosion': 300};

  static void _gate(String name) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final delay = _delays[name] ?? 100;
    final last = _lastPlayed[name] ?? 0;

    if (now - last > delay) {
      _lastPlayed[name] = now;
      if (name == 'fire') {
        _fire();
      }
      // 'explosion' reserved for future use, like the original.
    }
  }

  static void _fire() {
    // AssetSource paths are resolved under assets/ by audioplayers, so this
    // loads assets/pew.wav.
    _player.play(AssetSource('pew.wav'));
  }

  static void fire() => _gate('fire');
}
