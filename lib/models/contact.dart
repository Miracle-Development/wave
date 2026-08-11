class Contact {
  final String id;
  final String name;
  final String? note;
  final DateTime addedAt;

  Contact({
    required this.id,
    required this.name,
    this.note,
    required this.addedAt,
  });

  String get displayName => note?.isNotEmpty == true ? note! : name;

  Map<String, dynamic> toJson() => {
        'contactId': id,
        'name': name,
        'note': note,
        'addedAt': addedAt.toIso8601String(),
      };

  factory Contact.fromJson(Map<String, dynamic> json) => Contact(
        id: json['contactId'] as String,
        name: json['name'] as String,
        note: json['note'] as String?,
        addedAt: DateTime.parse(json['addedAt'] as String),
      );
}