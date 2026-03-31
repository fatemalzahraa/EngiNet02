import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/book_model.dart';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';





class BookDatabase {
  static final BookDatabase instance = BookDatabase._init();
  static Database? _database;

  BookDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('enginet.db');
    return _database!;
  }

  Future<Database> _initDB(String fileName) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, fileName);
    debugPrint("Database path: $path");
    
    final exists = await databaseExists(path);
    debugPrint("Database exists: $exists");
    
    if (!exists) {
      debugPrint("Copying database from assets...");
      ByteData data =
          await rootBundle.load('assets/database/$fileName');
      List<int> bytes =
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);

      await File(path).writeAsBytes(bytes, flush: true);
      debugPrint("Database copied successfully");
    }

    return await openDatabase(
      path,
      version: 1,
    );
  }


  Future<List<Book>> getAllBooks() async {
    final db = await instance.database;
    debugPrint("DB opened");
    final tables = await db.rawQuery(
    "SELECT name FROM sqlite_master WHERE type='table'"
  );
  debugPrint(tables.toString());
    final result = await db.query('book');
    return result.map((e) => Book.fromMap(e)).toList();
  }
}
