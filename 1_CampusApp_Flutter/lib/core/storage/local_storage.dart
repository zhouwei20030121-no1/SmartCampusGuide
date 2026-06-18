import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class LocalStorage {
  static Database? _db;

  static Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  static Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'campus_cache.db');
    return openDatabase(path, version: 2, onCreate: _onCreate, onUpgrade: _onUpgrade);
  }

  static Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS cache_spot (
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        category TEXT,
        description TEXT,
        coverImage TEXT,
        images TEXT,
        audio_url TEXT,
        longitude REAL,
        latitude REAL,
        cached_at INTEGER
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS cache_map (
        tile_key TEXT PRIMARY KEY,
        tile_data BLOB,
        cached_at INTEGER
      )
    ''');
  }

  static Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      final columns = await db.rawQuery("PRAGMA table_info(cache_spot)");
      final names = columns.map((column) => column['name']?.toString()).toSet();
      if (!names.contains('coverImage')) {
        await db.execute('ALTER TABLE cache_spot ADD COLUMN coverImage TEXT');
      }
      if (!names.contains('images')) {
        await db.execute('ALTER TABLE cache_spot ADD COLUMN images TEXT');
      }
    }
  }

  static Future<void> saveSpotList(List<Map<String, dynamic>> spots) async {
    final db = await database;
    final batch = db.batch();
    for (final spot in spots) {
      spot['cached_at'] = DateTime.now().millisecondsSinceEpoch;
      batch.insert('cache_spot', spot,
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  static Future<List<Map<String, dynamic>>> getSpotList() async {
    final db = await database;
    return db.query('cache_spot');
  }

  static Future<void> clearAll() async {
    final db = await database;
    await db.delete('cache_spot');
    await db.delete('cache_map');
  }
}
