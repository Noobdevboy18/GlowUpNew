class MakeupHistory {
  final String id;
  final String imageUrl;
  final String context;
  final DateTime timestamp;
  final Map<String, dynamic> suggestion;

  MakeupHistory({
    required this.id,
    required this.imageUrl,
    required this.context,
    required this.timestamp,
    required this.suggestion,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'imageUrl': imageUrl,
      'context': context,
      'timestamp': timestamp.toIso8601String(),
      'suggestion': suggestion,
    };
  }

  factory MakeupHistory.fromMap(Map<String, dynamic> map) {
    return MakeupHistory(
      id: map['id'],
      imageUrl: map['imageUrl'],
      context: map['context'],
      timestamp: DateTime.parse(map['timestamp']),
      suggestion: map['suggestion'],
    );
  }
} 