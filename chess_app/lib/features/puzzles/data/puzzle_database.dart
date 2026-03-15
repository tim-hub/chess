import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

/// Manages the puzzle SQLite database asset.
/// Copies from Flutter assets to the documents directory on first run.
class PuzzleDatabase {
  static Database? _db;

  static Future<Database> getInstance() async {
    _db ??= await _open();
    return _db!;
  }

  static Future<Database> _open() async {
    final dir = await getApplicationDocumentsDirectory();
    final dbPath = path.join(dir.path, 'puzzles.db');

    // Copy from assets if not present
    if (!File(dbPath).existsSync()) {
      await _copyFromAssets(dbPath);
    }

    return openDatabase(dbPath, readOnly: true).timeout(
      const Duration(seconds: 30),
      onTimeout: () => throw TimeoutException('Puzzle database open timed out'),
    );
  }

  static Future<void> _copyFromAssets(String destPath) async {
    final data = await rootBundle.load('assets/puzzles.db');
    final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    await File(destPath).writeAsBytes(bytes);
  }

  // For testing only
  static void setTestDatabase(Database db) => _db = db;
  static void clearTestDatabase() => _db = null;
}
