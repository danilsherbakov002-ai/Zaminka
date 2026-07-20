import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Неоновый визуализатор — набор анимированных столбиков,
/// реагирующих на состояние воспроизведения.
class Visualizer extends StatefulWidget {
  final bool isPlaying;
  final int barCount;

  const Visualizer({super.key, required this.isPlaying, this.barCount = 24});

  @override
  State<Visualizer> createState() => _VisualizerState();
}

class _VisualizerState extends State<Visualizer> with TickerProviderStateMixin {
  late final List<AnimationController> _controllers;
  late final List<Animation<double>> _animations;
  final _random = math.Random();

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(widget.barCount, (i) {
      return AnimationController(
        vsync: this,
        duration: Duration(milliseconds: 350 + (i % 5) * 60),
      );
    });
    _animations = _controllers.map((c) {
      final target = 8 + _random.nextDouble() * 32;
      return Tween<double>(begin: 4, end: target).animate(
        CurvedAnimation(parent: c, curve: Curves.easeInOut),
      );
    }).toList();

    if (widget.isPlaying) _startAll();
  }

  void _startAll() {
    for (final c in _controllers) {
      c.repeat(reverse: true);
    }
  }

  void _stopAll() {
    for (final c in _controllers) {
      c.animateTo(0.1, duration: const Duration(milliseconds: 300));
    }
  }

  @override
  void didUpdateWidget(covariant Visualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying != oldWidget.isPlaying) {
      widget.isPlaying ? _startAll() : _stopAll();
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(widget.barCount, (i) {
          return AnimatedBuilder(
            animation: _animations[i],
            builder: (context, _) {
              return Container(
                width: 3,
                height: _animations[i].value,
                margin: const EdgeInsets.symmetric(horizontal: 1.5),
                decoration: BoxDecoration(
                  color: const Color(0xFF5CE1E6),
                  borderRadius: BorderRadius.circular(2),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF5CE1E6).withOpacity(0.7),
                      blurRadius: 6,
                    ),
                  ],
                ),
              );
            },
          );
        }),
      ),
    );
  }
}
