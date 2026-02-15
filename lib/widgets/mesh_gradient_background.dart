import 'dart:ui';
import 'package:flutter/material.dart';

class MeshGradientBackground extends StatelessWidget {
  final Widget child;
  final bool isDark;

  const MeshGradientBackground({
    Key? key,
    required this.child,
    this.isDark = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Light Mode Colors (Pastel)
    final Color baseColor = isDark ? const Color(0xFF1E1E2C) : const Color(0xFFF5F5FA);
    final Color orb1 = isDark ? const Color(0xFF6C63FF) : const Color(0xFFA5A1FF); // Purple
    final Color orb2 = isDark ? const Color(0xFF00E5FF) : const Color(0xFF80F3FF); // Cyan
    final Color orb3 = isDark ? const Color(0xFFB64166) : const Color(0xFFFF8FA3); // Pink
    final Color orb4 = isDark ? const Color(0xFF2979FF) : const Color(0xFF82B1FF); // Blue

    return Stack(
      children: [
        // Background base
        Container(
          color: baseColor,
        ),
        
        // Blurred Orbs
        Positioned(
          top: -100,
          left: -100,
          child: _buildOrb(orb1, 300), 
        ),
        Positioned(
          top: 100,
          right: -50,
          child: _buildOrb(orb2, 250), 
        ),
        Positioned(
          bottom: -50,
          left: 50,
          child: _buildOrb(orb3, 280), 
        ),
        Positioned(
          bottom: 100,
          right: -20,
          child: _buildOrb(orb4, 200), 
        ),

        // Blur Filter
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
          child: Container(
            color: (isDark ? Colors.black : Colors.white).withOpacity(0.2),
          ),
        ),

        // Content
        // Content
        Positioned.fill(child: child),
      ],
    );
  }

  Widget _buildOrb(Color color, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withOpacity(0.6),
        shape: BoxShape.circle,
      ),
    );
  }
}
