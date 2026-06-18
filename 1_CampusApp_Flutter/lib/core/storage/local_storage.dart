import 'dart:convert';

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class LocalStorage {
  static Database? _db;

  static Future<Database> get database async {
    if (_db != null && _db!.isOpen) return _db!;
    _db = await _initDb();
    return _db!;
  }

  static Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'campus_cache.db');
    return openDatabase(
      path,
      version: 3,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  static Future<void> _onCreate(Database db, int version) async {
    await _createSpotTable(db);
    await _createMapTable(db);
    await _createGuideTable(db);
    await _createRouteTable(db);
    await _createGraphTable(db);
    await _createMetaTable(db);
  }

  static Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      final columns = await db.rawQuery('PRAGMA table_info(cache_spot)');
      final names = columns.map((column) => column['name']?.toString()).toSet();
      if (!names.contains('coverImage')) {
        await db.execute('ALTER TABLE cache_spot ADD COLUMN coverImage TEXT');
      }
      if (!names.contains('images')) {
        await db.execute('ALTER TABLE cache_spot ADD COLUMN images TEXT');
      }
    }
    if (oldVersion < 3) {
      final columns = await db.rawQuery('PRAGMA table_info(cache_spot)');
      final names = columns.map((column) => column['name']?.toString()).toSet();
      if (!names.contains('visitCount')) {
        await db.execute(
            'ALTER TABLE cache_spot ADD COLUMN visitCount INTEGER DEFAULT 0');
      }
      await _createGuideTable(db);
      await _createRouteTable(db);
      await _createGraphTable(db);
      await _createMetaTable(db);
    }
  }

  static Future<void> _createSpotTable(Database db) async {
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
        visitCount INTEGER DEFAULT 0,
        cached_at INTEGER
      )
    ''');
  }

  static Future<void> _createMapTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS cache_map (
        tile_key TEXT PRIMARY KEY,
        tile_data BLOB,
        cached_at INTEGER
      )
    ''');
  }

  static Future<void> _createGuideTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS cache_guide (
        spot_id INTEGER NOT NULL,
        language TEXT NOT NULL DEFAULT 'zh',
        title TEXT,
        script_content TEXT,
        audio_url TEXT,
        cached_at INTEGER,
        PRIMARY KEY (spot_id, language)
      )
    ''');
  }

  static Future<void> _createRouteTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS cache_route (
        id INTEGER PRIMARY KEY,
        route_name TEXT,
        target_audience TEXT,
        estimated_time INTEGER,
        description TEXT,
        spot_ids TEXT,
        spots_json TEXT,
        cached_at INTEGER
      )
    ''');
  }

  static Future<void> _createGraphTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS cache_graph_edge (
        from_id INTEGER NOT NULL,
        to_id INTEGER NOT NULL,
        distance REAL NOT NULL,
        PRIMARY KEY (from_id, to_id)
      )
    ''');
  }

  static Future<void> _createMetaTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS cache_meta (
        key TEXT PRIMARY KEY,
        value TEXT
      )
    ''');
  }

  static Map<String, dynamic> _normalizeSpotRow(Map<String, dynamic> spot) {
    final row = Map<String, dynamic>.from(spot);
    row['cached_at'] = DateTime.now().millisecondsSinceEpoch;
    final images = row['images'];
    if (images != null && images is! String) {
      row['images'] = images is List ? images.join(',') : images.toString();
    }
    return row;
  }

  static Future<void> saveSpotList(List<Map<String, dynamic>> spots) async {
    final db = await database;
    final batch = db.batch();
    for (final spot in spots) {
      batch.insert(
        'cache_spot',
        _normalizeSpotRow(spot),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  static Future<List<Map<String, dynamic>>> getSpotList() async {
    final db = await database;
    return db.query('cache_spot', orderBy: 'name ASC');
  }

  static Future<List<Map<String, dynamic>>> searchSpots(String keyword) async {
    final q = keyword.trim();
    if (q.isEmpty) return getSpotList();
    final db = await database;
    final like = '%$q%';
    return db.query(
      'cache_spot',
      where: 'name LIKE ? OR category LIKE ? OR description LIKE ?',
      whereArgs: [like, like, like],
      orderBy: 'name ASC',
    );
  }

  static Future<void> saveGuideContent(List<Map<String, dynamic>> guides) async {
    if (guides.isEmpty) return;
    final db = await database;
    final batch = db.batch();
    for (final guide in guides) {
      batch.insert(
        'cache_guide',
        {
          'spot_id': guide['spot_id'],
          'language': guide['language'] ?? 'zh',
          'title': guide['title'],
          'script_content': guide['script_content'],
          'audio_url': guide['audio_url'],
          'cached_at': DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  static Future<Map<String, dynamic>?> getGuideContent(int spotId,
      {String language = 'zh'}) async {
    final db = await database;
    final rows = await db.query(
      'cache_guide',
      where: 'spot_id = ? AND language = ?',
      whereArgs: [spotId, language],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  static Future<List<Map<String, dynamic>>> getAllGuides() async {
    final db = await database;
    return db.query('cache_guide', orderBy: 'spot_id ASC');
  }

  static Future<void> saveRouteList(List<Map<String, dynamic>> routes) async {
    final db = await database;
    final batch = db.batch();
    batch.delete('cache_route');
    for (final route in routes) {
      batch.insert(
        'cache_route',
        {
          'id': route['id'],
          'route_name': route['route_name'],
          'target_audience': route['target_audience'],
          'estimated_time': route['estimated_time'],
          'description': route['description'],
          'spot_ids': route['spot_ids'],
          'spots_json': route['spots_json'],
          'cached_at': DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  static Future<List<Map<String, dynamic>>> getRouteList() async {
    final db = await database;
    return db.query('cache_route', orderBy: 'id ASC');
  }

  static Future<void> saveGraphEdges(List<Map<String, dynamic>> edges) async {
    final db = await database;
    final batch = db.batch();
    batch.delete('cache_graph_edge');
    for (final edge in edges) {
      batch.insert(
        'cache_graph_edge',
        {
          'from_id': edge['from_id'],
          'to_id': edge['to_id'],
          'distance': edge['distance'],
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  static Future<List<Map<String, dynamic>>> getGraphEdges() async {
    final db = await database;
    return db.query('cache_graph_edge');
  }

  static Future<void> setMeta(String key, String value) async {
    final db = await database;
    await db.insert(
      'cache_meta',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<String?> getMeta(String key) async {
    final db = await database;
    final rows = await db.query(
      'cache_meta',
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['value']?.toString();
  }

  static Future<Map<String, int>> getCacheStats() async {
    final db = await database;
    final spotCount = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM cache_spot'),
        ) ??
        0;
    final guideCount = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM cache_guide'),
        ) ??
        0;
    final routeCount = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM cache_route'),
        ) ??
        0;
    final edgeCount = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM cache_graph_edge'),
        ) ??
        0;
    return {
      'spots': spotCount,
      'guides': guideCount,
      'routes': routeCount,
      'graphEdges': edgeCount,
    };
  }

  /// 仅清空离线缓存表，不影响数据库连接。
  static Future<void> clearOfflineCache() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('cache_spot');
      await txn.delete('cache_map');
      await txn.delete('cache_guide');
      await txn.delete('cache_route');
      await txn.delete('cache_graph_edge');
      await txn.delete('cache_meta');
    });
  }

  @Deprecated('Use clearOfflineCache')
  static Future<void> clearAll() => clearOfflineCache();

  static String encodeJson(Object? value) => jsonEncode(value);

  static dynamic decodeJson(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      return jsonDecode(raw);
    } catch (_) {
      return null;
    }
  }
}
