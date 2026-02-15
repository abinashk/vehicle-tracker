import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';

/// Plays distinct audio alerts for speeding and overstay violations.
///
/// Uses a platform channel to trigger native audio playback,
/// ensuring the sound is loud enough for outdoor/road environments.
class AudioAlertService {
  AudioAlertService({MethodChannel? channel})
      : _channel =
            channel ?? const MethodChannel('com.bnp.vehicletracker/audio');

  final MethodChannel _channel;

  /// Asset paths for violation sounds.
  static const String speedingSound = 'assets/sounds/speeding_alert.mp3';
  static const String overstaySound = 'assets/sounds/overstay_alert.mp3';

  bool _isPlaying = false;

  /// Whether an alert is currently playing.
  bool get isPlaying => _isPlaying;

  /// Play the appropriate alert sound for the given violation type.
  ///
  /// Uses distinct sounds: a rapid high-pitched tone for speeding,
  /// and a lower sustained tone for overstay.
  Future<void> playViolationAlert(ViolationType type) async {
    if (_isPlaying) return;

    final soundAsset = switch (type) {
      ViolationType.speeding => speedingSound,
      ViolationType.overstay => overstaySound,
    };

    _isPlaying = true;
    try {
      await _channel.invokeMethod<void>('playAlert', {
        'asset': soundAsset,
        'volume': 1.0,
      });
    } on PlatformException {
      // If native playback fails, fall back to system sound.
      await _playSystemSound();
    } finally {
      _isPlaying = false;
    }
  }

  /// Stop any currently playing alert.
  Future<void> stopAlert() async {
    try {
      await _channel.invokeMethod<void>('stopAlert');
    } on PlatformException {
      // Ignore errors when stopping.
    }
    _isPlaying = false;
  }

  /// Fallback: play a system beep sound.
  Future<void> _playSystemSound() async {
    await SystemSound.play(SystemSoundType.alert);
  }
}

/// Provider for the audio alert service.
final audioAlertServiceProvider = Provider<AudioAlertService>((ref) {
  return AudioAlertService();
});
