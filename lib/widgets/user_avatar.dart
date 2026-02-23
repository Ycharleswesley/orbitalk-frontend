import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/app_colors.dart';

class UserAvatar extends StatelessWidget {
  final String? profilePicture;
  final String name;
  final double size;
  final bool isOnline;
  final int? colorId;
  final VoidCallback? onTap;

  const UserAvatar({
    Key? key,
    this.profilePicture,
    required this.name,
    this.size = 50,
    this.colorId,
    this.onTap,
    this.isOnline = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final Widget avatar = _buildCircle();
    
    Widget content = avatar;
    
    if (isOnline) {
      content = Stack(
        clipBehavior: Clip.none,
        children: [
          avatar,
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              width: size * 0.3,
              height: size * 0.3,
              decoration: BoxDecoration(
                color: const Color(0xFF00C853), // Online Green
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(context).scaffoldBackgroundColor, // Match background for cutoff effect
                  width: 2,
                ),
              ),
            ),
          ),
        ],
      );
    }

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: content,
      );
    }
    return content;
  }

  Widget _buildCircle() {
    // 1. Get Color
    final bgColor = _getDeterministicColor();

    // 2. Image (if valid)
    if (profilePicture != null && profilePicture!.isNotEmpty) {
      return ClipOval(
        child: CachedNetworkImage(
          imageUrl: profilePicture!,
          width: size,
          height: size,
          memCacheWidth: (size * 3).toInt(), // Optimize memory: Cache smaller version
          memCacheHeight: (size * 3).toInt(),
          fit: BoxFit.cover,
          placeholder: (context, url) => _buildPlaceholder(Colors.grey.shade300, icon: Icons.person),
          errorWidget: (context, url, error) => _buildInitials(bgColor),
        ),
      );
    }

    // 3. Initials (Fallback)
    return _buildInitials(bgColor);
  }

  Widget _buildPlaceholder(Color color, {IconData? icon}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
      child: icon != null
          ? Icon(icon, color: Colors.white, size: size * 0.5)
          : null,
    );
  }

  Widget _buildInitials(Color color) {
    String initials = '?';
    if (name.isNotEmpty) {
      final parts = name.trim().split(' ');
      if (parts.length > 1 && parts[1].isNotEmpty) {
        initials = '${parts[0][0]}${parts[1][0]}'.toUpperCase();
      } else {
        initials = name[0].toUpperCase();
      }
    }

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
      child: Text(
        initials,
        style: GoogleFonts.poppins(
          color: Colors.white,
          fontSize: size * 0.4, // Responsive font size
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Color _getDeterministicColor() {
    if (colorId != null) {
       return AppColors.getColor(colorId!);
    }
    
    final colors = [
      Colors.blue, Colors.green, Colors.orange, Colors.purple, 
      Colors.red, Colors.teal, Colors.amber, Colors.pink,
      const Color(0xFF0141B5), // UTELO Blue
      const Color(0xFF00C853), // UTELO Green
    ];
    
    final seed = (name.hashCode).abs();
    return colors[seed % colors.length];
  }
}
