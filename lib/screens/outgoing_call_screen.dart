import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart'; // Added
import 'dart:async'; // Added
import 'package:cloud_firestore/cloud_firestore.dart'; // Added
import '../models/call_model.dart';
import '../services/call_service.dart';
import 'active_call_screen.dart';
import '../utils/app_colors.dart';

class OutgoingCallScreen extends StatefulWidget {
  final String callId;
  final String contactId; // Added
  final String contactName;
  final String contactAvatar;
  final int contactProfileColor;

  const OutgoingCallScreen({
    Key? key,
    required this.callId,
    required this.contactId, // Added
    required this.contactName,
    required this.contactAvatar,
    this.contactProfileColor = 0,
  }) : super(key: key);

  @override
  State<OutgoingCallScreen> createState() => _OutgoingCallScreenState();
}

class _OutgoingCallScreenState extends State<OutgoingCallScreen> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final CallService _callService = CallService();
  bool _isCancelling = false;
  late AnimationController _rippleController;
  Timer? _ringbackTimer; // Added
  bool _hasStartedRinging = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    debugPrint('OutgoingCallScreen: Initialized for call ${widget.callId}');
    
    // Start Ringback Tone (Simulated "Tuuu... Tuuu...")
    _startRingback();

    // Animation for Ripple Effect
    _rippleController = AnimationController(
       vsync: this,
       duration: const Duration(seconds: 2), 
    )..repeat();
    
    // 1. Start 90s Timeout Timer (Auto-Cancel if no answer)
    Timer(const Duration(seconds: 90), _handleTimeout);
    
    // 2. Check if User is Offline
    _checkOfflineStatus();
  }

  Future<void> _checkOfflineStatus() async {
      try {
        // We need to check the RECEIVER'S status.
        // widget.contactId is the receiver userId.
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(widget.contactId).get();
        
        if (userDoc.exists) {
           final data = userDoc.data();
           final isOnline = data?['isOnline'] ?? false;
           final fcmToken = data?['fcmToken'];
           final isLoggedOut = data?['isLoggedOut'] ?? false;
           
           // CRITICAL: If explicitly Logged Out OR No Token => User is Not Reachable
           if (isLoggedOut == true || fcmToken == null || fcmToken.toString().isEmpty) {
              debugPrint('OutgoingCallScreen: User is Offline/Logged Out. Playing busy signal.');
              
              // Stop Ringback immediately
              FlutterRingtonePlayer().stop();
              _ringbackTimer?.cancel();
              
              // Play 3 Beeps with 2s gap
              _playBusySignalAndEnd();
           }
        }
      } catch (e) {
        debugPrint('Error checking offline status: $e');
      }
  }

  Future<void> _playBusySignalAndEnd() async {
      if (!mounted) return;
      
      // Beep 1
      await _playBeep();
      if (!mounted) return;
      await Future.delayed(const Duration(seconds: 2));
      
      // Beep 2
      if (!mounted) return;
      await _playBeep();
      if (!mounted) return;
      await Future.delayed(const Duration(seconds: 2));
      
      // Beep 3
      if (!mounted) return;
      await _playBeep();
      if (!mounted) return;
      
      // End Call
      _handleOfflineEnd();
  }

  Future<void> _playBeep() async {
     // Use system notification sound or short beep asset
     // Assuming we have 'assets/sounds/beep.mp3' or similar, or use ringtone player with short duration
     try {
       await FlutterRingtonePlayer().play(
          fromAsset: "assets/sounds/end_call.mp3", // Reuse end call sound as beep
          ios: IosSounds.glass, 
          looping: false, 
          volume: 1.0, 
       );
     } catch(e) { debugPrint('Error playing beep: $e'); }
  }

  void _handleOfflineEnd() {
      if (mounted) {
         // Update Status to Missed or Failed
         FirebaseFirestore.instance.collection('calls').doc(widget.callId).update({
           'callStatus': 'missed' // Or 'failed'
         });
         
         Navigator.of(context).pop();
         
         ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('User is not logged in'),
              backgroundColor: Colors.redAccent,
              duration: Duration(seconds: 4),
            ),
         );
      }
  }

  void _handleTimeout() {
      if (mounted) {
         debugPrint('OutgoingCallScreen: 90s Timeout. Marking as Missed...');
         FirebaseFirestore.instance.collection('calls').doc(widget.callId).update({
           'callStatus': 'missed'
         });
         
         Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(content: Text('User is busy (No Answer)'), backgroundColor: Colors.orange),
        );
     }
  }

  Future<void> _startRingback() async {
    debugPrint('OutgoingCallScreen: Starting Ringback Tone (Custom)');
    await FlutterRingtonePlayer().stop(); 
    
    // Use custom ringback so caller hears a "calling" tone
    try {
      await FlutterRingtonePlayer().play(
         fromAsset: "assets/sounds/phone-ringing-382734.mp3",
         ios: IosSounds.glass,
         looping: true, 
         volume: 1.0, 
      );
    } catch (e) {
      debugPrint('Error playing custom ringback: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached) {
       debugPrint('OutgoingCallScreen: App DETACHED. Cancelling call...');
       _handleCancel(); 
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ringbackTimer?.cancel(); 
    // Ensuring stop happens
    FlutterRingtonePlayer().stop();
    _rippleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        _handleCancel();
        return false;
      },
      child: Scaffold(
        body: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('users').doc(widget.contactId).snapshots(),
          builder: (context, profileSnapshot) {
            int liveColorId = widget.contactProfileColor;
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
                    if (snapshot.hasData) {
                      final call = snapshot.data!;
                      
                      if (call.callStatus == CallStatus.ongoing) {
                         debugPrint('OutgoingCallScreen: Answered -> Navigating to ActiveCallScreen');
                         FlutterRingtonePlayer().stop();
                         _ringbackTimer?.cancel(); 
                         // No delay needed for ongoing call
                         WidgetsBinding.instance.addPostFrameCallback((_) {
                           if (mounted) {
                             Navigator.of(context).pushReplacement(
                               MaterialPageRoute(
                                 builder: (context) => ActiveCallScreen(
                                   callId: widget.callId,
                                   contactId: widget.contactId,
                                   contactName: widget.contactName,
                                   contactAvatar: widget.contactAvatar,
                                   contactProfileColor: liveColorId,
                                   isOutgoing: true,
                                 ),
                               ),
                             );
                           }
                         });
                      } else if (call.callStatus == CallStatus.ringing) {
                         // Start Ringback ONLY when confirmed 'ringing'
                         if (!_hasStartedRinging) {
                              _hasStartedRinging = true;
                              _startRingback();
                         }
                      } else if (call.callStatus == CallStatus.declined || 
                                 call.callStatus == CallStatus.ended ||
                                 call.callStatus == CallStatus.busy) {
                         debugPrint('OutgoingCallScreen: ${call.callStatus} -> Closing');
                         FlutterRingtonePlayer().stop();
                         _ringbackTimer?.cancel();

                         FlutterRingtonePlayer().play(
                            fromAsset: "assets/sounds/end_call.mp3",
                            ios: IosSounds.glass,
                            looping: false,
                            volume: 0.5,
                         );

                         WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted) {
                               // Delay pop to show end state and play sound
                               Future.delayed(const Duration(seconds: 1), () {
                                 if (mounted) {
                                   Navigator.of(context).pop();
                                   String msg = 'Call ended';
                                   if (call.callStatus == CallStatus.declined) msg = 'Call declined';
                                   if (call.callStatus == CallStatus.busy) msg = 'User is busy';

                                   ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text(msg), backgroundColor: Colors.red),
                                   );
                                 }
                               });
                            }
                         });
                      }
                    }

                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 60),
                        _buildRippleAvatar(),
                        const SizedBox(height: 40),
                        Text(
                          widget.contactName,
                          style: GoogleFonts.poppins(
                            fontSize: 32,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Calling...',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            color: Colors.white.withOpacity(0.8),
                            letterSpacing: 1.2,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const Spacer(),
                        _buildCancelButton(),
                        const SizedBox(height: 80),
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

  Widget _buildRippleAvatar() {
    Widget avatarContent = widget.contactAvatar.isNotEmpty
        ? ClipOval(
            child: CachedNetworkImage(
              imageUrl: widget.contactAvatar,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(color: Colors.white24),
              errorWidget: (context, url, error) => _buildDefaultAvatar(),
            ),
          )
        : _buildDefaultAvatar();

    final bgColor = AppColors.getColor(widget.contactProfileColor);

    return SizedBox(
       width: 250,
       height: 250,
       child: CustomPaint(
          painter: RipplePainter(
             _rippleController,
             color: bgColor, // Use Profile Color
          ),
          child: Center(
             child: Container(
               width: 140,
               height: 140,
               decoration: BoxDecoration(
                 shape: BoxShape.circle,
                 border: Border.all(color: Colors.white, width: 3),
                 boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                 ],
               ),
               child: ClipOval(child: avatarContent),
             ),
          ),
       ),
    );
  }

  Widget _buildDefaultAvatar() {
    final bgColor = AppColors.getColor(widget.contactProfileColor);
    return Container(
      color: bgColor, // Use Profile Color
      child: Center(
        child: Text(
          widget.contactName.isNotEmpty ? widget.contactName[0].toUpperCase() : '?',
          style: GoogleFonts.poppins(
            fontSize: 56,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildCancelButton() {
    return GestureDetector(
      onTap: _isCancelling ? null : _handleCancel,
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: Colors.redAccent,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.redAccent.withOpacity(0.4),
              blurRadius: 15,
              spreadRadius: 2,
            ),
          ],
        ),
        child: _isCancelling
            ? const Center(child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : const Icon(
                Icons.call_end,
                color: Colors.white,
                size: 36,
              ),
      ),
    );
  }

  Future<void> _handleCancel() async {
    if (_isCancelling) return;
    setState(() => _isCancelling = true);
    try {
      await _callService.cancelCall(widget.callId);
      // Let StreamBuilder handle navigation
    } catch (e) {
       debugPrint('Error cancelling: $e');
       setState(() => _isCancelling = false);
    }
  }
}

// Copy of RipplePainter from active_call_screen.dart to assume consistent look
class RipplePainter extends CustomPainter {
  final Animation<double> animation;
  final Color color;

  RipplePainter(this.animation, {required this.color}) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final t = animation.value;
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;

    _drawWave(canvas, center, maxRadius, t, 0.0);
    _drawWave(canvas, center, maxRadius, t, 0.2);
    _drawWave(canvas, center, maxRadius, t, 0.4);
  }

  void _drawWave(Canvas canvas, Offset center, double maxRadius, double t, double delay) {
    double localT = t - delay;
    double activeDuration = 1.0; // Slower wave for "Ringing" (calmer)
    
    // Cycle it
    if (localT < 0) localT += 2.0; // wrap? No, just loop module handled by controller
    // Actually controller repeats 0..1. 
    // If we want seamless multi-wave, we check bounds.
    
    // Simplified logic for "Ringing":
    // Just simple ping-pong or expanding rings.
    // The ActiveCall logic uses "brake" silence. Here we want continuous "Calling...".
    
    // Let's stick to simple expanding rings
    activeDuration = 2.0; // Matches controller
    if (localT < 0) return;
    
    double progress = (localT % activeDuration) / activeDuration;
    
    double radius = maxRadius * progress;
    double opacity = 1.0 - progress;
    
    final paint = Paint()
      ..color = color.withOpacity(opacity * 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(covariant RipplePainter oldDelegate) => true;
}
