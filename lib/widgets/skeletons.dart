import 'package:flutter/material.dart';

class ChatListSkeleton extends StatefulWidget {
  final int itemCount;
  final bool isDark;

  const ChatListSkeleton({
    Key? key,
    this.itemCount = 8,
    required this.isDark,
  }) : super(key: key);

  @override
  _ChatListSkeletonState createState() => _ChatListSkeletonState();
}

class _ChatListSkeletonState extends State<ChatListSkeleton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.3, end: 0.6).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final baseColor = widget.isDark ? Colors.white : Colors.black;

    return ListView.builder(
      padding: const EdgeInsets.only(top: 210, bottom: 120),
      itemCount: widget.itemCount,
      physics: const NeverScrollableScrollPhysics(), // Prevent scrolling while loading
      itemBuilder: (context, index) {
        return FadeTransition(
          opacity: _animation,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                // Avatar Skeleton
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: baseColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 16),
                // Text Lines Skeleton
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 140,
                        height: 16,
                        decoration: BoxDecoration(
                          color: baseColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        height: 12,
                        margin: const EdgeInsets.only(right: 40),
                        decoration: BoxDecoration(
                          color: baseColor.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
