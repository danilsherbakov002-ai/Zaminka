import 'dart:ui';
import 'package:flutter/material.dart';
import '../core/audio_engine.dart';
import '../core/offline_cache_manager.dart';
import '../widgets/knob.dart';
import '../widgets/visualizer.dart';

const _bandLabels = ['60Hz', '250Hz', '1kHz', '4kHz', '12kHz'];

class SoundEffectsScreen extends StatefulWidget {
  final String trackId;
  final String streamUrl;

  const SoundEffectsScreen({super.key, required this.trackId, required this.streamUrl});

  @override
  State<SoundEffectsScreen> createState() => _SoundEffectsScreenState();
}

class _SoundEffectsScreenState extends State<SoundEffectsScreen> {
  final _engine = AudioEngine();
  final _cache = OfflineCacheManager();

  double _spatial = 0.3;
  List<double> _eq = List<double>.from(eqPresets['flat']!.map((g) => (g + 12) / 24));
  String _preset = 'flat';
  bool _isPlaying = true;
  CacheProgress? _cacheProgress;

  @override
  void initState() {
    super.initState();
    _setup();
  }

  Future<void> _setup() async {
    await _engine.init();
    final source = await _cache.getPlaybackSource(widget.trackId, widget.streamUrl);
    await _engine.loadTrack(source);
    await _engine.play();

    _cache.progressStream.listen((p) {
      if (p.trackId == widget.trackId && mounted) {
        setState(() => _cacheProgress = p);
      }
    });
    _cache.cacheWhilePlaying(widget.trackId, widget.streamUrl);
  }

  void _onSpatialChange(double v) {
    setState(() => _spatial = v);
    _engine.setSpatialDepth(v);
  }

  void _onEqChange(int index, double v) {
    setState(() {
      _eq[index] = v;
      _preset = 'custom';
    });
    _engine.setEQBand(index, v * 24 - 12); // -12..+12 дБ
  }

  Future<void> _applyPreset(String name) async {
    await _engine.applyPreset(name);
    setState(() {
      _eq = eqPresets[name]!.map((g) => (g + 12) / 24).toList();
      _preset = name;
    });
  }

  Future<void> _saveOffline() async {
    await _cache.saveForOffline(widget.trackId, widget.streamUrl);
  }

  @override
  void dispose() {
    _engine.dispose();
    _cache.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0B0B12), Color(0xFF14141F)],
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Text(
                'Звуковые эффекты',
                style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              _glassCard(
                child: Column(
                  children: [
                    Visualizer(isPlaying: _isPlaying),
                    if (_cacheProgress != null && !_cacheProgress!.done) ...[
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: _cacheProgress!.progress,
                          backgroundColor: Colors.white.withOpacity(0.08),
                          color: const Color(0xFF5CE1E6),
                          minHeight: 3,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _glassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionLabel('3D Presence'),
                    Center(
                      child: Knob(label: 'Depth', value: _spatial, onChanged: _onSpatialChange, size: 90),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _glassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionLabel('Эквалайзер'),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _presetChip('flat', 'Флэт'),
                        _presetChip('bassBoost', 'Басс-буст'),
                        _presetChip('vocal', 'Вокал'),
                        _presetChip('acoustic', 'Акустика'),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(_bandLabels.length, (i) {
                        return Knob(
                          label: _bandLabels[i],
                          value: _eq[i],
                          onChanged: (v) => _onEqChange(i, v),
                          size: 56,
                        );
                      }),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: _saveOffline,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFF5CE1E6).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF5CE1E6)),
                  ),
                  child: const Text(
                    'Сохранить для оффлайна',
                    style: TextStyle(color: Color(0xFF5CE1E6), fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(
          text.toUpperCase(),
          style: const TextStyle(color: Color(0xFF8A8A99), fontSize: 13, fontWeight: FontWeight.w600),
        ),
      );

  Widget _presetChip(String key, String label) {
    final active = _preset == key;
    return GestureDetector(
      onTap: () => _applyPreset(key),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF5CE1E6).withOpacity(0.15) : Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? const Color(0xFF5CE1E6) : Colors.white.withOpacity(0.1)),
        ),
        child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 13)),
      ),
    );
  }

  /// Карточка в стиле Frosted Glass (BackdropFilter + полупрозрачный фон).
  Widget _glassCard({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: child,
        ),
      ),
    );
  }
}
