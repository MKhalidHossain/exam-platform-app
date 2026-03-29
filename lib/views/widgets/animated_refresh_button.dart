import 'dart:async';

import 'package:flutter/material.dart';

class AnimatedRefreshButton extends StatefulWidget {
  const AnimatedRefreshButton({
    super.key,
    required this.onPressed,
    this.size = 44,
    this.iconSize = 22,
    this.tooltip = 'Refresh',
    this.icon = Icons.refresh_rounded,
    this.foregroundColor = const Color(0xFF10213F),
    this.backgroundColor = Colors.white,
    this.borderColor = const Color(0x1A10213F),
    this.shadowColor = const Color(0x140F172A),
    this.gradient,
    this.padding = const EdgeInsets.all(10),
  });

  final Future<void> Function()? onPressed;
  final double size;
  final double iconSize;
  final String tooltip;
  final IconData icon;
  final Color foregroundColor;
  final Color backgroundColor;
  final Color borderColor;
  final Color shadowColor;
  final Gradient? gradient;
  final EdgeInsets padding;

  @override
  State<AnimatedRefreshButton> createState() => _AnimatedRefreshButtonState();
}

class _AnimatedRefreshButtonState extends State<AnimatedRefreshButton> {
  static const Duration _spinStepDuration = Duration(milliseconds: 720);

  bool _isRefreshing = false;
  double _turns = 0;

  Future<void> _spinLoop() async {
    while (mounted && _isRefreshing) {
      setState(() => _turns += 1);
      await Future<void>.delayed(_spinStepDuration);
    }
  }

  Future<void> _handlePressed() async {
    if (_isRefreshing || widget.onPressed == null) return;

    setState(() => _isRefreshing = true);
    unawaited(_spinLoop());

    try {
      await widget.onPressed!.call();
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEnabled = widget.onPressed != null && !_isRefreshing;

    return Tooltip(
      message: widget.tooltip,
      child: AnimatedScale(
        scale: _isRefreshing ? 0.96 : 1,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        child: AnimatedOpacity(
          opacity: isEnabled ? 1 : 0.8,
          duration: const Duration(milliseconds: 180),
          child: Material(
            color: Colors.transparent,
            child: Ink(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                color: widget.gradient == null ? widget.backgroundColor : null,
                gradient: widget.gradient,
                borderRadius: BorderRadius.circular(widget.size * 0.34),
                border: Border.all(color: widget.borderColor),
                boxShadow: [
                  BoxShadow(
                    color: widget.shadowColor,
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: InkWell(
                onTap: isEnabled ? _handlePressed : null,
                borderRadius: BorderRadius.circular(widget.size * 0.34),
                child: Padding(
                  padding: widget.padding,
                  child: Center(
                    child: AnimatedRotation(
                      turns: _turns,
                      duration: _spinStepDuration,
                      curve: Curves.easeInOutCubic,
                      child: Icon(
                        widget.icon,
                        size: widget.iconSize,
                        color: widget.foregroundColor,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
