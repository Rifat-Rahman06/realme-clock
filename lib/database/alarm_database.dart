import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/alarm_models.dart';

/// Local record of every alarm this app asked the Clock app to schedule.
///
/// This is an audit log, not the alarm source of truth. The Realme Clock app
/// owns the real alarms and this database cannot read them back.
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

    return openDatabase(
      path,
      version: 1,
      onConfigure: _configureDB,
      onCreate: _createDB,
    );
  }

  Future<void> _configureDB(Database db) async {
    // SQLite ignores ON DELETE CASCADE unless foreign keys are enabled.
    await db.execute('PRAGMA foreign_keys = ON');
  }

  Future<void> _createDB(Database db, int version) async {
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

  Future<void> saveGroup(AlarmGroupRecord group) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.insert(
        'alarm_groups',
        {
          'id': group.id,
          'name': group.title,
          'created_at': group.createdAt.millisecondsSinceEpoch,
          'duration_hours': group.durationHours,
          'duration_minutes': group.durationMinutes,
          'alarm_count': group.alarmCount,
          'interval_minutes': group.intervalMinutes,
          'status': group.allDelivered ? 'sent' : 'partial',
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      for (final alarm in group.alarms) {
        await txn.insert(
          'alarm_records',
          {
            'id': alarm.id,
            'group_id': group.id,
            'seq_index': alarm.sequenceIndex,
            'scheduled_timestamp': alarm.scheduledAt.millisecondsSinceEpoch,
            'time_string': alarm.displayTime,
            'label': 'Alarm (${alarm.sequenceIndex}/${alarm.totalInGroup})',
            'status': alarm.delivered ? 'sent' : 'failed',
            'intent_status': alarm.delivered
                ? (alarm.targetPackage ?? 'sent')
                : (alarm.error ?? 'failed'),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  Future<List<AlarmGroupRecord>> loadGroups() async {
    final db = await database;
    final groupRows = await db.query(
      'alarm_groups',
      orderBy: 'created_at DESC',
    );

    final groups = <AlarmGroupRecord>[];
    for (final row in groupRows) {
      final groupId = row['id'] as String;
      final alarmRows = await db.query(
        'alarm_records',
        where: 'group_id = ?',
        whereArgs: [groupId],
        orderBy: 'seq_index ASC',
      );

      final alarms = alarmRows.map((alarmRow) {
        final status = alarmRow['status'] as String? ?? 'sent';
        final intentStatus = alarmRow['intent_status'] as String?;
        return AlarmItemRecord(
          id: alarmRow['id'] as String,
          groupId: groupId,
          scheduledAt: DateTime.fromMillisecondsSinceEpoch(
            alarmRow['scheduled_timestamp'] as int,
          ),
          sequenceIndex: alarmRow['seq_index'] as int,
          totalInGroup: row['alarm_count'] as int,
          delivered: status == 'sent',
          targetPackage: status == 'sent' ? intentStatus : null,
          error: status == 'sent' ? null : intentStatus,
        );
      }).toList();

      groups.add(
        AlarmGroupRecord(
          id: groupId,
          title: row['name'] as String,
          initialTargetTime: alarms.isEmpty ? '' : alarms.first.displayTime,
          alarmCount: row['alarm_count'] as int,
          intervalMinutes: row['interval_minutes'] as int,
          durationHours: row['duration_hours'] as int,
          durationMinutes: row['duration_minutes'] as int,
          createdAt: DateTime.fromMillisecondsSinceEpoch(
            row['created_at'] as int,
          ),
          alarms: alarms,
        ),
      );
    }
    return groups;
  }

  Future<void> deleteAlarm(String groupId, String alarmId) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete(
        'alarm_records',
        where: 'id = ? AND group_id = ?',
        whereArgs: [alarmId, groupId],
      );
      final remaining = Sqflite.firstIntValue(
        await txn.rawQuery(
          'SELECT COUNT(*) FROM alarm_records WHERE group_id = ?',
          [groupId],
        ),
      );
      if ((remaining ?? 0) == 0) {
        await txn.delete('alarm_groups', where: 'id = ?', whereArgs: [groupId]);
      }
    });
  }

  Future<void> deleteGroup(String groupId) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('alarm_records', where: 'group_id = ?', whereArgs: [groupId]);
      await txn.delete('alarm_groups', where: 'id = ?', whereArgs: [groupId]);
    });
  }

  Future<void> logHistory({
    required String action,
    String? groupId,
    String? alarmId,
    required String message,
    required String resultStatus,
  }) async {
    final db = await database;
    await db.insert(
      'alarm_history',
      {
        'id': 'log_${DateTime.now().microsecondsSinceEpoch}',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'action': action,
        'group_id': groupId,
        'alarm_id': alarmId,
        'message': message,
        'result_status': resultStatus,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> clearAll() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('alarm_records');
      await txn.delete('alarm_groups');
      await txn.delete('alarm_history');
    });
  }
}
