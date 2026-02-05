import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:math' as math;
import '../models/call_model.dart';
import '../services/call_service.dart';
import '../services/local_storage_service.dart';
import '../services/notification_service.dart';
import 'active_call_screen.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';

import '../utils/app_colors.dart'; // Added

class IncomingCallScreen extends StatefulWidget {
  final String callId;
  final String callerId; // Added
  final String callerName;
  final String callerAvatar;
  final int callerProfileColor; 
  final bool autoAnswer; 

  const IncomingCallScreen({
    Key? key,
    required this.callId,
    required this.callerId, 
    required this.callerName,
    required this.callerAvatar,
    this.callerProfileColor = 0, 
    this.autoAnswer = false,
  }) : super(key: key);

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen> with TickerProviderStateMixin, WidgetsBindingObserver {
  final CallService _callService = CallService();
  final LocalStorageService _localStorage = LocalStorageService();
  final NotificationService _notificationService = NotificationService();
  
  bool _isAnswering = false;
  bool _isDeclining = false;

  late AnimationController _rippleController;

  @override
  void initState() {
    super.initState();
    debugPrint('IncomingCallScreen: MOUNTED for Call ID: ${widget.callId}'); // DEBUG LOG
    WidgetsBinding.instance.addObserver(this);
    
    // Clear any persistent notifications immediately
    _notificationService.cancelCallNotification(widget.callId);
    _notificationService.cancelAllNotifications();
    
    // Auto-Answer Trigger
    if (widget.autoAnswer) {
      debugPrint('IncomingCallScreen: Auto-Answering call...');
      // Small delay to ensure initialization
      Future.delayed(const Duration(milliseconds: 500), _handleAnswer);
    }

    // Loop animation: 3 waves then brake (wait)
    // Duration includes the Waves + The Brake time.
    _rippleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2), 
    )..repeat();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached) {
       debugPrint('IncomingCallScreen: App DETACHED. Setting Busy status...');
       _handleAppKill(); 
    }
  }

  Future<void> _handleAppKill() async {
    try {
      // Direct Firestore update to be as fast as possible before process ends
      await FirebaseFirestore.instance.collection('calls').doc(widget.callId).update({
        'callStatus': 'busy'
      });
      _callService.stopRinging();
    } catch (e) {
      debugPrint('Error marking busy: $e');
    }
  }

  @override
  void dispose() {
    debugPrint('IncomingCallScreen: DISPOSING...');
    try {
      WidgetsBinding.instance.removeObserver(this);
      _rippleController.dispose();
      _callService.stopRinging(); // Stop ringing when disposed
    } catch (e) {
      debugPrint('IncomingCallScreen: Error during dispose: $e');
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('IncomingCallScreen: BUILDING UI...'); // DEBUG LOG
    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        body: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('users').doc(widget.callerId).snapshots(),
          builder: (context, profileSnapshot) {
            int liveColorId = widget.callerProfileColor;
            if (profileSnapshot.hasData && profileSnapshot.data!.exists) {
              liveColorId = (profileSnapshot.data!.data() as Map<String, dynamic>)['profileColor'] ?? liveColorId;
            }

            return Container(
              width: double.infinity,
              height: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: AppColors.getGradientColors(liveColorId),
                ),
              ),
              child: SafeArea(
                child: StreamBuilder<CallModel>(
                  stream: _callService.getCallStream(widget.callId),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) return _buildErrorState();
                    if (!snapshot.hasData) return _buildLoadingState();

                    final call = snapshot.data!;

                    // Handle Call End/Cancel remotely
                    if (call.callStatus == CallStatus.cancelled || 
                        call.callStatus == CallStatus.ended) {
                       
                       _callService.stopRinging();
                       FlutterRingtonePlayer().play(
                          fromAsset: "assets/sounds/end_call.mp3",
                          ios: IosSounds.glass,
                          looping: false,
                          volume: 0.5,
                       );

                       WidgetsBinding.instance.addPostFrameCallback((_) {
                         if (mounted) {
                            Future.delayed(const Duration(seconds: 1), () { // 1 sec delay
                                if (mounted) {
                                    Navigator.of(context).popUntil((route) => route.isFirst);
                                }
                            });
                         }
                       });
                       return _buildCallEndedState('Call Ended');
                    }

                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Spacer(flex: 2),
                        
                        // AVATAR WITH RIPPLES
                        SizedBox(
                          width: 300,
                          height: 300,
                          child: CustomPaint(
                            painter: RipplePainter(
                              _rippleController,
                              color: AppColors.getColor(liveColorId),
                            ),
                            child: Center(
                              child: Container(
                                width: 140,
                                height: 140,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.getColor(liveColorId),
                                  border: Border.all(color: Colors.white.withOpacity(0.9), width: 4),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.4),
                                      blurRadius: 20,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                                child: ClipOval(child: Center(child: _buildCallerAvatar())),
                              ),
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 32),
                        
                        Text(
                          widget.callerName,
                          style: GoogleFonts.poppins(
                            fontSize: 34,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            shadows: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              )
                            ]
                          ),
                        ),
                        
                        const SizedBox(height: 8),
                        
                        Text(
                          'Incoming Voice Call...',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            color: Colors.blue.shade100,
                            letterSpacing: 1.2,
                          ),
                        ),
                        
                        const Spacer(flex: 3),
                        
                        _buildCallActions(),
                        
                        const SizedBox(height: 60),
                      ],
                    );
                  },
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildCallerAvatar() {
    double avatarSize = 140;
    final bgColor = AppColors.getColor(widget.callerProfileColor);
    
    Widget content;
    if (widget.callerAvatar.isNotEmpty) {
      content = CachedNetworkImage(
        imageUrl: widget.callerAvatar,
        fit: BoxFit.cover,
        errorWidget: (context, url, error) => const Icon(Icons.person, size: 60, color: Colors.white),
      );
    } else {
       content = Text(
          widget.callerName.isNotEmpty ? widget.callerName[0].toUpperCase() : '?',
          style: GoogleFonts.poppins(
            fontSize: 56,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        );
    }

    return Container(
      width: avatarSize,
      height: avatarSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: bgColor, // Use Profile Color
        border: Border.all(color: Colors.white.withOpacity(0.9), width: 4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipOval(child: Center(child: content)),
    );
  }

  Widget _buildCallActions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildActionButton(
            color: Colors.redAccent,
            icon: Icons.call_end,
            onTap: _isDeclining ? null : _handleDecline,
            isLoading: _isDeclining,
            label: "Decline",
          ),
          const SizedBox(width: 40),
          _buildActionButton(
            color: const Color(0xFF00E676), // Vibrant Green
            icon: Icons.call, // Phone Icon
            onTap: _isAnswering ? null : _handleAnswer,
            isLoading: _isAnswering,
            label: "Accept",
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required Color color,
    required IconData icon,
    required VoidCallback? onTap,
    required bool isLoading,
    required String label,
  }) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 75,
            height: 75,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.4),
                  blurRadius: 15,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: isLoading
                ? const Padding(
                    padding: EdgeInsets.all(20.0),
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                  )
                : Icon(icon, color: Colors.white, size: 36),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          label,
          style: GoogleFonts.poppins(
            color: Colors.white.withOpacity(0.9),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingState() => const Center(child: CircularProgressIndicator(color: Colors.white));
  Widget _buildErrorState() => const Center(child: Icon(Icons.error, color: Colors.amber, size: 50));
  Widget _buildCallEndedState(String msg) => Center(child: Text(msg, style: GoogleFonts.poppins(color: Colors.white)));

  Future<void> _handleAnswer() async {
    if (_isAnswering) return;
    setState(() => _isAnswering = true);
    try {
      final userId = await _localStorage.getUserId();
      final userName = await _localStorage.getUserName();
      if (userId == null) throw Exception('No User');
      
      // STOP RINGTONE IMMEDIATELY
      _callService.stopRinging();
      FlutterRingtonePlayer().stop(); // Force Direct Stop


      await _callService.answerCall(widget.callId, userId, userName ?? 'User');
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => ActiveCallScreen(
              callId: widget.callId,
              contactId: widget.callerId, // Added
              contactName: widget.callerName,
              contactAvatar: widget.callerAvatar,
              contactProfileColor: widget.callerProfileColor, 
              isOutgoing: false,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _isAnswering = false);
    }
  }

  Future<void> _handleDecline() async {
    if (_isDeclining) return;
    setState(() => _isDeclining = true);
    try {
      await _callService.declineCall(widget.callId);
      
      // Stop Ringing & Play End Call
      _callService.stopRinging();
      FlutterRingtonePlayer().play(
         fromAsset: "assets/sounds/end_call.mp3",
         ios: IosSounds.glass,
         looping: false,
         volume: 0.5,
      );

      if (mounted) Navigator.of(context).pop();
    } catch(e) {
      if (mounted) setState(() => _isDeclining = false);
    }
  }
}

// Custom Painter for "Three Waves + Brake" Animation
class RipplePainter extends CustomPainter {
  final Animation<double> animation;
  final Color color;

  RipplePainter(this.animation, {required this.color}) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    // We want 3 waves.
    // The animation goes 0.0 -> 1.0.
    // We'll split the timeline so the "waves" happen in the first 70%, and 30% is the "brake".
    
    final t = animation.value;
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;

    // Draw 3 waves
    // Wave 1 starts at 0.0
    // Wave 2 starts at 0.2
    // Wave 3 starts at 0.4
    
    // We adjust 't' effectively for each wave.
    _drawWave(canvas, center, maxRadius, t, 0.0);
    _drawWave(canvas, center, maxRadius, t, 0.2);
    _drawWave(canvas, center, maxRadius, t, 0.4);
  }

  void _drawWave(Canvas canvas, Offset center, double maxRadius, double t, double delay) {
    // Adjust time by delay
    double localT = t - delay;
    
    // If not started yet, or if we are in the "brake" period (e.g. > 0.6 + duration), don't draw?
    // Let's say loop is:
    // 0.0 -> Wave 1 Start
    // ...
    // 0.7 -> All Waves Faded out?
    // 0.7 -> 1.0 -> Silence (Brake)
    
    // Normalize localT to be 0.0 -> 1.0 within the *active* phase (say 0.7 of total time)
    double activeDuration = 0.7; // 70% of time is waving
    
    // If we are past active phase relative to start, don't draw (or fade out completely)
    if (localT < 0.0 || localT > activeDuration) return;

    // Map localT (0..0.7) to progress (0..1)
    double progress = localT / activeDuration;
    
    // Radius grows 0 -> max
    double radius = maxRadius * math.pow(progress, 0.5); // Ease out
    
    // Opacity goes 1 -> 0
    double opacity = 1.0 - progress;
    opacity = opacity.clamp(0.0, 1.0);

    final paint = Paint()
      ..color = color.withOpacity(opacity * 0.6) // Max opacity 0.6
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4 * (1-progress); // Thins out as it expands

    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(covariant RipplePainter oldDelegate) => true;
}
