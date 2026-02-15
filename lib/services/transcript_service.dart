import 'dart:async';
import 'package:flutter/material.dart';

import '../models/transcript_model.dart';

class TranscriptService {
  static final TranscriptService _instance = TranscriptService._internal();
  factory TranscriptService() => _instance;
  TranscriptService._internal();

  final StreamController<List<TranscriptModel>> _transcriptController =
      StreamController<List<TranscriptModel>>.broadcast();

  final List<TranscriptModel> _transcripts = [];

  // Get transcript stream for UI updates (replay latest on new listeners)
  Stream<List<TranscriptModel>> get transcriptStream async* {
    yield List.unmodifiable(_transcripts);
    yield* _transcriptController.stream;
  }

  // Get current transcripts
  List<TranscriptModel> get transcripts => List.unmodifiable(_transcripts);

  // Add a new transcript
  void addTranscript(TranscriptModel transcript) {
    _transcripts.add(transcript);
    _transcriptController.add(List.from(_transcripts));
    debugPrint('TranscriptService: Added transcript - ${transcript.originalText}');
  }

  // Add transcript with text
  void addTranscriptText({
    required String id,
    required String originalText,
    required String translatedText,
    required bool isLocal,
    required String speaker,
  }) {
    final transcript = TranscriptModel(
      id: id,
      originalText: originalText,
      translatedText: translatedText,
      timestamp: DateTime.now(),
      isLocal: isLocal,
      speaker: speaker,
    );
    addTranscript(transcript);
  }

  // Clear all transcripts
  void clearTranscripts() {
    _transcripts.clear();
    _transcriptController.add([]);
    debugPrint('TranscriptService: Cleared all transcripts');
  }

  // Dispose
  void dispose() {
    _transcriptController.close();
  }
}
