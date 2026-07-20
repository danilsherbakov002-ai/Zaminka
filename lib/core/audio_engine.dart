import 'dart:async';
import 'package:just_audio/just_audio.dart';

/// Пресеты 5-полосного эквалайзера (значения в дБ, порядок: 60/250/1k/4k/12k Гц).
const Map<String, List<double>> eqPresets = {
  'flat': [0, 0, 0, 0, 0],
  'bassBoost': [6, 4, 0, -1, -2], // Басс-буст
  'vocal': [-2, 0, 4, 3, 1], // Вокал
  'acoustic': [2, 1, 0, 2, 3], // Акустика
};

/// DSP-движок Direx поверх just_audio.
///
/// Эквалайзер использует нативный ExoPlayer-эффект [AndroidEqualizer]
/// (доступен на Android; на iOS just_audio не даёт доступа к параметрическому
/// EQ без platform-канала).
///
/// "Пространственный" эффект реализован как приближение через
/// [AndroidLoudnessEnhancer] + плавное затухание/усиление громкости.
class AudioEngine {
  final AndroidEqualizer _equalizer = AndroidEqualizer();
  final AndroidLoudnessEnhancer _loudnessEnhancer = AndroidLoudnessEnhancer();

  late final AudioPlayer _player = AudioPlayer(
    audioPipeline: AudioPipeline(
      androidAudioEffects: [_loudnessEnhancer, _equalizer],
    ),
  );

  AudioPlayer? _nextPlayer; // для кроссфейда

  double _spatialDepth = 0.0;
  Timer? _spatialTimer;

  AudioPlayer get player => _player;

  Future<void> init() async {
    await _loudnessEnhancer.setEnabled(true);
    await _equalizer.setEnabled(true);
  }

  Future<void> loadTrack(String uriOrPath) async {
    await _player.setAudioSource(AudioSource.uri(Uri.parse(uriOrPath)));
  }

  Future<void> play() => _player.play();
  Future<void> pause() => _player.pause();

  /// Установка гейна одной полосы EQ (index: 0..4, gainDb: -12..12).
  Future<void> setEQBand(int index, double gainDb) async {
    final params = await _equalizer.parameters;
    if (index < 0 || index >= params.bands.length) return;
    final band = params.bands[index];
    final clamped = gainDb.clamp(params.minDecibels, params.maxDecibels);
    await band.setGain(clamped);
  }

  Future<void> applyPreset(String name) async {
    final gains = eqPresets[name];
    if (gains == null) return;
    final params = await _equalizer.parameters;
    final bandCount = params.bands.length;
    for (int i = 0; i < bandCount && i < gains.length; i++) {
      await setEQBand(i, gains[i]);
    }
  }

  /// Плавная регулировка "presence": 0 = плоско, 1 = максимальный эффект.
  void setSpatialDepth(double value) {
    _spatialDepth = value.clamp(0.0, 1.0);
    _loudnessEnhancer.setTargetGain(_spatialDepth * 6.0); // до +6 дБ presence

    _spatialTimer?.cancel();
    if (_spatialDepth > 0.05) {
      _spatialTimer = Timer.periodic(const Duration(milliseconds: 900), (_) {
        final wobble = 1.0 - (_spatialDepth * 0.04);
        _player.setVolume(wobble);
        Future.delayed(const Duration(milliseconds: 450), () {
          _player.setVolume(1.0);
        });
      });
    }
  }

  /// Бесшовный кроссфейд на следующий трек.
  Future<void> crossfadeTo(String nextUri, {Duration duration = const Duration(seconds: 3)}) async {
    _nextPlayer = AudioPlayer();
    await _nextPlayer!.setAudioSource(AudioSource.uri(Uri.parse(nextUri)));
    await _nextPlayer!.setVolume(0);
    await _nextPlayer!.play();

    const steps = 30;
    final stepDuration = duration ~/ steps;
    for (int i = 1; i <= steps; i++) {
      await Future.delayed(stepDuration);
      final t = i / steps;
      await _player.setVolume(1 - t);
      await _nextPlayer!.setVolume(t);
    }

    await _player.stop();
  }

  Future<void> dispose() async {
    _spatialTimer?.cancel();
    await _player.dispose();
    await _nextPlayer?.dispose();
  }
}
