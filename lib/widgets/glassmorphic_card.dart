import 'dart:ui';
import 'package:flutter/material.dart';

class GlassmorphicCard extends StatelessWidget {
  final Widget child;
  final double blur;
  final double opacity;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final Color color; // New parameter

  const GlassmorphicCard({
    Key? key,
    required this.child,
    this.blur = 10,
    this.opacity = 0.2,
    this.borderRadius = 20,
    this.padding,
    this.color = Colors.white, // Default to white
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.05), // Lighter shadow for light mode
            blurRadius: 25,
            spreadRadius: 1, 
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding ?? const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: color.withOpacity(opacity), // Tint
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(
                color: color.withOpacity(0.3), // Border matches tint
                width: 1.5,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
