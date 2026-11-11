import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class AlarmDatabase {
  static final AlarmDatabase instance = AlarmDatabase._init();
  static Database? _database;

  AlarmDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('realme_alarms.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future _createDB(Database db, int version) async {
    // Alarm Groups Table
    await db.execute('''
      CREATE TABLE alarm_groups (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        duration_hours INTEGER NOT NULL,
        duration_minutes INTEGER NOT NULL,
        alarm_count INTEGER NOT NULL,
        interval_minutes INTEGER NOT NULL,
        status TEXT NOT NULL
      )
    ''');

    // Individual Alarm Records Table
    await db.execute('''
      CREATE TABLE alarm_records (
        id TEXT PRIMARY KEY,
        group_id TEXT NOT NULL,
        seq_index INTEGER NOT NULL,
        scheduled_timestamp INTEGER NOT NULL,
        time_string TEXT NOT NULL,
        label TEXT NOT NULL,
        status TEXT NOT NULL,
        intent_status TEXT NOT NULL,
        FOREIGN KEY (group_id) REFERENCES alarm_groups (id) ON DELETE CASCADE
      )
    ''');

    // History and Audit Log Table
    await db.execute('''
      CREATE TABLE alarm_history (
        id TEXT PRIMARY KEY,
        timestamp INTEGER NOT NULL,
        action TEXT NOT NULL,
        group_id TEXT,
        alarm_id TEXT,
        message TEXT NOT NULL,
        result_status TEXT NOT NULL
      )
    ''');
  }
}
