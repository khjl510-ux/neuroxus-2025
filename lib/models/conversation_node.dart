import 'cognitive_score.dart';

enum Role {
  user,
  assistant,
  system
}

class ConversationNode {
  final String id;
  final Role role; // Added Role field
  final String content;
  final DateTime timestamp;
  final CognitiveScore scores;
  final String logicSchema;
  final Map<String, dynamic> metadata;

  ConversationNode({
    required this.id,
    this.role = Role.user, // Default
    required this.content,
    required this.timestamp,
    required this.scores,
    required this.logicSchema,
    required this.metadata,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'role': role.toString().split('.').last,
      'content': content,
      'timestamp': timestamp.toIso8601String(),
      'scores': scores.toMap(),
      'logicSchema': logicSchema,
      'metadata': metadata,
    };
  }

  factory ConversationNode.fromMap(Map<String, dynamic> map) {
    return ConversationNode(
      id: map['id'],
      role: Role.values.firstWhere((e) => e.toString().split('.').last == map['role'], orElse: () => Role.user),
      content: map['content'],
      timestamp: DateTime.parse(map['timestamp']),
      scores: CognitiveScore.fromMap(map['scores']),
      logicSchema: map['logicSchema'] ?? '',
      metadata: map['metadata'] ?? {},
    );
  }
}
