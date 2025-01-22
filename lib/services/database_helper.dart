import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/task.dart';  // Taskモデルをインポート

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('tasks.db');
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

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE tasks(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        isCompleted INTEGER NOT NULL DEFAULT 0,
        deadline TEXT,
        priority TEXT NOT NULL DEFAULT 'medium',
        category TEXT NOT NULL DEFAULT '未分類',
        taskColor INTEGER NOT NULL DEFAULT 0xFF2196F3,
        completedAt TEXT
      )
    ''');
  }

  // 全てのタスクを取得
  Future<List<Task>> getAllTasks() async {
    final db = await database;
    final result = await db.query('tasks');
    return result.map((json) => Task.fromMap(json)).toList();
  }

  // 新しいタスクを作成
  Future<Task> create(Task task) async {
    final db = await database;
    final id = await db.insert('tasks', task.toMap());
    return task.copy(id: id);
  }

  // タスクを更新
  Future<int> update(Task task) async {
    final db = await database;
    
    if (task.isCompleted) {
      task.completedAt = DateTime.now();
    } else {
      task.completedAt = null;
    }

    return db.update(
      'tasks',
      task.toMap(),
      where: 'id = ?',
      whereArgs: [task.id],
    );
  }

  // タスクを削除
  Future<int> delete(int id) async {
    final db = await database;
    return await db.delete(
      'tasks',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // 完了したタスクの数を取得
  Future<int> getCompletedTaskCount() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM tasks WHERE isCompleted = 1'
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  // 連続達成日数を取得
  Future<int> getCurrentStreak() async {
    final db = await database;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    // 今日完了したタスクがあるか確認
    final todayResult = await db.rawQuery(
      'SELECT COUNT(*) as count FROM tasks WHERE isCompleted = 1 AND date(completedAt) = date(?)',
      [today.toIso8601String()]
    );
    final hasTodayCompleted = (Sqflite.firstIntValue(todayResult) ?? 0) > 0;

    // 連続日数を計算
    var streak = 0;
    var currentDate = hasTodayCompleted ? today : today.subtract(const Duration(days: 1));

    while (true) {
      final result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM tasks WHERE isCompleted = 1 AND date(completedAt) = date(?)',
        [currentDate.toIso8601String()]
      );
      
      if ((Sqflite.firstIntValue(result) ?? 0) == 0) {
        break;
      }
      
      streak++;
      currentDate = currentDate.subtract(const Duration(days: 1));
    }

    return streak;
  }

  // データベースを閉じる
  Future<void> close() async {
    final db = await database;
    db.close();
  }
} 