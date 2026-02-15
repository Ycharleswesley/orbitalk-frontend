import 'package:flutter/material.dart';
import '../utils/app_colors.dart';

class GradientBackground extends StatelessWidget {
  final Widget child;
  final bool withOpacity;

  const GradientBackground({
    Key? key,
    required this.child,
    this.withOpacity = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: withOpacity
            ? AppColors.getGradient()
            : AppColors.getFullGradient(),
      ),
      child: child,
    );
  }
}
