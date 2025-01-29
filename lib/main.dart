import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';  // HapticFeedbackのために追加
import 'package:intl/date_symbol_data_local.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'models/task.dart';
import 'services/database_helper.dart';
import 'services/notification_service.dart';
import 'screens/calendar_screen.dart';
import 'screens/settings_screen.dart';  // 設定画面のインポートを追加
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/profile_screen.dart';  // ProfileScreenを追加する必要があります
import 'package:provider/provider.dart';
import 'models/user.dart';
import 'dart:math' show max, min;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // データベースを初期化
  try {
    // データベースを完全に削除
    await DatabaseHelper.instance.deleteDatabase();
    
    // データベースを新規作成
    final db = await DatabaseHelper.instance.database;
    print('Database initialized successfully');
  } catch (e) {
    print('Error during database initialization: $e');
  }
  
  await Future.wait([
    initializeDateFormatting('ja_JP'),
    initializeDateFormatting('ja'),
  ]);
  tz.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('Asia/Tokyo'));
  
  runApp(
    ChangeNotifierProvider(
      create: (context) => User(
        nickname: "Default User",
      ),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _isDarkMode = false;
  List<Task> _tasks = []; // 現在のタスク一覧を保持

  @override
  void initState() {
    super.initState();
    _loadSettings();
    NotificationService().initialize();
    updateTaskList(); // アプリ起動時にタスクを読み込む
    
    // データベースの変更を監視するリスナーを追加
    DatabaseHelper.instance.onTasksUpdated.listen((_) {
      updateTaskList();
    });
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkMode = prefs.getBool('isDarkMode') ?? false;
    });
  }

  void _handleDarkModeChanged(bool value) {
    setState(() {
      _isDarkMode = value;
    });
  }

  Future<void> updateTaskList() async {
    // データベースからタスクを取得して更新
    final tasks = await DatabaseHelper.instance.getAllTasks();
    setState(() {
      _tasks = tasks;
    });
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoApp(
      title: '毎日のタスク',
      theme: CupertinoThemeData(
        primaryColor: const Color(0xFFFF2A6D),
        brightness: _isDarkMode ? Brightness.dark : Brightness.light,
        scaffoldBackgroundColor: _isDarkMode 
            ? CupertinoColors.black 
            : CupertinoColors.systemBackground,
        barBackgroundColor: _isDarkMode 
            ? CupertinoColors.black 
            : CupertinoColors.systemBackground,
      ),
      localizationsDelegates: const [
        DefaultMaterialLocalizations.delegate,
        DefaultCupertinoLocalizations.delegate,
        DefaultWidgetsLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ja', 'JP'),
      ],
      home: MainScreen(
        isDarkMode: _isDarkMode,
        onDarkModeChanged: _handleDarkModeChanged,
        onUpdateTasks: updateTaskList,
        tasks: _tasks,
      ),
    );
  }
}

class MainScreen extends StatelessWidget {
  final bool isDarkMode;
  final Function(bool) onDarkModeChanged;
  final Function() onUpdateTasks;
  final List<Task> tasks;

  const MainScreen({
    super.key,
    required this.isDarkMode,
    required this.onDarkModeChanged,
    required this.onUpdateTasks,
    required this.tasks,
  });

  @override
  Widget build(BuildContext context) {
    return CupertinoTabScaffold(
      backgroundColor: isDarkMode 
          ? CupertinoColors.black 
          : CupertinoColors.systemBackground, 
      tabBar: CupertinoTabBar(
        backgroundColor: isDarkMode 
            ? CupertinoColors.black 
            : CupertinoColors.systemBackground,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.list_bullet),
            label: 'タスク',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.calendar),
            label: 'カレンダー',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.person),
            label: 'プロフィール',
          ),
        ],
      ),
      tabBuilder: (context, index) {
        late final Widget child;
        switch (index) {
          case 0:
            child = TaskListScreen(
              isDarkMode: isDarkMode,
              onDarkModeChanged: onDarkModeChanged,
              onUpdateTasks: onUpdateTasks,
              tasks: tasks, // タスクのリストを渡す
            );
            break;
          case 1:
            child = CalendarScreen(
              isDarkMode: isDarkMode,
              onDarkModeChanged: onDarkModeChanged,
              onTasksUpdated: onUpdateTasks,
            );
            break;
          case 2:
            child = ProfileScreen(  // ProfileScreenを追加する必要があります
              isDarkMode: isDarkMode,
              onDarkModeChanged: onDarkModeChanged,
            );
            break;
          default:
            child = TaskListScreen(
              isDarkMode: isDarkMode,
              onDarkModeChanged: onDarkModeChanged,
              onUpdateTasks: onUpdateTasks,
              tasks: tasks, // タスクのリストを渡す
            );
        }

        return CupertinoPageScaffold(
          backgroundColor: isDarkMode 
              ? CupertinoColors.black 
              : CupertinoColors.systemBackground,
          child: child,
        );
      },
    );
  }
}

class TaskListScreen extends StatefulWidget {
  final bool isDarkMode;
  final Function(bool) onDarkModeChanged;
  final Function() onUpdateTasks;
  final List<Task> tasks;

  const TaskListScreen({
    super.key,
    required this.isDarkMode,
    required this.onDarkModeChanged,
    required this.onUpdateTasks,
    required this.tasks,
  });

  @override
  State<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> {
  late List<Task> _tasks;
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  DateTime? _selectedTime;
  Color? _selectedColor;
  bool _isEditMode = false;
  
  // predefinedCategories を追加
  final List<String> predefinedCategories = ['仕事', '個人', '買い物', '勉強', 'その他'];
  
  final _taskColors = [
    const Color(0xFF4CAF50),  // 緑
    const Color(0xFF2196F3),  // 青
    const Color(0xFFFFC107),  // 黄
    const Color(0xFFE91E63),  // ピンク
    const Color(0xFF9C27B0),  // 紫
    const Color(0xFFFF5722),  // オレンジ
  ];
  String selectedCategory = '未分類';

  @override
  void initState() {
    super.initState();
    _tasks = List.from(widget.tasks);
    _loadTasks();
    NotificationService().initialize();
    
    // データベースの変更を監視
    DatabaseHelper.instance.onTasksUpdated.listen((_) {
      _loadTasks();  // ローカルのタスクリストを更新
      widget.onUpdateTasks();  // 親ウィジェットの更新メソッドを呼び出す
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadTasks() async {
    final tasks = await DatabaseHelper.instance.getAllTasks();
    final user = Provider.of<User>(context, listen: false);
    
    // タスクの読み込み時に完了タスク数を更新
    int completedCount = tasks.where((task) => task.isCompleted).length;
    if (user.totalCompletedTasks != completedCount) {
      user.totalCompletedTasks = completedCount;
    }

    setState(() {
      _tasks = tasks;
      // 完了状態とdeadlineでソート
      _tasks.sort((a, b) {
        // まず完了状態でソート（未完了が上）
        if (a.isCompleted != b.isCompleted) {
          return a.isCompleted ? 1 : -1;
        }
        
        // 両方ともdeadlineがない場合は順序を維持
        if (a.deadline == null && b.deadline == null) return 0;
        // deadlineがない場合は後ろに
        if (a.deadline == null) return 1;
        if (b.deadline == null) return -1;
        
        // 時間を分単位に変換して比較
        final timeA = a.deadline!.hour * 60 + a.deadline!.minute;
        final timeB = b.deadline!.hour * 60 + b.deadline!.minute;
        return timeA.compareTo(timeB);
      });
    });
  }

  Future<void> _handleTaskCompletion(Task task, bool isCompleted) async {
    try {
      setState(() {
        task.isCompleted = isCompleted;
        if (isCompleted) {
          task.completedAt = DateTime.now();
        } else {
          task.completedAt = null;
        }
      });

      final user = Provider.of<User>(context, listen: false);
      
      // タスク完了時の処理
      if (isCompleted) {
        // すべてのタスクが完了したかチェック
        bool allTasksCompleted = _tasks.every((t) => t.isCompleted);
        
        if (allTasksCompleted) {
          // 一日のすべてのタスクを完了した場合
          user.completeAllDailyTasks(DateTime.now());
        }
      }

      // データベースを更新
      await DatabaseHelper.instance.update(task);
      DatabaseHelper.instance.notifyTasksUpdated();
      
      await _loadTasks();
      widget.onUpdateTasks();

    } catch (e) {
      print('Error handling task completion: $e');
      setState(() {
        task.isCompleted = !isCompleted;
        task.completedAt = isCompleted ? null : DateTime.now();
      });
    }
  }

  bool _isFirstTaskOfDay(DateTime completedAt) {
    return !_tasks.any((task) => 
      task.isCompleted && 
      task.completedAt != null &&
      _isSameDay(task.completedAt!, completedAt)
    );
  }

  bool _isLastTaskOfDay(Task task) {
    if (!task.isCompleted || task.completedAt == null) return false;
    return !_tasks.any((t) => 
      t != task &&
      t.isCompleted && 
      t.completedAt != null &&
      _isSameDay(t.completedAt!, task.completedAt!)
    );
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year && 
           date1.month == date2.month && 
           date1.day == date2.day;
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: widget.isDarkMode 
          ? CupertinoColors.black 
          : CupertinoColors.systemBackground,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: widget.isDarkMode 
            ? CupertinoColors.black 
            : CupertinoColors.systemBackground,
        middle: const Text('毎日のタスク'),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Icon(CupertinoIcons.settings),
          onPressed: () {
            Navigator.push(
              context,
              CupertinoPageRoute(
                builder: (context) => SettingsScreen(
                  isDarkMode: widget.isDarkMode,
                  onDarkModeChanged: widget.onDarkModeChanged,
                ),
              ),
            );
          },
        ),
        trailing: _isEditMode
            ? _buildEditModeActions()
            : CupertinoButton(
                padding: EdgeInsets.zero,
                child: Text(_isEditMode ? '完了' : '編集'),
                onPressed: () {
                  setState(() {
                    _isEditMode = !_isEditMode;
                  });
                },
              ),
      ),
      child: Material(  // Materialウィジェットを追加
        type: MaterialType.transparency,  // 背景を透明に
        child: SafeArea(
          child: ReorderableListView.builder(
            onReorder: (oldIndex, newIndex) {
              setState(() {
                if (oldIndex < newIndex) {
                  newIndex -= 1;
                }
                final Task item = _tasks.removeAt(oldIndex);
                _tasks.insert(newIndex, item);
                
                // 並び替え後の順序を更新
                for (int i = 0; i < _tasks.length; i++) {
                  _tasks[i] = _tasks[i].copyWith(order: i);
                  DatabaseHelper.instance.update(_tasks[i]);
                }
                DatabaseHelper.instance.notifyTasksUpdated();
              });
            },
            itemCount: _tasks.length,
            itemBuilder: (context, index) {
              final task = _tasks[index];
              return KeyedSubtree(
                key: Key('${task.id}'),
                child: _buildTaskItem(task),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildTaskItem(Task task) {
    return Dismissible(
      key: Key(task.id.toString()),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) async {
        bool? result = await showCupertinoDialog<bool>(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: const Text('タスクを削除'),
            content: const Text('このタスクを削除してもよろしいですか？'),
            actions: [
              CupertinoDialogAction(
                isDestructiveAction: true,
                onPressed: () => Navigator.pop(context, true),
                child: const Text('削除'),
              ),
              CupertinoDialogAction(
                isDefaultAction: true,
                onPressed: () => Navigator.pop(context, false),
                child: const Text('キャンセル'),
              ),
            ],
          ),
        );
        if (result == true) {
          await DatabaseHelper.instance.delete(task.id!);
          DatabaseHelper.instance.notifyTasksUpdated();
          return true;
        }
        return false;
      },
      background: Container(
        decoration: BoxDecoration(
          color: CupertinoColors.systemRed.withOpacity(0.9),
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: const Icon(CupertinoIcons.delete, color: CupertinoColors.white),
      ),
      child: DragTarget<Task>(
        onWillAccept: (incomingTask) => incomingTask != null && incomingTask != task,
        onAccept: (incomingTask) async {
          final oldIndex = _tasks.indexOf(incomingTask);
          final newIndex = _tasks.indexOf(task);
          
          if (oldIndex >= 0 && newIndex >= 0) {
            setState(() {
              _tasks.removeAt(oldIndex);
              _tasks.insert(newIndex, incomingTask);
            });
            
            // データベースの順序を更新
            try {
              for (int i = 0; i < _tasks.length; i++) {
                final currentTask = _tasks[i];
                currentTask.order = i;
                await DatabaseHelper.instance.update(currentTask);
              }
              
              // 触覚フィードバック
              HapticFeedback.mediumImpact();
              
              // データベースの変更を通知
              DatabaseHelper.instance.notifyTasksUpdated();
            } catch (e) {
              print('Error updating task order: $e');
            }
          }
        },
        builder: (context, candidateData, rejectedData) {
          return LongPressDraggable<Task>(
            data: task,
            feedback: Material(
              color: Colors.transparent,
              child: Container(
                width: MediaQuery.of(context).size.width - 32,
                child: _buildTaskItemContent(task, isDragging: true),
              ),
            ),
            childWhenDragging: Opacity(
              opacity: 0.5,
              child: _buildTaskItemContent(task),
            ),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: candidateData.isNotEmpty  // ドラッグ中のタスクがホバーしている時
                    ? [
                        BoxShadow(
                          color: widget.isDarkMode
                              ? const Color(0xFFFF2A6D).withOpacity(0.15)  // ダークモード: ピンク
                              : CupertinoColors.systemGrey.withOpacity(0.3),  // ライトモード: グレー
                          blurRadius: 12,
                          spreadRadius: 1,
                        ),
                      ]
                    : [],
              ),
              child: _buildTaskItemContent(task),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTaskItemContent(Task task, {bool isDragging = false}) {
    return GestureDetector(
      onTap: () async {
        if (!_isEditMode) {
          if (task.isCompleted) {
            await _handleTaskCompletion(task, false);
          } else {
            _showTaskDetails(task);
          }
        }
      },
      onDoubleTap: () async {
        if (!_isEditMode && !task.isCompleted) {
          await _handleTaskCompletion(task, true);
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 8,
        ),
        height: 100,
        decoration: BoxDecoration(
          color: task.isCompleted 
              ? (widget.isDarkMode
                  ? const Color(0xFFFF2A6D).withOpacity(0.2)  // ダークモード時は薄いピンク
                  : const Color(0xFFFF2A6D).withOpacity(0.1))
              : (widget.isDarkMode
                  ? const Color(0xFF1A1A1A)
                  : CupertinoColors.systemBackground),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: task.isCompleted
                ? (widget.isDarkMode
                    ? const Color(0xFFFF2A6D).withOpacity(0.4)  // ダークモード時は薄いピンクのボーダー
                    : const Color(0xFFFF2A6D).withOpacity(0.2))
                : (widget.isDarkMode
                    ? const Color(0xFF2D8C3C).withOpacity(0.3)
                    : CupertinoColors.systemGrey5),
            width: widget.isDarkMode ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: task.isCompleted 
                  ? (widget.isDarkMode
                      ? const Color(0xFFFF2A6D).withOpacity(0.3)  // ダークモード時は薄いピンクのシャドウ
                      : const Color(0xFFFF2A6D).withOpacity(0.1))
                  : (widget.isDarkMode
                      ? const Color(0xFF2D8C3C).withOpacity(0.15)
                      : CupertinoColors.systemGrey.withOpacity(0.2)),
              blurRadius: widget.isDarkMode ? 6 : 4,
              offset: widget.isDarkMode 
                  ? const Offset(0, 3)
                  : const Offset(0, 2),
              spreadRadius: widget.isDarkMode ? 0.5 : 0,
            ),
          ],
        ),
        child: Row(
          children: [
            if (_isEditMode) ...[
              CupertinoButton(
                padding: const EdgeInsets.only(left: 16),
                child: Icon(
                  task.isSelected
                      ? CupertinoIcons.checkmark_circle_fill
                      : CupertinoIcons.circle,
                  color: const Color(0xFFFF2A6D),
                  size: 24,
                ),
                onPressed: () {
                  setState(() {
                    task.isSelected = !task.isSelected;
                  });
                },
              ),
            ],
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Container(
                      width: 4,
                      height: 36,
                      decoration: BoxDecoration(
                        color: task.isCompleted ? CupertinoColors.systemGrey3 : task.taskColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            task.title,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              decoration: task.isCompleted ? TextDecoration.lineThrough : null,
                              color: task.isCompleted 
                                  ? CupertinoColors.systemGrey
                                  : (Theme.of(context).brightness == Brightness.light 
                                      ? Colors.black 
                                      : const Color(0xFFFF2A6D)),
                            ),
                          ),
                          if (!task.isCompleted) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Expanded(
                                  child: Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          'カテゴリー: ${task.category}',
                                          style: TextStyle(
                                            color: widget.isDarkMode
                                                ? const Color(0xFFFF2A6D).withOpacity(0.7)
                                                : CupertinoColors.systemGrey,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        '重要度: ${task.importance}',
                                        style: TextStyle(
                                          color: widget.isDarkMode
                                              ? const Color(0xFFFF2A6D).withOpacity(0.7)
                                              : CupertinoColors.systemGrey,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (task.deadline != null) ...[
              Padding(
                padding: const EdgeInsets.only(right: 16),  // 右側に余白を追加
                child: Text(
                  '${task.deadline!.hour.toString().padLeft(2, '0')}:${task.deadline!.minute.toString().padLeft(2, '0')}',
                  style: TextStyle(
                    fontSize: 15,
                    color: task.isCompleted 
                        ? CupertinoColors.systemGrey3 
                        : task.taskColor,  // タスクごとに設定された色を使用
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
            if (_isEditMode) ...[
              CupertinoButton(
                padding: const EdgeInsets.only(right: 16),
                child: Icon(
                  CupertinoIcons.pencil_circle_fill,
                  color: widget.isDarkMode 
                      ? CupertinoColors.systemGrey 
                      : CupertinoColors.systemGrey2,
                  size: 28,
                ),
                onPressed: () => _showEditTaskDialog(task),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEditModeActions() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        CupertinoButton(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: const Text('表示'),
          onPressed: () {
            _showSortOptionsDialog();
          },
        ),
        CupertinoButton(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: const Text(
            '削除',
            style: TextStyle(
              color: CupertinoColors.destructiveRed,
            ),
          ),
          onPressed: () {
            showCupertinoDialog(
              context: context,
              builder: (context) => CupertinoAlertDialog(
                title: const Text('選択したタスクを削除'),
                content: const Text('選択したタスクを削除しますか？'),
                actions: [
                  CupertinoDialogAction(
                    isDestructiveAction: true,
                    onPressed: () async {
                      Navigator.pop(context);
                      // 選択されたタスクを削除
                      for (var task in _tasks.where((t) => t.isSelected).toList()) {
                        await DatabaseHelper.instance.delete(task.id!);
                      }
                      setState(() {
                        _isEditMode = false;
                      });
                      _loadTasks();
                    },
                    child: const Text('削除'),
                  ),
                  CupertinoDialogAction(
                    child: const Text('キャンセル'),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            );
          },
        ),
        CupertinoButton(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: const Text('完了'),
          onPressed: () {
            setState(() {
              _isEditMode = false;
              // 選択状態をリセット
              for (var task in _tasks) {
                task.isSelected = false;
              }
            });
          },
        ),
      ],
    );
  }

  void _showSortOptionsDialog() {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('並び替え'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              _sortTasks('deadline_asc');
              Navigator.pop(context);
            },
            child: const Text('期限が早い順'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              _sortTasks('deadline_desc');
              Navigator.pop(context);
            },
            child: const Text('期限が遅い順'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              _sortTasks('importance');
              Navigator.pop(context);
            },
            child: const Text('重要度順'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('キャンセル'),
        ),
      ),
    );
  }

  void _sortTasks(String sortBy) {
    setState(() {
      switch (sortBy) {
        case 'deadline_asc':
          _tasks.sort((a, b) {
            if (a.deadline == null) return 1;
            if (b.deadline == null) return -1;
            return a.deadline!.compareTo(b.deadline!);
          });
          break;
        case 'deadline_desc':
          _tasks.sort((a, b) {
            if (a.deadline == null) return 1;
            if (b.deadline == null) return -1;
            return b.deadline!.compareTo(a.deadline!);
          });
          break;
        case 'importance':
          _tasks.sort((a, b) => b.importance.compareTo(a.importance));
          break;
      }
    });
  }

  Future<void> _showAddTaskDialog() async {
    // 初期時刻を12:00に設定
    DateTime tempSelectedTime = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
      12,  // 時を12に設定
      0,   // 分を0に設定
    );
    Color? tempSelectedColor = _selectedColor;
    _selectedTime = tempSelectedTime;  // 初期値を設定
    _selectedColor = null;
    _textController.clear();

    int selectedImportance = 1;  // デフォルト値

    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext dialogContext) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: widget.isDarkMode 
              ? CupertinoColors.black 
              : CupertinoColors.systemBackground,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [
            BoxShadow(
              color: CupertinoColors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Column(
              children: [
                Container(
                  width: 40,
                  height: 4,
                  // marginをCenterウィジェットで置き換える
                  child: Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: widget.isDarkMode 
                            ? CupertinoColors.systemGrey 
                            : CupertinoColors.systemGrey4,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  '新しいタスクを追加',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: widget.isDarkMode 
                        ? CupertinoColors.white 
                        : CupertinoColors.black,
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  decoration: BoxDecoration(
                    color: widget.isDarkMode 
                        ? CupertinoColors.darkBackgroundGray 
                        : CupertinoColors.systemGrey6,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: CupertinoTextField(
                    controller: _textController,
                    placeholder: 'タスクを入力してください',
                    padding: const EdgeInsets.all(12),
                    decoration: null,
                    style: TextStyle(
                      color: widget.isDarkMode 
                          ? CupertinoColors.white 
                          : CupertinoColors.black,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  height: 50,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: _taskColors.map((color) {
                      final isSelected = tempSelectedColor == color;
                      return GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setModalState(() => tempSelectedColor = color);
                        },
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: isSelected
                                ? Border.all(
                                    color: widget.isDarkMode 
                                        ? CupertinoColors.white 
                                        : CupertinoColors.black,
                                    width: 2,
                                  )
                                : null,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 24),
                GestureDetector(
                  onTap: () {
                    showCupertinoModalPopup(
                      context: context,
                      builder: (context) => Container(
                        height: 200,
                        color: widget.isDarkMode 
                            ? CupertinoColors.black 
                            : CupertinoColors.systemBackground,
                        child: Column(
                          children: [
                            Container(
                              height: 40,
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(
                                    color: widget.isDarkMode 
                                        ? CupertinoColors.darkBackgroundGray 
                                        : CupertinoColors.systemGrey5,
                                    width: 1,
                                  ),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  CupertinoButton(
                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                    child: const Text('キャンセル'),
                                    onPressed: () => Navigator.pop(context),
                                  ),
                                  CupertinoButton(
                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                    child: const Text('完了'),
                                    onPressed: () {
                                      Navigator.pop(context);
                                    },
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: CupertinoPicker(
                                itemExtent: 32,
                                onSelectedItemChanged: (index) {
                                  setModalState(() {
                                    selectedCategory = predefinedCategories[index];
                                  });
                                },
                                children: predefinedCategories
                                    .map((category) => Text(category))
                                    .toList(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: widget.isDarkMode 
                          ? CupertinoColors.darkBackgroundGray 
                          : CupertinoColors.systemGrey6,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          CupertinoIcons.tag,
                          color: widget.isDarkMode 
                              ? CupertinoColors.systemGrey2 
                              : CupertinoColors.systemGrey,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          selectedCategory,
                          style: TextStyle(
                            color: CupertinoColors.systemGrey,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 16),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: widget.isDarkMode 
                        ? CupertinoColors.darkBackgroundGray 
                        : CupertinoColors.systemGrey6,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('重要度'),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: List.generate(5, (index) {
                          final number = index + 1;
                          return GestureDetector(
                            onTap: () {
                              setModalState(() {
                                selectedImportance = number;
                              });
                            },
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: selectedImportance == number
                                    ? const Color(0xFFFF2A6D)
                                    : Colors.transparent,
                                border: Border.all(
                                  color: const Color(0xFFFF2A6D),
                                ),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Center(
                                child: Text(
                                  number.toString(),
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: selectedImportance == number
                                        ? CupertinoColors.white
                                        : const Color(0xFFFF2A6D),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                GestureDetector(
                  onTap: () {
                    showCupertinoModalPopup(
                      context: context,
                      builder: (context) => Container(
                        height: 216,
                        color: widget.isDarkMode 
                            ? CupertinoColors.black 
                            : CupertinoColors.systemBackground,
                        child: Column(
                          children: [
                            Container(
                              height: 44,
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(
                                    color: widget.isDarkMode 
                                        ? CupertinoColors.darkBackgroundGray 
                                        : CupertinoColors.systemGrey5,
                                    width: 1,
                                  ),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  CupertinoButton(
                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                    child: const Text('キャンセル'),
                                    onPressed: () => Navigator.pop(context),
                                  ),
                                  CupertinoButton(
                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                    child: const Text('完了'),
                                    onPressed: () {
                                      Navigator.pop(context);
                                    },
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: CupertinoDatePicker(
                                mode: CupertinoDatePickerMode.time,
                                initialDateTime: tempSelectedTime,
                                onDateTimeChanged: (time) {
                                  setModalState(() => tempSelectedTime = time);
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: widget.isDarkMode 
                          ? CupertinoColors.darkBackgroundGray 
                          : CupertinoColors.systemGrey6,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          CupertinoIcons.clock,
                          color: widget.isDarkMode 
                              ? CupertinoColors.systemGrey2 
                              : CupertinoColors.systemGrey,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          tempSelectedTime == null
                              ? '時刻の設定'
                              : '${tempSelectedTime!.hour.toString().padLeft(2, '0')}:${tempSelectedTime!.minute.toString().padLeft(2, '0')}',
                          style: TextStyle(
                            color: CupertinoColors.systemGrey,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                Row(
                  children: [
                    Expanded(
                      child: CupertinoButton(
                        padding: EdgeInsets.zero,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: widget.isDarkMode 
                                ? CupertinoColors.darkBackgroundGray 
                                : CupertinoColors.systemGrey6,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text(
                              'キャンセル',
                              style: TextStyle(
                                color: widget.isDarkMode 
                                    ? CupertinoColors.systemGrey2 
                                    : CupertinoColors.systemGrey,
                              ),
                            ),
                          ),
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: CupertinoButton(
                        padding: EdgeInsets.zero,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF2A6D),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Center(
                            child: Text(
                              '追加',
                              style: TextStyle(
                                color: CupertinoColors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        onPressed: () async {
                          if (_textController.text.isNotEmpty) {
                            final now = DateTime.now();
                            final deadline = tempSelectedTime != null
                                ? DateTime(
                                    now.year,
                                    now.month,
                                    now.day,
                                    tempSelectedTime!.hour,
                                    tempSelectedTime!.minute,
                                  )
                                : null;
                            
                            final task = Task(
                              title: _textController.text,
                              deadline: deadline,
                              priority: Priority.medium,
                              category: selectedCategory,
                              taskColor: tempSelectedColor ?? const Color(0xFFFFC107),
                              taskPriority: TaskPriority.medium,
                              importance: selectedImportance,
                            );
                            final savedTask = await DatabaseHelper.instance.create(task);
                            
                            if (deadline != null) {
                              await NotificationService().scheduleTaskNotification(
                                savedTask.id!,
                                savedTask.title,
                                deadline,
                              );
                            }
                            
                            _loadTasks();
                          }
                          Navigator.pop(context);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _showEditTaskDialog(Task task) async {
    _textController.text = task.title;
    DateTime? tempSelectedTime = task.deadline;
    Color? tempSelectedColor = task.taskColor;
    String tempCategory = task.category;
    int tempImportance = task.importance;

    await showCupertinoModalPopup(
      context: context,
      builder: (BuildContext dialogContext) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: widget.isDarkMode 
              ? CupertinoColors.black 
              : CupertinoColors.systemBackground,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [
            BoxShadow(
              color: CupertinoColors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Column(
          children: [
            // タイトル入力
            CupertinoTextField(
              controller: _textController,
              placeholder: 'タスクを入力',
            ),
            const SizedBox(height: 16),

            // カラー選択
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: _taskColors.map((color) {
                return GestureDetector(
                  onTap: () {
                    setState(() => tempSelectedColor = color);
                  },
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: tempSelectedColor == color
                          ? Border.all(color: CupertinoColors.white, width: 2)
                          : null,
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // 重要度選択
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(5, (index) {
                final number = index + 1;
                return GestureDetector(
                  onTap: () {
                    setState(() => tempImportance = number);
                  },
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: tempImportance == number
                          ? const Color(0xFFFF2A6D)
                          : Colors.transparent,
                      border: Border.all(
                        color: const Color(0xFFFF2A6D),
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Center(
                      child: Text(
                        number.toString(),
                        style: TextStyle(
                          color: tempImportance == number
                              ? CupertinoColors.white
                              : const Color(0xFFFF2A6D),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 16),

            // 保存ボタン
            CupertinoButton(
              color: const Color(0xFFFF2A6D),
              child: const Text('保存'),
              onPressed: () async {
                if (_textController.text.isNotEmpty) {
                  final updatedTask = task.copyWith(
                    title: _textController.text,
                    deadline: tempSelectedTime,
                    taskColor: tempSelectedColor,
                    category: tempCategory,
                    importance: tempImportance,
                  );
                  await DatabaseHelper.instance.update(updatedTask);
                  DatabaseHelper.instance.notifyTasksUpdated();
                  Navigator.pop(context);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showTaskDetails(Task task) {
    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) => Container(
        height: MediaQuery.of(context).size.height * 0.5,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: widget.isDarkMode 
              ? CupertinoColors.black 
              : CupertinoColors.systemBackground,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          border: Border.all(
            color: widget.isDarkMode
                ? const Color(0xFFFF2A6D)
                : CupertinoColors.systemGrey.withOpacity(0.3),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: widget.isDarkMode
                  ? const Color(0xFFFF2A6D).withOpacity(0.1)
                  : CupertinoColors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              task.title,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(
                  CupertinoIcons.tag,
                  color: widget.isDarkMode 
                      ? CupertinoColors.systemGrey2 
                      : CupertinoColors.systemGrey,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'カテゴリー: ${task.category}',
                  style: TextStyle(
                    color: widget.isDarkMode
                        ? const Color(0xFFFF2A6D).withOpacity(0.7)
                        : CupertinoColors.systemGrey,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  CupertinoIcons.star,
                  color: widget.isDarkMode 
                      ? CupertinoColors.systemGrey2 
                      : CupertinoColors.systemGrey,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  '重要度: ${task.importance}',
                  style: TextStyle(
                    color: widget.isDarkMode
                        ? const Color(0xFFFF2A6D).withOpacity(0.7)
                        : CupertinoColors.systemGrey,
                  ),
                ),
              ],
            ),
            const Spacer(),  // 下部にボタンを配置するためのスペーサー
            
            // 閉じるボタン
            CupertinoButton(
              padding: EdgeInsets.zero,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF2A6D),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Text(
                    '閉じる',
                    style: TextStyle(
                      color: CupertinoColors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }
}
