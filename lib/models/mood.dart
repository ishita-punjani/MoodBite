class Mood {
  const Mood({
    required this.id,
    required this.label,
    required this.emoji,
    this.description = '',
  });

  static const columns = 'id, label, emoji, description';

  factory Mood.fromJson(Map<String, dynamic> json) => Mood(
        id: json['id'] as String,
        label: json['label'] as String,
        emoji: json['emoji'] as String,
        description: json['description'] as String? ?? '',
      );

  final String id;
  final String label;
  final String emoji;
  final String description;
}
