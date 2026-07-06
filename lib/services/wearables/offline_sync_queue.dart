import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class OfflineSyncQueue {
  OfflineSyncQueue._privateConstructor();
  static final OfflineSyncQueue instance =
      OfflineSyncQueue._privateConstructor();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final pathString = join(dbPath, 'caresync_offline_sync.db');

    return await openDatabase(
      pathString,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE offline_vitals (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            patient_id TEXT NOT NULL,
            type TEXT NOT NULL,
            value TEXT NOT NULL,
            unit TEXT NOT NULL,
            recorded_at TEXT NOT NULL,
            source TEXT NOT NULL,
            platform TEXT,
            device_name TEXT,
            device_id TEXT,
            confidence REAL,
            duplicate_hash TEXT
          )
        ''');
      },
    );
  }

  Future<void> enqueueVital(Map<String, dynamic> vital) async {
    final db = await database;
    await db.insert('offline_vitals', {
      'patient_id': vital['patient_id'],
      'type': vital['type'],
      'value': vital['value'],
      'unit': vital['unit'],
      'recorded_at': vital['recorded_at'],
      'source': vital['source'],
      'platform': vital['platform'],
      'device_name': vital['device_name'],
      'device_id': vital['device_id'],
      'confidence': vital['confidence'],
      'duplicate_hash': vital['duplicate_hash'],
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> getQueuedVitals() async {
    final db = await database;
    return await db.query('offline_vitals', orderBy: 'id ASC');
  }

  Future<void> removeVital(int id) async {
    final db = await database;
    await db.delete('offline_vitals', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> clearQueue() async {
    final db = await database;
    await db.delete('offline_vitals');
  }
}
