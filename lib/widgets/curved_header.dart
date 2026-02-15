import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';

class CurvedHeader extends StatelessWidget {
  final String? title;
  final Widget? titleWidget;
  final VoidCallback? onBackPressed;
  final List<Widget>? actions;
  final bool showBack;
  final Widget? bottomChild;
  final double? height;

  const CurvedHeader({
    Key? key,
    this.title,
    this.titleWidget,
    this.onBackPressed,
    this.actions,
    this.showBack = true,
    this.bottomChild,
    this.height,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        bottomLeft: Radius.circular(30),
        bottomRight: Radius.circular(30),
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            // High Contrast: Use Dark Blue for both Light and Dark modes
            color: isDark ? const Color(0xFF001133).withOpacity(0.6) : const Color(0xFF001133).withOpacity(0.7),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(30),
              bottomRight: Radius.circular(30),
            ),
            border: Border(
              bottom: BorderSide(
                color: Colors.white.withOpacity(0.2),
                width: 1,
              ),
            ),
             // Gradient: Dark Blue range for both modes to ensure white text visibility
             gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: isDark
                  ? [
                      const Color(0xFF001133).withOpacity(0.7),
                      const Color(0xFF0141B5).withOpacity(0.5),
                    ]
                  : [
                      const Color(0xFF001133).withOpacity(0.8), // Dark Blue
                      const Color(0xFF0141B5).withOpacity(0.6), // Lighter Deep Blue
                    ],
            ),
          ),
          child: AnnotatedRegion<SystemUiOverlayStyle>(
            value: const SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness: Brightness.light,
              statusBarBrightness: Brightness.dark, 
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 30, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        if (showBack)
                          IconButton(
                            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
                            onPressed: onBackPressed ?? () => Navigator.of(context).pop(),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            visualDensity: VisualDensity.compact,
                          ),
                        
                        if (showBack) const SizedBox(width: 16),
                        
                        Expanded(
                          child: titleWidget ?? Text(
                            title ?? '',
                            style: GoogleFonts.poppins(
                              fontSize: 22,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        
                        if (actions != null)
                          ...actions!,
                      ],
                    ),
                    if (bottomChild != null) ...[
                      const SizedBox(height: 16),
                      bottomChild!,
                    ]
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
