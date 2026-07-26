// lib/presentation/features/home/sections/countdown_text.dart

import 'dart:async';

import 'package:flutter/material.dart';

/// Ticking "ends in HH:MM:SS" label for time-boxed sections.
///
/// Rebuilds only itself — a countdown inside a section widget would otherwise
/// rebuild the whole rail, including its images, once a second.
class CountdownText extends StatefulWidget {
  final DateTime endsAt;
  final TextStyle? style;

  /// Called once when the deadline passes, so the parent can drop the section.
  final VoidCallback? onExpired;

  const CountdownText({
    super.key,
    required this.endsAt,
    this.style,
    this.onExpired,
  });

  @override
  State<CountdownText> createState() => _CountdownTextState();
}

class _CountdownTextState extends State<CountdownText> {
  Timer? _timer;
  late Duration _remaining;
  bool _notified = false;

  @override
  void initState() {
    super.initState();
    _remaining = _remainingNow();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  @override
  void didUpdateWidget(covariant CountdownText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.endsAt != widget.endsAt) {
      _notified = false;
      setState(() => _remaining = _remainingNow());
    }
  }

  Duration _remainingNow() {
    final left = widget.endsAt.difference(DateTime.now());
    return left.isNegative ? Duration.zero : left;
  }

  void _tick() {
    if (!mounted) return;
    final remaining = _remainingNow();
    setState(() => _remaining = remaining);

    if (remaining == Duration.zero && !_notified) {
      _notified = true;
      _timer?.cancel();
      widget.onExpired?.call();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String get _label {
    final d = _remaining;
    final days = d.inDays;
    final hours = d.inHours % 24;
    final minutes = d.inMinutes % 60;
    final seconds = d.inSeconds % 60;

    two(int v) => v.toString().padLeft(2, '0');

    // Past a day the seconds are noise; under it they are the urgency.
    if (days > 0) return '${days}d ${two(hours)}h ${two(minutes)}m';
    return '${two(hours)}:${two(minutes)}:${two(seconds)}';
  }

  @override
  Widget build(BuildContext context) => Text(_label, style: widget.style);
}
