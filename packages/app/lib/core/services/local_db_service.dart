import 'dart:io';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class LocalNote {
  final String id;
  final String title;
  final String subject;
  final String authorName;
  final String localPath;
  final String fileType;
  final DateTime downloadedAt;

  LocalNote({
    required this.id,
    required this.title,
    required this.subject,
    required this.authorName,
    required this.localPath,
    required this.fileType,
    required this.downloadedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'subject': subject,
      'authorName': authorName,
      'localPath': localPath,
      'fileType': fileType,
      'downloadedAt': downloadedAt.toIso8601String(),
    };
  }

  factory LocalNote.fromMap(Map<String, dynamic> map) {
    return LocalNote(
      id: map['id'],
      title: map['title'],
      subject: map['subject'],
      authorName: map['authorName'],
      localPath: map['localPath'],
      fileType: map['fileType'],
      downloadedAt: DateTime.parse(map['downloadedAt']),
    );
  }
}

class LocalDbService {
  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'offline_notes.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE downloaded_notes (
            id TEXT PRIMARY KEY,
            title TEXT,
            subject TEXT,
            authorName TEXT,
            localPath TEXT,
            fileType TEXT,
            downloadedAt TEXT
          )
        ''');
      },
    );
  }

  Future<void> saveNote(LocalNote note) async {
    final db = await database;
    await db.insert('downloaded_notes', note.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<LocalNote>> getAllDownloadedNotes() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('downloaded_notes', orderBy: 'downloadedAt DESC');
    return List.generate(maps.length, (i) => LocalNote.fromMap(maps[i]));
  }

  Future<void> deleteNote(String id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('downloaded_notes', where: 'id = ?', whereArgs: [id]);
    if (maps.isNotEmpty) {
      final path = maps.first['localPath'];
      final file = File(path);
      if (await file.exists()) await file.delete();
    }
    await db.delete('downloaded_notes', where: 'id = ?', whereArgs: [id]);
  }

  Future<bool> isDownloaded(String id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('downloaded_notes', where: 'id = ?', whereArgs: [id]);
    return maps.isNotEmpty;
  }
}
