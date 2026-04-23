import 'package:flutter/material.dart';

class SubtitleLayer extends StatelessWidget {
  final String text;
  final double fontSize;
  final bool controlsVisible;

  const SubtitleLayer({
    super.key,
    required this.text,
    required this.fontSize,
    required this.controlsVisible,
  });

  @override
  Widget build(BuildContext context) {
    if (text.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    return Positioned(
      left: 120,
      right: 120,
      bottom: controlsVisible ? 180 : 72,
      child: IgnorePointer(
        child: Center(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              child: Text(
                text,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: fontSize,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                  shadows: const [
                    Shadow(
                      blurRadius: 6,
                      color: Colors.black87,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
