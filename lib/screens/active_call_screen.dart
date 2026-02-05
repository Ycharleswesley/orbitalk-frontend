import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/call_service.dart';
import '../models/call_model.dart';
import '../models/transcript_model.dart';
import '../config/translation_config.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import '../services/audio_processor_service.dart'; // Added for debug stream

import '../utils/app_colors.dart'; // Added

class ActiveCallScreen extends StatefulWidget {
  final String callId;
  final String contactId; // Added
  final String contactName;
  final String contactAvatar;
  final int contactProfileColor; // Added
  final bool isOutgoing;

  const ActiveCallScreen({
    Key? key,
    required this.callId,
    required this.contactId, // Added
    required this.contactName,
    required this.contactAvatar,
    this.contactProfileColor = 0, // Default Blue
    required this.isOutgoing,
  }) : super(key: key);

  @override
  State<ActiveCallScreen> createState() => _ActiveCallScreenState();
}

class _ActiveCallScreenState extends State<ActiveCallScreen> with TickerProviderStateMixin, WidgetsBindingObserver {
  final CallService _callService = CallService();
  Timer? _callTimer;
  int _secondsElapsed = 0;
  bool _isMuted = false;
  bool _isSpeakerOn = false;
  bool _isEnding = false;
  bool _isTimerStarted = false;
  StreamSubscription<CallModel>? _callStatusSubscription;
  StreamSubscription<bool>? _connectionStatusSubscription;
  bool _isWebSocketConnected = false;
  final ScrollController _scrollController = ScrollController();
  late AnimationController _blinkController;
  late Animation<double> _blinkAnimation;
  late AnimationController _rippleController; // New Controller for Waves
  bool _isConnectionReady = false; 

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // SAFETY: Ensure any previous ringtone is stopped immediately upon entering Active Call
    _callService.stopRinging(); // Sync State
    FlutterRingtonePlayer().stop(); // Force Stop
    
    _initializeCall();
  }

  void _initializeCall() {
    _listenToCallStatus();
    debugPrint('ActiveCallScreen: Call started, ID: ${widget.callId}');
    
    // Animation for translation indicator
    _blinkController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..repeat(reverse: true);
    _blinkAnimation = Tween<double>(begin: 0.2, end: 1.0).animate(_blinkController);
    
    // Animation for Waves (Same as Incoming)
    _rippleController = AnimationController(
       duration: const Duration(seconds: 2),
       vsync: this,
    )..repeat();
  }

  void _listenToCallStatus() {
    _callStatusSubscription = _callService.getCallStream(widget.callId).listen((call) {
      if (!_isTimerStarted && call.callStatus == CallStatus.ongoing) {
        // Wait for WebSocket "Ready" signal.
        debugPrint('ActiveCallScreen: Call is ongoing. Waiting for Backend Call Active signal...');
        
        if (_callService.webSocketService.isCallActive) {
            _onCallActive();
        }
      } else if (call.callStatus == CallStatus.ended || call.callStatus == CallStatus.declined || call.callStatus == CallStatus.cancelled) {
        // Call ended remotely
        debugPrint('ActiveCallScreen: Call status changed to ${call.callStatus}. Exiting...');
        if (!_isEnding) {
           _handleEndCall(remote: true);
        }
      }
    });
    
    _isWebSocketConnected = _callService.webSocketService.isConnected;
    _connectionStatusSubscription = _callService.webSocketService.connectionStatusStream.listen((isConnected) {
      if (mounted) {
        setState(() {
          _isWebSocketConnected = isConnected;
          // If disconnected, show connecting state again
          if (!isConnected) {
             _isConnectionReady = false;
          }
        });
      }
    });

    // Listen for System Messages (Ready Signal)
    _callService.webSocketService.systemMessageStream.listen((message) {
      if (message['type'] == 'system' && message['status'] == 'call_active') {
         _onCallActive();
      }
    });
  }

  void _onCallActive() {
     if (mounted && !_isConnectionReady) {
        debugPrint('ActiveCallScreen: Backend CALL START! Starting Timer Sync.');
        setState(() => _isConnectionReady = true);
        if (!_isTimerStarted) {
           _startTimer();
           _isTimerStarted = true;
        }
     }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached) {
       // User swiped away the app
       debugPrint('ActiveCallScreen: App DETACHED. Ending call...');
       _handleEndCall();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _blinkController.dispose();
    _rippleController.dispose();
    _callTimer?.cancel();
    _callStatusSubscription?.cancel();
    _connectionStatusSubscription?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _startTimer() {
    _callTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _secondsElapsed++;
        });
      }
    });
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        _handleEndCall();
        return false;
      },
      child: Scaffold(
        body: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('users').doc(widget.contactId).snapshots(),
          builder: (context, snapshot) {
            int liveColorId = widget.contactProfileColor;
            if (snapshot.hasData && snapshot.data!.exists) {
              liveColorId = (snapshot.data!.data() as Map<String, dynamic>)['profileColor'] ?? liveColorId;
            }

            return Container(
              width: double.infinity,
              height: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF02ABE3), // Ocean Blue Light
                    Color(0xFF1B4BAB), // Ocean Blue Dark
                  ],
                ),
              ),
              child: SafeArea(
                  child: Column(
                    children: [
                      _buildConnectionStatus(),
                      
                      const SizedBox(height: 10),
                      
                      // Flexible Top Section: Avatar + Name + Timer
                      // Using Flexible instead of Fixed Expanded to adapt to screen size
                      Flexible(
                         flex: 3, 
                         child: Center(
                          child: SingleChildScrollView(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _buildContactAvatar(), 
                                const SizedBox(height: 12),
                                
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 20),
                                  child: Text(
                                    widget.contactName,
                                    style: GoogleFonts.poppins(
                                      fontSize: 26, 
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                    textAlign: TextAlign.center,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                
                                const SizedBox(height: 8),
                                
                                // Timer/Status
                                if (_isEnding)
                                   Text(
                                      'Call Ended',
                                      style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white70),
                                   )
                                else if (!_isConnectionReady)
                                  Text(
                                    'Connecting...',
                                    style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.white70),
                                  )
                                else
                                   Text(
                                    _formatTime(_secondsElapsed),
                                    style: GoogleFonts.poppins(
                                      fontSize: 24, 
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                      letterSpacing: 2.0,
                                      shadows: [BoxShadow(blurRadius: 4, color: Colors.black26)]
                                    ),
                                  ),
                                  
                               if (!_isWebSocketConnected && !_isEnding)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text('Low Signal', style: GoogleFonts.poppins(fontSize: 12, color: Colors.amber)),
                                ),
                              ],
                            ),
                          ),
                         ),
                      ),
                      
                      // Transcript Area (Expanded to fill remaining space)
                      Expanded(
                          flex: 4,
                          child: _buildTranscriptArea(),
                      ),
                      
                      const SizedBox(height: 10),
                      
                      // Bottom Section: Controls
                      SafeArea(
                        top: false,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 20),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                               _buildCallControls(),
                               const SizedBox(height: 16),
                               _buildEndCallButton(),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildContactAvatar() {
    Widget avatarContent;
    if (widget.contactAvatar.isNotEmpty) {
      avatarContent = ClipOval(
            child: CachedNetworkImage(
              imageUrl: widget.contactAvatar,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                color: Colors.grey[800],
                child: const Icon(Icons.person, size: 60, color: Colors.white54),
              ),
              errorWidget: (context, url, error) => _buildDefaultAvatar(),
            ),
      );
    } else {
      avatarContent = _buildDefaultAvatar();
    }
    
    final bgColor = AppColors.getColor(widget.contactProfileColor);

    return SizedBox(
       width: 140, 
       height: 140,
       child: CustomPaint(
          painter: RipplePainter(
             _rippleController,
             color: bgColor, // Use Profile Color
          ),
          child: Center(
             child: Container(
               width: 80, 
               height: 80,
               decoration: BoxDecoration(
                 shape: BoxShape.circle,
                 border: Border.all(color: Colors.white.withOpacity(0.8), width: 3),
                 boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 10,
                      spreadRadius: 2,
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
      width: 110, 
      height: 110,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: bgColor, // Use Profile Color
        border: Border.all(color: Colors.white, width: 4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Center(
        child: Text(
          widget.contactName.isNotEmpty ? widget.contactName[0].toUpperCase() : '?',
          style: GoogleFonts.poppins(
            fontSize: 40,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildCallControls() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildSpeakerButton(),
          _buildControlButton(
            icon: _isMuted ? Icons.mic_off : Icons.mic,
            label: 'Mute',
            isActive: _isMuted,
            onTap: _toggleMute,
          ),
        ],
      ),
    );
  }

  Widget _buildSpeakerButton() {
    return GestureDetector(
      onTap: _toggleSpeaker,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _isSpeakerOn ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(
              Icons.volume_up,
              color: _isSpeakerOn ? Colors.black : Colors.white,
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              'Speaker',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: _isSpeakerOn ? Colors.black : Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isActive ? Colors.white.withOpacity(0.3) : Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: Colors.white,
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEndCallButton() {
    return GestureDetector(
      onTap: _isEnding ? null : _handleEndCall,
      child: Container(
        width: 70,
        height: 70,
        decoration: BoxDecoration(
          color: Colors.red,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.red.withOpacity(0.5),
              blurRadius: 15,
              spreadRadius: 2,
            ),
          ],
        ),
        child: _isEnding
            ? const CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              )
            : const Icon(
                Icons.call_end,
                color: Colors.white,
                size: 32,
              ),
      ),
    );
  }

  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
    });
    _callService.toggleMicrophone(_isMuted);
    debugPrint('ActiveCallScreen: Microphone ${_isMuted ? "muted" : "unmuted"}');
  }

  void _toggleSpeaker() {
    setState(() {
      _isSpeakerOn = !_isSpeakerOn;
    });
    _callService.toggleSpeaker(_isSpeakerOn);
    debugPrint('ActiveCallScreen: Speaker ${_isSpeakerOn ? "on" : "off"}');
  }

  Future<void> _handleEndCall({bool remote = false}) async {
    if (_isEnding) return;

    setState(() {
      _isEnding = true;
    });

    try {
      if (!remote) {
        debugPrint('ActiveCallScreen: Ending call ${widget.callId}, duration: $_secondsElapsed seconds');
        await _callService.endCall(widget.callId, _secondsElapsed);
        debugPrint('ActiveCallScreen: Call ended successfully');
      } else {
        debugPrint('ActiveCallScreen: Handling remote call end for ${widget.callId}');
      }
      
      // Stop anything currently playing
      FlutterRingtonePlayer().stop();
      
      // Play Custom End Call Sound
      FlutterRingtonePlayer().play(
        fromAsset: "assets/sounds/end_call.mp3",
        ios: IosSounds.glass, // Fallback
        looping: false,
        volume: 0.5,
      );

      // Instant Navigation - Audio plays in background via Plugin
      if (mounted) {
         // No delay, just pop. Audio continues.
         Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      debugPrint('ActiveCallScreen: Error ending call: $e');
      
      if (mounted) {
        setState(() {
          _isEnding = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to end call: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Build connection status indicator (Top Right) & Version (Top Left)
  Widget _buildConnectionStatus() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 0. Version Info (Top Left - Connectivity)
          Column(
             crossAxisAlignment: CrossAxisAlignment.start,
             children: [
               Text(
                 'v2.4-STABLE', // Reverted
                 style: GoogleFonts.poppins(
                   fontSize: 14,
                   fontWeight: FontWeight.bold,
                   color: Colors.white70,
                 ),
               ),
               // Blue Dot Logic
               StreamBuilder<int>(
                  stream: _callService.webSocketService.userCountStream,
                  initialData: 1,
                  builder: (context, snapshot) {
                      final count = snapshot.data ?? 1;
                      final isConnected = count > 1 || _isConnectionReady;
                      if (isConnected) {
                         return Padding(
                           padding: const EdgeInsets.only(top: 4, left: 2),
                           child: Container(
                             width: 8,
                             height: 8,
                             decoration: BoxDecoration(
                               color: Colors.blueAccent,
                               shape: BoxShape.circle,
                               boxShadow: [
                                 BoxShadow(
                                   color: Colors.blueAccent.withOpacity(0.6),
                                   blurRadius: 6,
                                   spreadRadius: 1,
                                 ),
                               ],
                             ),
                           ),
                         );
                      }
                      return const SizedBox.shrink();
                  },
               ),
             ],
          ),
          // ... (Rest of buildConnectionStatus is fine, leaving it but I need to close the bracket properly if I don't replace it all)
          // Actually, let's just replace the whole function to be safe or use careful range.
          // I will replace ONLY _handleEndCall and proceed to modify the build function logic below.
          
          // Wait, I can't split this easily without more context.
          // Let's replace _handleEndCall first.


          // Right Side: AI Status Indicator (Horizontal)
          Row(
            children: [
              FadeTransition(
                opacity: _isWebSocketConnected ? _blinkAnimation : const AlwaysStoppedAnimation(1.0),
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: _isWebSocketConnected ? Colors.greenAccent : Colors.redAccent,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                         color: (_isWebSocketConnected ? Colors.greenAccent : Colors.redAccent).withOpacity(0.6),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'AI Translator', 
                style: GoogleFonts.poppins(
                  fontSize: 12, 
                  fontWeight: FontWeight.w500,
                  color: Colors.white70
                )
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Build transcript area (Modified to be Flexible/Expanded)
  Widget _buildTranscriptArea() {
    return Expanded(
      flex: 2,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.3),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                'Live Transcripts',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
            Expanded(
              child: StreamBuilder<List<TranscriptModel>>(
                stream: _callService.transcriptService.transcriptStream,
                initialData: const [],
                builder: (context, snapshot) {
                  final transcripts = snapshot.data ?? [];
                  
                  if (transcripts.isEmpty) {
                    return Center(
                      child: Text(
                        'Waiting for speech...',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.white60,
                        ),
                      ),
                    );
                  }
                  
                  // Auto-scroll to bottom
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (_scrollController.hasClients) {
                      _scrollController.animateTo(
                        _scrollController.position.maxScrollExtent,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOut,
                      );
                    }
                  });
                  
                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    itemCount: transcripts.length,
                    itemBuilder: (context, index) {
                      final transcript = transcripts[index];
                      return _buildTranscriptItem(transcript);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Build individual transcript item
  Widget _buildTranscriptItem(TranscriptModel transcript) {
    final isLocal = transcript.isLocal;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isLocal 
            ? Colors.blue.withOpacity(0.15) 
            : Colors.purple.withOpacity(0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isLocal 
              ? Colors.blueAccent.withOpacity(0.4) 
              : Colors.purpleAccent.withOpacity(0.4),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Speaker label
          Row(
            children: [
              Icon(
                isLocal ? Icons.person : Icons.person_outline,
                size: 16,
                color: isLocal ? Colors.blueAccent : Colors.purpleAccent,
              ),
              const SizedBox(width: 6),
              Text(
                isLocal ? 'You' : widget.contactName,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isLocal ? Colors.blueAccent : Colors.purpleAccent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          
          // Original text
          if (transcript.originalText.isNotEmpty)
            Text(
              transcript.originalText,
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: Colors.white.withOpacity(0.8),
                height: 1.4,
              ),
            ),
          
          // Divider
          if (transcript.originalText.isNotEmpty && transcript.translatedText.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Divider(
                color: Colors.white.withOpacity(0.1),
                thickness: 1,
              ),
            ),
          
          // Translated text
          if (transcript.translatedText.isNotEmpty)
            Text(
              transcript.translatedText,
              style: GoogleFonts.poppins(
                fontSize: 20, // Clearly Bigger
                fontWeight: FontWeight.bold,
                color: const Color(0xFF00E676), // Bright Green
                height: 1.3,
                shadows: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.8),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _getCallStatusText() {
    if (_isEnding) return 'Call Ended';
    
    // Check network connectivity first (simulated via WebSocket status)
    if (!_isWebSocketConnected) return 'Low Signal'; 

    if (!_isTimerStarted) {
        // More robust "Connecting..." logic
        // If we are waiting for partner or handshake
        return 'Connecting...';
    }
    
    // "Connecting..." phase after pick up
    if (!_isConnectionReady) return 'Connecting...';
    
    return _formatTime(_secondsElapsed);
  }


}

// Custom Painter for "Three Waves + Brake" Animation
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
    double activeDuration = 0.7; 
    
    if (localT < 0.0 || localT > activeDuration) return;

    double progress = localT / activeDuration;
    
    // Simple Easing
    double radius = maxRadius * progress;

    double opacity = 1.0 - progress;
    if (opacity < 0) opacity = 0;
    if (opacity > 1) opacity = 1;

    final paint = Paint()
      ..color = color.withOpacity(opacity * 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4 * (1-progress);

    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(covariant RipplePainter oldDelegate) => true;
}
