import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Круглый тактильный регулятор в стиле Neo-Tactile.
/// value: 0..1. Вращается на 270° (-135°..+135°), управляется вертикальным drag.
class Knob extends StatefulWidget {
  final String label;
  final double value;
  final ValueChanged<double> onChanged;
  final double size;

  const Knob({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.size = 72,
  });

  @override
  State<Knob> createState() => _KnobState();
}

class _KnobState extends State<Knob> {
  late double _value = widget.value;

  void _handleDrag(DragUpdateDetails details) {
    setState(() {
      final delta = -details.delta.dy / 150;
      _value = (_value + delta).clamp(0.0, 1.0);
    });
    widget.onChanged(_value);
  }

  @override
  Widget build(BuildContext context) {
    final angle = (_value * 270 - 135) * math.pi / 180;

    return Column(
      children: [
        GestureDetector(
          onVerticalDragUpdate: _handleDrag,
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.06),
              border: Border.all(color: Colors.white.withOpacity(0.15)),
            ),
            child: Transform.rotate(
              angle: angle,
              child: Align(
                alignment: const Alignment(0, -0.8),
                child: Container(
                  width: 3,
                  height: widget.size * 0.2,
                  decoration: BoxDecoration(
                    color: const Color(0xFF5CE1E6),
                    borderRadius: BorderRadius.circular(2),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF5CE1E6).withOpacity(0.6),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          widget.label,
          style: const TextStyle(color: Color(0xFFAAAAAA), fontSize: 12, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}
