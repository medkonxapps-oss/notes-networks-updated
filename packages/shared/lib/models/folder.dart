class Folder {
  final String id;
  final String userId;
  final String name;
  final String colorHex;
  final int notesCount;
  final String? parentFolderId; // null = root folder
  final DateTime createdAt;

  const Folder({
    required this.id,
    required this.userId,
    required this.name,
    this.colorHex = '#4F46E5',
    this.notesCount = 0,
    this.parentFolderId,
    required this.createdAt,
  });

  bool get isRoot => parentFolderId == null;

  factory Folder.fromJson(Map<String, dynamic> j) => Folder(
    id: j['id'] as String,
    userId: j['user_id'] as String,
    name: j['name'] as String,
    colorHex: j['color_hex'] as String? ?? '#4F46E5',
    notesCount: j['notes_count'] as int? ?? 0,
    parentFolderId: j['parent_folder_id'] as String?,
    createdAt: DateTime.parse(j['created_at'] as String),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'name': name,
    'color_hex': colorHex,
    'notes_count': notesCount,
    'parent_folder_id': parentFolderId,
    'created_at': createdAt.toIso8601String(),
  };
}
