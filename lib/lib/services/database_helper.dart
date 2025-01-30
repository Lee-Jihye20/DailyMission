import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/task.dart';  // Taskモデルをインポート
import 'dart:async';

class DatabaseHelper {
  static final _databaseName = "my_database.db";
  static final _databaseVersion = 6;  // バージョンを上げる

  static Database? _database;

  // Singletonパターン
  DatabaseHelper._privateConstructor();
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), _databaseName);
    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  // テーブル作成時
  Future _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE tasks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT,
        deadline TEXT,
        priority INTEGER,
        category TEXT,
        taskColor INTEGER,
        isCompleted INTEGER,
        completedAt TEXT,
        taskPriority INTEGER,
        `order` INTEGER,
        importance INTEGER
      )
    ''');
  }

  // バージョンアップ時（マイグレーション）
  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    print('Upgrading database from version $oldVersion to $newVersion');
    
    if (oldVersion < 2) {
      print('Adding completedAt column...');
      await db.execute('ALTER TABLE tasks ADD COLUMN completedAt TEXT');
    }
    if (oldVersion < 4) {
      print('Adding taskPriority column...');
      var result = await db.rawQuery("PRAGMA table_info(tasks)");
      bool columnExists = result.any((column) => column['name'] == 'taskPriority');
      if (!columnExists) {
        await db.execute("ALTER TABLE tasks ADD COLUMN taskPriority INTEGER DEFAULT 1");
      }
    }
    if (oldVersion < 5) {
      print('Adding order column...');
      var result = await db.rawQuery("PRAGMA table_info(tasks)");
      bool columnExists = result.any((column) => column['name'] == 'order');
      if (!columnExists) {
        await db.execute("ALTER TABLE tasks ADD COLUMN `order` INTEGER DEFAULT 0");
      }
    }
    if (oldVersion < 6) {
      print('Adding importance column...');
      var result = await db.rawQuery("PRAGMA table_info(tasks)");
      bool columnExists = result.any((column) => column['name'] == 'importance');
      if (!columnExists) {
        await db.execute("ALTER TABLE tasks ADD COLUMN importance INTEGER DEFAULT 1");
      }
    }
  }

  // 全てのタスクを取得
  Future<List<Task>> getAllTasks() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'tasks',
      orderBy: '`order` ASC',  // orderをバッククォートで囲む
    );
    return List.generate(maps.length, (i) => Task.fromMap(maps[i]));
  }

  // タスクを取得する際に順序でソート
  Future<List<Task>> getTodayTasks() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'tasks',
      where: 'date(deadline) = date(?)',
      whereArgs: [DateTime.now().toIso8601String()],
      orderBy: '`order` ASC',  // orderで昇順ソート
    );
    return List.generate(maps.length, (i) => Task.fromMap(maps[i]));
  }

  // 新しいタスクを作成
  Future<Task> create(Task task) async {
    final db = await database;
    
    // 最大の order 値を取得
    final List<Map<String, dynamic>> result = await db.rawQuery(
      'SELECT MAX(`order`) as maxOrder FROM tasks'
    );
    final int maxOrder = Sqflite.firstIntValue(result) ?? -1;
    
    // 新しいタスクの order を設定
    final taskMap = task.toMap();
    taskMap['order'] = maxOrder + 1;
    
    final id = await db.insert('tasks', taskMap);
    return task.copyWith(
      id: id,
      order: maxOrder + 1,
    );
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
    await _tasksUpdateController.close();
    final db = await database;
    db.close();
  }

  // タスクの更新
  Future<int> updateTask(int id, String title, String deadline, int priority, String category, int taskColor, int isCompleted, String? completedAt) async {
    Database db = await instance.database;

    return await db.rawUpdate('''
      UPDATE tasks
      SET
        title = ?,
        deadline = ?,
        priority = ?,
        category = ?,
        taskColor = ?,
        isCompleted = ?,
        completedAt = ?
      WHERE id = ?
    ''', [title, deadline, priority, category, taskColor, isCompleted, completedAt, id]);
  }

  // データベースの削除と再作成（開発環境用）
  Future<void> deleteDatabaseFile() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _databaseName);
    await databaseFactory.deleteDatabase(path);  // databaseFactoryを使用
    print('Database deleted: $path');
  }

  // テーブルのスキーマを確認するためのメソッド
  Future<void> checkSchema() async {
    Database db = await instance.database;
    List<Map<String, dynamic>> result = await db.rawQuery('PRAGMA table_info(tasks);');
    print('Schema for tasks table: $result');
  }

  // 列の存在を確認するためのメソッド
  Future<void> checkColumnExists() async {
    final db = await database;
    final result = await db.rawQuery("PRAGMA table_info(tasks);");
    print('Column info: $result');
  }

  Future<int> insert(Task task) async {
    final db = await database;
    return await db.insert('tasks', task.toMap());
  }

  // データベースを再作成するメソッド
  Future<void> recreateDatabase() async {
    print('Recreating database...');
    
    // 既存のデータベースを閉じる
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
    
    // データベースファイルを削除
    String path = join(await getDatabasesPath(), _databaseName);
    print('Deleting database at: $path');
    await databaseFactory.deleteDatabase(path);  // databaseFactoryを使用
    
    // データベースを再作成
    _database = await _initDatabase();
    print('Database recreated successfully');
  }

  // データベースを削除するメソッド
  Future<void> deleteDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _databaseName);
    await databaseFactory.deleteDatabase(path);  // databaseFactoryを使用
  }

  // StreamController を追加
  final _tasksUpdateController = StreamController<void>.broadcast();
  
  // Stream を公開
  Stream<void> get onTasksUpdated => _tasksUpdateController.stream;

  // 通知メソッドを追加
  void notifyTasksUpdated() {
    _tasksUpdateController.add(null);
  }

  // dispose メソッドを追加（必要に応じて）
  void dispose() {
    _tasksUpdateController.close();
  }

  // アプリ起動時にデータベースを再作成
  static Future<void> initializeDatabase() async {
    await instance.recreateDatabase();
  }
} 