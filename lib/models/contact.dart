class Contact {
  final String id;
  final String displayName;
  Contact({required this.id, required this.displayName});
  Map<String, dynamic> toJson() => {"id": id, "displayName": displayName};
  factory Contact.fromJson(Map<String, dynamic> j) =>
      Contact(id: j['id'] as String, displayName: j['displayName'] as String);
}
