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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
        // その他の初期値
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

  @override
  void initState() {
    super.initState();
    _loadSettings();
    NotificationService().initialize();
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
      home: MainScreen(isDarkMode: _isDarkMode, onDarkModeChanged: _handleDarkModeChanged),
    );
  }
}

class MainScreen extends StatelessWidget {
  final bool isDarkMode;
  final Function(bool) onDarkModeChanged;

  const MainScreen({
    super.key,
    required this.isDarkMode,
    required this.onDarkModeChanged,
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
            );
            break;
          case 1:
            child = CalendarScreen(
              isDarkMode: isDarkMode,
              onDarkModeChanged: onDarkModeChanged,
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

  const TaskListScreen({
    super.key,
    required this.isDarkMode,
    required this.onDarkModeChanged,
  });

  @override
  State<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> {
  final List<Task> _tasks = [];
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  DateTime? _selectedTime;
  Color? _selectedColor;
  bool _isEditMode = false;  // 編集モードの状態を追加
  final _taskColors = [
    const Color(0xFF4CAF50),  // 緑
    const Color(0xFF2196F3),  // 青
    const Color(0xFFFFC107),  // 黄
    const Color(0xFFE91E63),  // ピンク
    const Color(0xFF9C27B0),  // 紫
    const Color(0xFFFF5722),  // オレンジ
  ];

  @override
  void initState() {
    super.initState();
    _loadTasks();
    NotificationService().initialize();
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
      _tasks.clear();
      _tasks.addAll(tasks);
      // 完了状態でソート（未完了が上、完了が下）
      _tasks.sort((a, b) {
        if (a.isCompleted == b.isCompleted) {
          // 同じ完了状態の場合は、期限日でソート
          if (a.deadline == null && b.deadline == null) return 0;
          if (a.deadline == null) return 1;
          if (b.deadline == null) return -1;
          return a.deadline!.compareTo(b.deadline!);
        }
        // 完了タスクを下に
        return a.isCompleted ? 1 : -1;
      });
    });
  }

  Future<void> _handleTaskCompletion(Task task, bool isCompleted) async {
    final user = Provider.of<User>(context, listen: false);
    final lastCompletedTask = _tasks
        .where((t) => t.isCompleted && t.completedAt != null)
        .reduce((a, b) => a.completedAt!.isAfter(b.completedAt!) ? a : b);

    if (isCompleted) {
      task.isCompleted = true;
      task.completedAt = DateTime.now();
      user.completeTask(
        task.completedAt!,
        lastCompletedTask?.completedAt,
        _isFirstTaskOfDay(task.completedAt!),
      );
    } else {
      bool wasLastTaskOfDay = _isLastTaskOfDay(task);
      task.isCompleted = false;
      task.completedAt = null;
      user.uncompleteTask(wasLastTaskOfDay);
    }

    await DatabaseHelper.instance.update(task);
    _loadTasks();
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
      child: SafeArea(
        child: Stack(
          children: [
            ListView.builder(
              controller: _scrollController,
              itemCount: _tasks.length,
              itemBuilder: (context, index) {
                final task = _tasks[index];
                return DragTarget<Task>(
                  onWillAccept: (incomingTask) {
                    if (incomingTask != task) {
                      final oldIndex = _tasks.indexOf(incomingTask!);
                      final newIndex = _tasks.indexOf(task);
                      
                      // アニメーション付きでタスクを入れ替え
                      setState(() {
                        if (oldIndex < newIndex) {
                          for (int i = oldIndex; i < newIndex; i++) {
                            final temp = _tasks[i];
                            _tasks[i] = _tasks[i + 1];
                            _tasks[i + 1] = temp;
                          }
                        } else {
                          for (int i = oldIndex; i > newIndex; i--) {
                            final temp = _tasks[i];
                            _tasks[i] = _tasks[i - 1];
                            _tasks[i - 1] = temp;
                          }
                        }
                      });
                      
                      HapticFeedback.selectionClick();
                      return true;
                    }
                    return false;
                  },
                  onAccept: (incomingTask) {
                    HapticFeedback.mediumImpact();
                  },
                  builder: (context, candidateData, rejectedData) {
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      child: LongPressDraggable<Task>(
                        data: task,
                        axis: Axis.vertical,
                        maxSimultaneousDrags: 1,
                        feedback: Material(
                          color: Colors.transparent,
                          child: Opacity(
                            opacity: 0.9,
                            child: Transform.scale(
                              scale: 1.05,
                              child: SizedBox(
                                width: MediaQuery.of(context).size.width,
                                child: _buildTaskItem(
                                  task,
                                  isDragging: true,
                                ),
                              ),
                            ),
                          ),
                        ),
                        childWhenDragging: Container(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          height: 100,
                          decoration: BoxDecoration(
                            color: CupertinoColors.systemBackground.withOpacity(0.7),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: CupertinoColors.systemGrey5.withOpacity(0.5),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: task.taskColor.withOpacity(0.05),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 4,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: (task.isCompleted
                                        ? CupertinoColors.systemGrey3
                                        : task.taskColor).withOpacity(0.5),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              task.title,
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                fontSize: 20,
                                                fontWeight: FontWeight.w600,
                                                decoration: task.isCompleted
                                                    ? TextDecoration.lineThrough
                                                    : null,
                                                color: (task.isCompleted
                                                    ? CupertinoColors.systemGrey
                                                    : CupertinoColors.label).withOpacity(0.5),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (task.deadline != null) ...[
                                        const SizedBox(width: 8),
                                        Text(
                                          '${task.deadline!.hour.toString().padLeft(2, '0')}:${task.deadline!.minute.toString().padLeft(2, '0')}',
                                          style: TextStyle(
                                            fontSize: 15,
                                            color: (task.isCompleted
                                                ? CupertinoColors.systemGrey3
                                                : task.taskColor).withOpacity(0.5),
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        onDragStarted: () {
                          HapticFeedback.heavyImpact();
                        },
                        onDragEnd: (details) {
                          HapticFeedback.mediumImpact();
                        },
                        child: _buildTaskItem(task),
                      ),
                    );
                  },
                );
              },
            ),
            Positioned(
              right: 16,
              bottom: 24,
              child: CupertinoButton(
                color: const Color(0xFFFF2A6D),
                padding: const EdgeInsets.all(20),
                borderRadius: BorderRadius.circular(35),
                onPressed: _showAddTaskDialog,
                child: const Icon(
                  CupertinoIcons.add,
                  color: CupertinoColors.white,
                  size: 30,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskItem(Task task, {bool isDragging = false}) {
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
                onPressed: () {
                  Navigator.pop(context, true);
                },
                child: const Text('削除'),
              ),
              CupertinoDialogAction(
                isDefaultAction: true,
                onPressed: () {
                  Navigator.pop(context, false);
                },
                child: const Text('キャンセル'),
              ),
            ],
          ),
        );
        if (result == true) {
          await DatabaseHelper.instance.delete(task.id!);
          _loadTasks();
          return true;
        }
        return false;
      },
      background: Container(
        decoration: BoxDecoration(
          color: CupertinoColors.systemRed.withOpacity(0.9),
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 8,
        ),
        height: 100,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: const Icon(
          CupertinoIcons.delete,
          color: CupertinoColors.white,
          size: 24,
        ),
      ),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        margin: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 8,
        ),
        height: 100,
        decoration: BoxDecoration(
          color: task.isCompleted 
              ? CupertinoColors.systemRed.withOpacity(0.1)
              : CupertinoColors.systemBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: task.isCompleted
                ? CupertinoColors.systemRed.withOpacity(0.2)
                : CupertinoColors.systemGrey5,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: task.taskColor.withAlpha(isDragging ? 38 : (task.isCompleted ? 13 : 25)),
              blurRadius: isDragging ? 16 : 8,
              offset: Offset(0, isDragging ? 6 : 2),
              spreadRadius: isDragging ? 1 : 0,
            ),
          ],
        ),
        child: Row(
          children: [
            if (_isEditMode) ...[  // 編集モード時に選択チェックボックスを表示
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
              child: CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () async {
                  if (!_isEditMode) {
                    await _handleTaskCompletion(task, !task.isCompleted);
                  } else {
                    setState(() {
                      task.isSelected = !task.isSelected;
                    });
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 4,
                        height: 36,
                        decoration: BoxDecoration(
                          color: task.isCompleted
                              ? CupertinoColors.systemGrey3
                              : task.taskColor,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    task.title,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w600,
                                      decoration: task.isCompleted
                                          ? TextDecoration.lineThrough
                                          : null,
                                      color: task.isCompleted
                                          ? CupertinoColors.systemGrey
                                          : CupertinoColors.label,
                                    ),
                                  ),
                                  if (task.isCompleted) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      '完了',
                                      style: TextStyle(
                                        color: CupertinoColors.systemRed.withOpacity(0.5),
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            if (task.deadline != null) ...[
                              const SizedBox(width: 8),
                              Text(
                                '${task.deadline!.hour.toString().padLeft(2, '0')}:${task.deadline!.minute.toString().padLeft(2, '0')}',
                                style: TextStyle(
                                  fontSize: 15,
                                  color: task.isCompleted
                                      ? CupertinoColors.systemGrey3
                                      : task.taskColor,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
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

  Future<void> _showAddTaskDialog() async {
    DateTime? tempSelectedTime = _selectedTime;  // 一時的な時刻変数を追加
    Color? tempSelectedColor = _selectedColor;   // 一時的な色変数を追加
    _selectedTime = null;
    _selectedColor = null;
    _textController.clear();

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
                  decoration: BoxDecoration(
                    color: widget.isDarkMode 
                        ? CupertinoColors.systemGrey 
                        : CupertinoColors.systemGrey4,
                    borderRadius: BorderRadius.circular(2),
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
                                      setModalState(() {});  // 親のStatefulBuilderの状態を更新
                                      Navigator.pop(context);
                                    },
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: CupertinoDatePicker(
                                mode: CupertinoDatePickerMode.time,
                                initialDateTime: tempSelectedTime ?? DateTime.now(),
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
                              ? '時刻を設定'
                              : '${tempSelectedTime!.hour.toString().padLeft(2, '0')}:${tempSelectedTime!.minute.toString().padLeft(2, '0')}',
                          style: TextStyle(
                            color: tempSelectedTime == null
                                ? (widget.isDarkMode 
                                    ? CupertinoColors.systemGrey2 
                                    : CupertinoColors.systemGrey)
                                : (widget.isDarkMode 
                                    ? CupertinoColors.white 
                                    : CupertinoColors.label),
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
                              category: '未分類',
                              taskColor: tempSelectedColor ?? CupertinoColors.white,
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
                  decoration: BoxDecoration(
                    color: widget.isDarkMode 
                        ? CupertinoColors.systemGrey 
                        : CupertinoColors.systemGrey4,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'タスクを編集',
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
                                      setModalState(() {});
                                      Navigator.pop(context);
                                    },
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: CupertinoDatePicker(
                                mode: CupertinoDatePickerMode.time,
                                initialDateTime: tempSelectedTime ?? DateTime.now(),
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
                              ? '時刻を設定'
                              : '${tempSelectedTime!.hour.toString().padLeft(2, '0')}:${tempSelectedTime!.minute.toString().padLeft(2, '0')}',
                          style: TextStyle(
                            color: tempSelectedTime == null
                                ? (widget.isDarkMode 
                                    ? CupertinoColors.systemGrey2 
                                    : CupertinoColors.systemGrey)
                                : (widget.isDarkMode 
                                    ? CupertinoColors.white 
                                    : CupertinoColors.label),
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
                              '保存',
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
                            
                            task.title = _textController.text;
                            task.deadline = deadline;
                            task.taskColor = tempSelectedColor ?? task.taskColor;
                            
                            await DatabaseHelper.instance.update(task);
                            
                            if (deadline != null) {
                              await NotificationService().scheduleTaskNotification(
                                task.id!,
                                task.title,
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
}
