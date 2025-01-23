import 'package:flutter/cupertino.dart';
import 'package:table_calendar/table_calendar.dart';
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

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _focusedDay = DateTime(now.year, now.month, now.day);
    _selectedDay = _focusedDay;
    _loadTasks();
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
        trailing: CupertinoButton(
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
                        return CupertinoButton(
                          padding: EdgeInsets.zero,
                          onPressed: () async {
                            task.isCompleted = !task.isCompleted;
                            await DatabaseHelper.instance.update(task);
                            _loadTasks();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 3,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: task.isCompleted
                                        ? CupertinoColors.systemGrey3
                                        : task.priority.color,
                                    borderRadius: BorderRadius.circular(1.5),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                if (task.isCompleted)
                                  const Padding(
                                    padding: EdgeInsets.only(right: 8),
                                    child: Text(
                                      '完了',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: CupertinoColors.systemGrey,
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
                                          fontSize: 16,
                                          decoration: task.isCompleted
                                              ? TextDecoration.lineThrough
                                              : null,
                                          color: task.isCompleted
                                              ? CupertinoColors.systemGrey
                                              : CupertinoColors.label,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'カテゴリー: ${task.category}',
                                        style: TextStyle(
                                          fontSize: 13,
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
                        );
                      },
                    ),
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
    // ここでタスクを取得するロジックを追加
    final tasks = []; // 例: タスクのリストを取得

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
        // タスク削除の確認ダイアログを表示
        return true; // 確認後に削除処理を行う
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