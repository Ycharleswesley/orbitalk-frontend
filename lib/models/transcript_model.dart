class TranscriptModel {
  final String id;
  final String originalText;
  final String translatedText;
  final DateTime timestamp;
  final bool isLocal; // true if from current user
  final String speaker; // 'user' or 'contact'

  TranscriptModel({
    required this.id,
    required this.originalText,
    required this.translatedText,
    required this.timestamp,
    required this.isLocal,
    required this.speaker,
  });

  factory TranscriptModel.fromMap(Map<String, dynamic> map) {
    return TranscriptModel(
      id: map['id'] ?? '',
      originalText: map['originalText'] ?? '',
      translatedText: map['translatedText'] ?? '',
      timestamp: DateTime.parse(map['timestamp']),
      isLocal: map['isLocal'] ?? false,
      speaker: map['speaker'] ?? 'user',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'originalText': originalText,
      'translatedText': translatedText,
      'timestamp': timestamp.toIso8601String(),
      'isLocal': isLocal,
      'speaker': speaker,
    };
  }
}
