import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class UteloLogo extends StatelessWidget {
  final double logoSize;
  final double fontSize;
  final bool showText;
  final Color textColor;

  const UteloLogo({
    Key? key,
    this.logoSize = 100,
    this.fontSize = 32,
    this.showText = true,
    this.textColor = Colors.white,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          'assets/orbitalkLogo.png',
          width: logoSize,
          height: logoSize,
          fit: BoxFit.contain,
        ),
        if (showText) ...[
          const SizedBox(height: 20),
          Text(
            'UTELO',
            style: GoogleFonts.poppins(
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ],
      ],
    );
  }
}
