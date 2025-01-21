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
import 'package:flutter/rendering.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Future.wait([
    initializeDateFormatting('ja_JP'),
    initializeDateFormatting('ja'),
  ]);
  tz.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('Asia/Tokyo'));
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoApp(
      title: '毎日のタスク',
      theme: const CupertinoThemeData(
        primaryColor: CupertinoColors.systemBlue,
        brightness: Brightness.light,
      ),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatelessWidget {
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoTabScaffold(
      tabBar: CupertinoTabBar(
        items: const [
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.list_bullet),
            label: 'タスク',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.calendar),
            label: 'カレンダー',
          ),
        ],
      ),
      tabBuilder: (context, index) {
        return CupertinoTabView(
          builder: (context) {
            switch (index) {
              case 0:
                return const TaskListScreen();
              case 1:
                return const CalendarScreen();
              default:
                return const TaskListScreen();
            }
          },
        );
      },
    );
  }
}

class TaskListScreen extends StatefulWidget {
  const TaskListScreen({super.key});

  @override
  State<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> {
  final List<Task> _tasks = [];
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  DateTime? _selectedDate;
  Priority _selectedPriority = Priority.medium;
  String _selectedCategory = '未分類';
  final _categories = ['未分類', '仕事', '個人', '買い物'];

  @override
  void initState() {
    super.initState();
    _loadTasks();
    NotificationService().init();
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadTasks() async {
    final tasks = await DatabaseHelper.instance.getAllTasks();
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

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('毎日のタスク'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Icon(CupertinoIcons.sort_down),
          onPressed: () {
            showCupertinoModalPopup(
              context: context,
              builder: (context) => CupertinoActionSheet(
                actions: [
                  CupertinoActionSheetAction(
                    onPressed: () {
                      setState(() {
                        _tasks.sort((a, b) => 
                          b.priority.index.compareTo(a.priority.index));
                      });
                      Navigator.pop(context);
                    },
                    child: const Text('優先度でソート'),
                  ),
                  CupertinoActionSheetAction(
                    onPressed: () {
                      setState(() {
                        _tasks.sort((a, b) {
                          if (a.deadline == null) return 1;
                          if (b.deadline == null) return -1;
                          return a.deadline!.compareTo(b.deadline!);
                        });
                      });
                      Navigator.pop(context);
                    },
                    child: const Text('期限でソート'),
                  ),
                ],
                cancelButton: CupertinoActionSheetAction(
                  onPressed: () => Navigator.pop(context),
                  isDestructiveAction: true,
                  child: const Text('キャンセル'),
                ),
              ),
            );
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
                    final isTarget = candidateData.isNotEmpty;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeInOut,
                      transform: Matrix4.identity()
                        ..translate(
                          0.0,
                          isTarget ? 4.0 : 0.0,
                        ),
                      child: AnimatedScale(
                        duration: const Duration(milliseconds: 200),
                        scale: isTarget ? 1.02 : 1.0,
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 200),
                          opacity: isTarget ? 0.7 : 1.0,
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
                              decoration: BoxDecoration(
                                color: CupertinoColors.systemGrey6.withOpacity(0.7),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: CupertinoColors.systemGrey4,
                                  width: 1,
                                  strokeAlign: BorderSide.strokeAlignCenter,
                                ),
                              ),
                              child: Opacity(
                                opacity: 0.5,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 16,
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 4,
                                        height: 32,
                                        decoration: BoxDecoration(
                                          color: task.isCompleted
                                              ? CupertinoColors.systemGrey3
                                              : task.priority.color,
                                          borderRadius: BorderRadius.circular(2),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      if (task.isCompleted)
                                        const Padding(
                                          padding: EdgeInsets.only(right: 12),
                                          child: Text(
                                            '完了',
                                            style: TextStyle(
                                              fontSize: 15,
                                              color: CupertinoColors.systemGrey,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              task.title,
                                              style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.w600,
                                                color: CupertinoColors.systemGrey,
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              'カテゴリー: ${task.category}',
                                              style: const TextStyle(
                                                fontSize: 14,
                                                color: CupertinoColors.systemGrey,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
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
                        ),
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
                color: CupertinoColors.activeBlue,
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

  Widget _buildTaskItem(Task task, {
    bool isDragging = false,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      margin: EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: task.isCompleted 
            ? CupertinoColors.systemGrey6 
            : CupertinoColors.systemBackground,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: CupertinoColors.systemGrey.withOpacity(
              isDragging ? 0.2 : (task.isCompleted ? 0.05 : 0.1)
            ),
            blurRadius: isDragging ? 20 : 10,
            offset: Offset(0, isDragging ? 8 : 4),
            spreadRadius: isDragging ? 2 : 0,
          ),
        ],
      ),
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: () async {
          task.isCompleted = !task.isCompleted;
          await DatabaseHelper.instance.update(task);
          _loadTasks();
          HapticFeedback.selectionClick();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 32,
                decoration: BoxDecoration(
                  color: task.isCompleted
                      ? CupertinoColors.systemGrey3
                      : task.priority.color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 16),
              if (task.isCompleted)
                const Padding(
                  padding: EdgeInsets.only(right: 12),
                  child: Text(
                    '完了',
                    style: TextStyle(
                      fontSize: 15,
                      color: Color.fromARGB(255, 255, 0, 0),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        decoration: task.isCompleted
                            ? TextDecoration.lineThrough
                            : null,
                        color: task.isCompleted
                            ? CupertinoColors.systemGrey
                            : CupertinoColors.label,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'カテゴリー: ${task.category}',
                      style: TextStyle(
                        fontSize: 14,
                        color: task.isCompleted
                            ? CupertinoColors.systemGrey3
                            : CupertinoColors.systemGrey,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showAddTaskDialog() async {
    _selectedDate = null;
    _selectedPriority = Priority.medium;
    _selectedCategory = '未分類';
    _textController.clear();

    showCupertinoModalPopup(
      context: context,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: CupertinoColors.systemBackground,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            const Text(
              '新しいタスクを追加',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            CupertinoTextField(
              controller: _textController,
              placeholder: 'タスクを入力してください',
              padding: const EdgeInsets.all(12),
            ),
            const SizedBox(height: 16),
            CupertinoSlidingSegmentedControl<Priority>(
              groupValue: _selectedPriority,
              children: {
                Priority.low: const Text('低'),
                Priority.medium: const Text('中'),
                Priority.high: const Text('高'),
              },
              onValueChanged: (value) {
                setState(() => _selectedPriority = value!);
              },
            ),
            const SizedBox(height: 16),
            CupertinoButton(
              child: Text(
                _selectedCategory,
                style: const TextStyle(color: CupertinoColors.activeBlue),
              ),
              onPressed: () {
                showCupertinoModalPopup(
                  context: context,
                  builder: (context) => CupertinoActionSheet(
                    actions: _categories
                        .map(
                          (category) => CupertinoActionSheetAction(
                            onPressed: () {
                              setState(() => _selectedCategory = category);
                              Navigator.pop(context);
                            },
                            child: Text(category),
                          ),
                        )
                        .toList(),
                    cancelButton: CupertinoActionSheetAction(
                      onPressed: () => Navigator.pop(context),
                      isDestructiveAction: true,
                      child: const Text('キャンセル'),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            CupertinoButton(
              child: Text(
                _selectedDate == null
                    ? '期限を設定'
                    : '期限: ${_selectedDate.toString().split(' ')[0]}',
                style: const TextStyle(color: CupertinoColors.activeBlue),
              ),
              onPressed: () {
                showCupertinoModalPopup(
                  context: context,
                  builder: (context) => Container(
                    height: 216,
                    color: CupertinoColors.systemBackground,
                    child: CupertinoDatePicker(
                      mode: CupertinoDatePickerMode.date,
                      initialDateTime: DateTime.now(),
                      minimumDate: DateTime.now(),
                      maximumDate: DateTime.now().add(const Duration(days: 365)),
                      onDateTimeChanged: (date) {
                        setState(() => _selectedDate = date);
                      },
                    ),
                  ),
                );
              },
            ),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                CupertinoButton(
                  child: const Text('キャンセル'),
                  onPressed: () => Navigator.pop(context),
                ),
                CupertinoButton.filled(
                  child: const Text('追加'),
                  onPressed: () async {
                    if (_textController.text.isNotEmpty) {
                      final task = Task(
                        title: _textController.text,
                        deadline: _selectedDate,
                        priority: _selectedPriority,
                        category: _selectedCategory,
                      );
                      final savedTask = await DatabaseHelper.instance.create(task);
                      
                      if (_selectedDate != null) {
                        await NotificationService().scheduleTaskNotification(
                          savedTask.id!,
                          savedTask.title,
                          _selectedDate!,
                        );
                      }
                      
                      _loadTasks();
                    }
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
