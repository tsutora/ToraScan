/// A user-created collection of scans, e.g. "Site A" or "Invoices".
///
/// Folders are pure organisation: deleting one never deletes the scans inside,
/// they simply become unfiled again.
class ScanFolder {
  ScanFolder({
    required this.id,
    required this.name,
    required this.createdAt,
    this.colorIndex = 0,
  });

  final String id;
  String name;
  final DateTime createdAt;

  /// Index into the folder gradient palette, so a folder keeps its colour.
  int colorIndex;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'name': name,
    'createdAt': createdAt.toIso8601String(),
    'colorIndex': colorIndex,
  };

  factory ScanFolder.fromJson(Map<String, dynamic> json) => ScanFolder(
    id: json['id'] as String,
    name: json['name'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
    colorIndex: (json['colorIndex'] as num?)?.toInt() ?? 0,
  );
}
