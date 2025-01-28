import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:table_calendar/table_calendar.dart';
import '../services/notification_service.dart';
import '../models/task.dart';
import '../services/database_helper.dart';
import '../screens/settings_screen.dart';

class CalendarScreen extends StatefulWidget {
  final bool isDarkMode;
  final Function(bool) onDarkModeChanged;

  const CalendarScreen({
    super.key,
    required this.isDarkMode,
    required this.onDarkModeChanged,
  });

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late DateTime _focusedDay;
  DateTime? _selectedDay;
  List<Task> _tasks = [];
  Map<DateTime, List<Task>> _tasksByDay = {};
  CalendarFormat _calendarFormat = CalendarFormat.month;

  DateTime? _selectedTime;
  Color? _selectedColor;
  TextEditingController _textController = TextEditingController();
  final List<Color> _taskColors = [
    CupertinoColors.systemRed,
    CupertinoColors.systemGreen,
    CupertinoColors.systemBlue,
    CupertinoColors.systemYellow,
  ];

  String selectedCategory = '未分類';

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _focusedDay = DateTime(now.year, now.month, now.day);
    _selectedDay = _focusedDay;
    _loadTasks();
    DatabaseHelper.instance.onTasksUpdated.listen((_) {
      _loadTasks();
    });
  }



  Future<void> _showAddTaskDialog() async {
    DateTime? tempSelectedTime = _selectedTime;
    Color? tempSelectedColor = _selectedColor;
    _selectedTime = null;
    _selectedColor = null;
    _textController.clear();

    final List<String> predefinedCategories = ['仕事', '個人', '買い物', '勉強', 'その他'];

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
                                initialDateTime: tempSelectedTime ?? _selectedDay,
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
                            final deadline = tempSelectedTime != null
                                ? DateTime(
                                    _selectedDay!.year,
                                    _selectedDay!.month,
                                    _selectedDay!.day,
                                    tempSelectedTime!.hour,
                                    tempSelectedTime!.minute,
                                  )
                                : null;
                            
                            final task = Task(
                              title: _textController.text,
                              deadline: deadline,
                              priority: Priority.medium,
                              category: selectedCategory,
                              taskColor: const Color(0xFFFFC107),
                              taskPriority: TaskPriority.medium,
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

  Future<void> _loadTasks() async {
    _tasks = await DatabaseHelper.instance.getAllTasks();
    _tasksByDay = {};
    
    for (var task in _tasks) {
      if (task.deadline != null) {
        final date = DateTime(
          task.deadline!.year,
          task.deadline!.month,
          task.deadline!.day,
        );
        
        if (_tasksByDay[date] == null) {
          _tasksByDay[date] = [];
        }
        _tasksByDay[date]!.add(task);
      }
    }
    
    setState(() {});
  }

  List<Task> _getTasksForDay(DateTime day) {
    final date = DateTime(day.year, day.month, day.day);
    return _tasksByDay[date] ?? [];
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final firstDay = DateTime(now.year, now.month - 6, 1);
    final lastDay = DateTime(now.year, now.month + 6, 1);

    return CupertinoPageScaffold(
      backgroundColor: widget.isDarkMode 
          ? CupertinoColors.black 
          : CupertinoColors.systemBackground,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: widget.isDarkMode 
            ? CupertinoColors.black 
            : CupertinoColors.systemBackground,
        middle: const Text('カレンダー'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CupertinoButton(
              padding: EdgeInsets.zero,
              child: const Icon(CupertinoIcons.add),
              onPressed: () async {
                print(_selectedDay);
                await _showAddTaskDialog();
                await _loadTasks();
              },
            ),
            CupertinoButton(
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
          ],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: TableCalendar<Task>(
                firstDay: firstDay,
                lastDay: lastDay,
                focusedDay: _focusedDay,
                currentDay: now,
                calendarFormat: _calendarFormat,
                selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                eventLoader: _getTasksForDay,
                startingDayOfWeek: StartingDayOfWeek.monday,
                locale: 'ja',
                daysOfWeekHeight: 20,
                rowHeight: 43,
                headerStyle: const HeaderStyle(
                  formatButtonVisible: true,
                  titleCentered: true,
                  titleTextStyle: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                  formatButtonShowsNext: false,
                  headerPadding: EdgeInsets.symmetric(vertical: 8),
                  leftChevronIcon: Icon(CupertinoIcons.left_chevron, size: 20),
                  rightChevronIcon: Icon(CupertinoIcons.right_chevron, size: 20),
                  formatButtonTextStyle: TextStyle(
                    fontSize: 14,
                    color: const Color(0xFFFF2A6D),
                  ),
                  formatButtonDecoration: BoxDecoration(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                  ),
                  headerMargin: EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 32,
                  ),
                ),
                daysOfWeekStyle: const DaysOfWeekStyle(
                  weekdayStyle: TextStyle(color: CupertinoColors.systemGrey),
                  weekendStyle: TextStyle(color: CupertinoColors.systemRed),
                ),
                calendarStyle: CalendarStyle(
                  isTodayHighlighted: true,
                  markersMaxCount: 4,
                  markerSize: 7,
                  markerDecoration: const BoxDecoration(
                    color: const Color(0xFFFF2A6D),
                    shape: BoxShape.circle,
                  ),
                  todayDecoration: BoxDecoration(
                    color: const Color(0xFFFF2A6D).withOpacity(0.3),
                    shape: BoxShape.circle,
                  ),
                  selectedDecoration: const BoxDecoration(
                    color: const Color(0xFFFF2A6D),
                    shape: BoxShape.circle,
                  ),
                  weekendTextStyle: const TextStyle(color: CupertinoColors.systemRed),
                  outsideTextStyle: const TextStyle(color: CupertinoColors.systemGrey3),
                  defaultTextStyle: const TextStyle(fontSize: 14),
                ),
                onDaySelected: (selectedDay, focusedDay) {
                  if (!isSameDay(_selectedDay, selectedDay)) {
                    setState(() {
                      _selectedDay = selectedDay;
                      _focusedDay = focusedDay;
                    });
                  }
                },
                onFormatChanged: (format) {
                  if (_calendarFormat != format) {
                    setState(() {
                      _calendarFormat = format;
                    });
                  }
                },
                onPageChanged: (focusedDay) {
                  _focusedDay = focusedDay;
                },
                availableCalendarFormats: const {
                  CalendarFormat.month: '月',
                  CalendarFormat.week: '週',
                },
              ),
            ),
            Container(
              height: 1,
              color: CupertinoColors.separator,
            ),
            Expanded(
              child: _selectedDay == null
                  ? const Center(child: Text('日付を選択してください'))
                  : ListView.separated(
                      padding: const EdgeInsets.only(bottom: 16),
                      itemCount: _getTasksForDay(_selectedDay!).length,
                      separatorBuilder: (context, index) => Container(
                        height: 1,
                        color: CupertinoColors.separator,
                      ),
                      itemBuilder: (context, index) {
                        final task = _getTasksForDay(_selectedDay!)[index];
                        return _buildTaskItem(task);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskItem(Task task) {
    return Dismissible(
      key: Key(task.id.toString()),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) async {
        return true;
      },
      background: Container(
        color: CupertinoColors.systemRed,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(CupertinoIcons.delete, color: CupertinoColors.white),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        decoration: BoxDecoration(
          color: CupertinoColors.systemBackground,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: CupertinoColors.systemGrey.withOpacity(0.2),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
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
                    children: [
                      Text(
                        task.title,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          decoration: task.isCompleted ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      if (task.deadline != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          '期限: ${task.deadline}',
                          style: TextStyle(color: CupertinoColors.systemGrey),
                        ),
                      ],
                      const SizedBox(height: 4),
                      Text(
                        'カテゴリー: ${task.category}',
                        style: TextStyle(color: CupertinoColors.systemGrey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class TaskList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final tasks = [];

    return ListView.builder(
      itemCount: tasks.length,
      itemBuilder: (context, index) {
        final task = tasks[index];
        return _buildTaskItem(task);
      },
    );
  }

  Widget _buildTaskItem(Task task) {
    return Dismissible(
      key: Key(task.id.toString()),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) async {
        return true;
      },
      background: Container(
        color: CupertinoColors.systemRed,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(CupertinoIcons.delete, color: CupertinoColors.white),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        decoration: BoxDecoration(
          color: CupertinoColors.systemBackground,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: CupertinoColors.systemGrey.withOpacity(0.2),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
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
                children: [
                  Text(
                    task.title,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      decoration: task.isCompleted ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  if (task.deadline != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      '期限: ${task.deadline}',
                      style: TextStyle(color: CupertinoColors.systemGrey),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
} 