import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/task.dart';

/// SQLite persistence for tasks and (for recurring tasks) their per-day
/// completion records, which drive the streak counters.
class TaskDb {
  TaskDb._();
  static final TaskDb instance = TaskDb._();

  Database? _db;

  Future<Database> get db async =>
      _db ??= await openDatabase(
        p.join(await getDatabasesPath(), 'pert_planner.db'),
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE tasks(
              id TEXT PRIMARY KEY,
              parentId TEXT,
              title TEXT NOT NULL,
              notes TEXT,
              optimisticMin REAL NOT NULL,
              likelyMin REAL NOT NULL,
              pessimisticMin REAL NOT NULL,
              scheduledStart INTEGER NOT NULL,
              sortOrder INTEGER NOT NULL DEFAULT 0,
              completed INTEGER NOT NULL DEFAULT 0,
              completedAt INTEGER,
              recurrence INTEGER NOT NULL DEFAULT 0,
              weekdays TEXT
            )
          ''');
          await db.execute('''
            CREATE TABLE completions(
              taskId TEXT NOT NULL,
              day TEXT NOT NULL,
              PRIMARY KEY (taskId, day)
            )
          ''');
        },
      );

  Future<List<PertTask>> fetchTasks() async {
    final rows = await (await db).query('tasks', orderBy: 'sortOrder ASC');
    return rows.map(PertTask.fromMap).toList();
  }

  Future<void> upsertTask(PertTask t) async {
    await (await db).insert('tasks', t.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteTask(String id) async {
    final d = await db;
    await d.delete('tasks', where: 'id = ?', whereArgs: [id]);
    await d.delete('tasks', where: 'parentId = ?', whereArgs: [id]);
    await d.delete('completions', where: 'taskId = ?', whereArgs: [id]);
  }

  /// Returns taskId -> set of completed day keys (yyyy-MM-dd).
  Future<Map<String, Set<String>>> fetchCompletions() async {
    final rows = await (await db).query('completions');
    final map = <String, Set<String>>{};
    for (final r in rows) {
      map.putIfAbsent(r['taskId'] as String, () => <String>{})
          .add(r['day'] as String);
    }
    return map;
  }

  Future<void> addCompletion(String taskId, String day) async {
    await (await db).insert('completions', {'taskId': taskId, 'day': day},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> removeCompletion(String taskId, String day) async {
    await (await db).delete('completions',
        where: 'taskId = ? AND day = ?', whereArgs: [taskId, day]);
  }
}
