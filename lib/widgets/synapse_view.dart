
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/neuro_metrics.dart';

class SynapseView extends StatefulWidget {
  final NeuroMetrics? metrics;

  const SynapseView({
    super.key,
    this.metrics,
  });

  @override
  State<SynapseView> createState() => _SynapseViewState();
}

class _SynapseViewState extends State<SynapseView> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _updateController();
  }

  @override
  void didUpdateWidget(SynapseView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateController();
  }

  void _updateController() {
    double speedFactor = 1.0;
    if (widget.metrics != null) {
      // Intensity 0-100 -> Speed 0.5 - 3.0
      speedFactor = 0.5 + (widget.metrics!.intensity / 100 * 2.5);
    }

    // Safety clamp
    if (speedFactor < 0.1) speedFactor = 0.1;

    final newDuration = Duration(milliseconds: (2000 / speedFactor).round());
    if (_controller.duration != newDuration) {
      _controller.duration = newDuration;
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color _determineColor() {
    if (widget.metrics == null) return Colors.cyan;
    final m = widget.metrics!;

    // "Scope > 80 && Mode < 40" -> Architect Mode Trigger (Purple)
    // Actually Mode > X is usually architect, but prompt says "Scope > 80, Mode < 40".
    // Wait, prompt: "Scope > 80, Mode < 40 등" -> Example of thresholds.
    // Usually Architect is high-level.
    // If Scope is High (Macro) and Mode is Low (Passive?), maybe that means "Observing Big Picture".
    // Or maybe Mode < 40 is Architect?
    // Let's stick to the prompt's implied logic for color triggers.
    // Let's use:
    // Scope > 80 (Macro) -> Purple (Architectural View)
    // Intensity > 80 -> Red (High Alert)
    // Else -> Cyan/Blue (Normal)

    if (m.scope > 80) return Colors.purpleAccent;
    if (m.intensity > 80) return Colors.redAccent;
    return Colors.cyan;
  }

  @override
  Widget build(BuildContext context) {
    final baseColor = _determineColor();

    return Center(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Container(
            width: 150 + (_controller.value * 20),
            height: 150 + (_controller.value * 20),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: baseColor.withOpacity(0.2 * _controller.value),
              boxShadow: [
                BoxShadow(
                  color: baseColor.withOpacity(0.5),
                  blurRadius: 20 * _controller.value,
                  spreadRadius: 5 * _controller.value,
                ),
              ],
            ),
          );
        },
      ),
    ).animate().fadeIn(duration: 800.ms);
  }
}
