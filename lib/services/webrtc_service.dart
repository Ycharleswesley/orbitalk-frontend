import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'websocket_service.dart';

class WebRTCService {
  static final WebRTCService _instance = WebRTCService._internal();
  factory WebRTCService() => _instance;
  WebRTCService._internal();

  final WebSocketService _webSocketService = WebSocketService();
  
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;
  
  String? _currentRoomId;
  String? _remoteUserId; // Track who we are talking to

  bool _isCallActive = false;
  bool get isCallActive => _isCallActive;

  // Configuration for ICE Servers (STUN/TURN)
  // In production, you need a TURN server for reliable connections over 4G/LTE
  final Map<String, dynamic> _p2pConstraints = {
    'mandatory': {
      'OfferToReceiveAudio': true,
      'OfferToReceiveVideo': false, // Audio only for now
    },
    'optional': [],
  };

  final Map<String, dynamic> _iceServers = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'}, // Public Google STUN
      {'urls': 'stun:stun1.l.google.com:19302'},
    ]
  };

  Future<void> initialize({required String roomId, required String remoteUserId}) async {
    try {
      debugPrint('WebRTCService: Initializing for Room $roomId');
      _currentRoomId = roomId;
      _remoteUserId = remoteUserId;

      // 1. Create Peer Connection
      _peerConnection = await createPeerConnection(_iceServers);

      // 2. Get User Media (Microphone)
      final mediaConstraints = {
        'audio': true,
        'video': false,
      };
      
      _localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
      debugPrint('WebRTCService: Local Stream (Mic) obtained');

      // 3. Add Local Track to Connection
      _localStream!.getTracks().forEach((track) {
        _peerConnection!.addTrack(track, _localStream!);
      });

      // 4. Handle Lifecycle Events
      _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
        debugPrint('WebRTCService: Generated ICE Candidate');
        if (_webSocketService.isConnected) {
          _webSocketService.sendSignalingMessage({
             'type': 'candidate',
             'targetId': _remoteUserId,
             'candidate': {
               'candidate': candidate.candidate,
               'sdpMid': candidate.sdpMid,
               'sdpMLineIndex': candidate.sdpMLineIndex,
             }
          });
        }
      };

      _peerConnection!.onTrack = (RTCTrackEvent event) {
        debugPrint('WebRTCService: Remote Track Received');
        if (event.streams.isNotEmpty) {
          _remoteStream = event.streams[0];
          // We might need to notify UI to attach this stream, 
          // but for Audio-only, flutter_webrtc mostly handles internal routing via Helper/Plugin
          // However, keeping reference is good.
          
          // Force audio output to speaker/earpiece?
          // Usually handled by default session, but we can enforce:
          _remoteStream!.getAudioTracks()[0].enableSpeakerphone(false); // Default to earpiece
        }
      };

      _peerConnection!.onConnectionState = (RTCPeerConnectionState state) {
        debugPrint('WebRTCService: Connection State Change: $state');
      };

      _isCallActive = true;
      debugPrint('WebRTCService: Initialization Complete');

    } catch (e) {
      debugPrint('WebRTCService: Init Error: $e');
      dispose();
      rethrow;
    }
  }

  // Caller: Create Offer
  Future<void> makeCall() async {
    if (_peerConnection == null) return;

    try {
      debugPrint('WebRTCService: Creating OFFER...');
      RTCSessionDescription offer = await _peerConnection!.createOffer(_p2pConstraints);
      await _peerConnection!.setLocalDescription(offer);

      // Send Offer via WebSocket
      _webSocketService.sendSignalingMessage({
        'type': 'offer',
        'targetId': _remoteUserId,
        'sdp': offer.sdp,
        'sdpType': offer.type,
      });
      debugPrint('WebRTCService: OFFER Sent');

    } catch (e) {
      debugPrint('WebRTCService: MakeCall Error: $e');
    }
  }

  // Callee: Handle Offer & Create Answer
  Future<void> handleOffer(String sdp) async {
    if (_peerConnection == null) return;

    try {
      debugPrint('WebRTCService: Handling OFFER...');
      
      // Set Remote Description (The Offer)
      RTCSessionDescription remoteDesc = RTCSessionDescription(sdp, 'offer');
      await _peerConnection!.setRemoteDescription(remoteDesc);

      // Create Answer
      RTCSessionDescription answer = await _peerConnection!.createAnswer(_p2pConstraints);
      await _peerConnection!.setLocalDescription(answer);

      // Send Answer
      _webSocketService.sendSignalingMessage({
        'type': 'answer',
        'targetId': _remoteUserId,
        'sdp': answer.sdp,
        'sdpType': answer.type,
      });
      debugPrint('WebRTCService: ANSWER Sent');

    } catch (e) {
      debugPrint('WebRTCService: HandleOffer Error: $e');
    }
  }

  // Caller: Handle Answer
  Future<void> handleAnswer(String sdp) async {
    if (_peerConnection == null) return;
    try {
      debugPrint('WebRTCService: Handling ANSWER...');
      RTCSessionDescription remoteDesc = RTCSessionDescription(sdp, 'answer');
      await _peerConnection!.setRemoteDescription(remoteDesc);
      debugPrint('WebRTCService: Connected!');
    } catch (e) {
      debugPrint('WebRTCService: HandleAnswer Error: $e');
    }
  }

  // Both: Handle ICE Candidate
  Future<void> handleCandidate(Map<String, dynamic> candidateData) async {
    if (_peerConnection == null) return;
    try {
      debugPrint('WebRTCService: Adding ICE Candidate...');
      RTCIceCandidate candidate = RTCIceCandidate(
        candidateData['candidate'],
        candidateData['sdpMid'],
        candidateData['sdpMLineIndex'],
      );
      await _peerConnection!.addCandidate(candidate);
    } catch (e) {
      debugPrint('WebRTCService: HandleCandidate Error: $e');
    }
  }
  
  // Toggle Mic
  void toggleMute(bool mute) {
    if (_localStream != null && _localStream!.getAudioTracks().isNotEmpty) {
      _localStream!.getAudioTracks()[0].enabled = !mute;
      debugPrint('WebRTCService: Mic Muted: $mute');
    }
  }

  // Toggle Speaker
  void toggleSpeaker(bool enabled) {
    if (_localStream != null && _localStream!.getAudioTracks().isNotEmpty) {
       _localStream!.getAudioTracks()[0].enableSpeakerphone(enabled);
       debugPrint('WebRTCService: Speaker Enabled: $enabled');
    }
  }

  // Cleanup
  Future<void> dispose() async {
    debugPrint('WebRTCService: Disposing...');
    try {
      await _localStream?.dispose();
      _localStream = null;
      _remoteStream = null; // Don't dispose remote stream, just null ref
      await _peerConnection?.close();
      _peerConnection = null;
      _isCallActive = false;
    } catch (e) {
      debugPrint('WebRTCService: Dispose Error: $e');
    }
  }
}
