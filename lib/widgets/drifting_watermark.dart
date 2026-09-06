import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

/// Drifting forensic watermark overlay.
/// Repositions to a new corner/edge every 20-40 seconds
/// to defeat camera photography and cropping attempts.
class DriftingWatermark extends StatefulWidget {
  final String identifier; // user's email or phone number
  final int minSeconds;
  final int maxSeconds;
  final double opacity;

  const DriftingWatermark({
    super.key,
    required this.identifier,
    this.minSeconds = 20,
    this.maxSeconds = 40,
    this.opacity = 0.15,
  });

  @override
  State<DriftingWatermark> createState() => _DriftingWatermarkState();
}

class _DriftingWatermarkState extends State<DriftingWatermark> {
  Alignment _position = Alignment.topLeft;
  Timer? _timer;
  final Random _random = Random();

  static const List<Alignment> _positions = [
    Alignment.topLeft,
    Alignment.topRight,
    Alignment.centerLeft,
    Alignment.centerRight,
    Alignment.bottomLeft,
    Alignment.bottomRight,
    Alignment.topCenter,
    Alignment.bottomCenter,
  ];

  @override
  void initState() {
    super.initState();
    _scheduleNextJump();
  }

  void _scheduleNextJump() {
    _timer?.cancel();
    final nextDurationSec = widget.minSeconds +
        _random.nextInt((widget.maxSeconds - widget.minSeconds + 1).clamp(1, 60));
    _timer = Timer(Duration(seconds: nextDurationSec), () {
      if (mounted) {
        setState(() {
          final nextPositions = List<Alignment>.from(_positions)..remove(_position);
          nextPositions.shuffle();
          _position = nextPositions.first;
        });
        _scheduleNextJump();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: true,
      child: AnimatedAlign(
        duration: const Duration(seconds: 2),
        curve: Curves.easeInOut,
        alignment: _position,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Opacity(
            opacity: widget.opacity,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.08),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                widget.identifier,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
