import 'package:flutter/foundation.dart';

class User extends ChangeNotifier {
  final int? id;
  String nickname;
  String? iconPath;
  int currentStreak;
  int bestStreak;
  int totalCompletedTasks;

  User({
    this.id,
    required this.nickname,
    this.iconPath,
    this.currentStreak = 0,
    this.bestStreak = 0,
    this.totalCompletedTasks = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nickname': nickname,
      'iconPath': iconPath,
      'currentStreak': currentStreak,
      'bestStreak': bestStreak,
      'totalCompletedTasks': totalCompletedTasks,
    };
  }

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'],
      nickname: map['nickname'],
      iconPath: map['iconPath'],
      currentStreak: map['currentStreak'],
      bestStreak: map['bestStreak'],
      totalCompletedTasks: map['totalCompletedTasks'],
    );
  }

  User copy({
    int? id,
    String? nickname,
    String? iconPath,
    int? currentStreak,
    int? bestStreak,
    int? totalCompletedTasks,
  }) {
    return User(
      id: id ?? this.id,
      nickname: nickname ?? this.nickname,
      iconPath: iconPath ?? this.iconPath,
      currentStreak: currentStreak ?? this.currentStreak,
      bestStreak: bestStreak ?? this.bestStreak,
      totalCompletedTasks: totalCompletedTasks ?? this.totalCompletedTasks,
    );
  }

  void completeTask(DateTime completedAt, DateTime? lastCompletedAt, bool isFirstTimeToday) {
    totalCompletedTasks++;

    // その日の最初のタスク完了かどうかを自動判定
    if (lastCompletedAt == null || !_isSameDay(lastCompletedAt, completedAt)) {
      if (lastCompletedAt == null || _isConsecutiveDay(lastCompletedAt, completedAt)) {
        currentStreak++;
        if (currentStreak > bestStreak) {
          bestStreak = currentStreak;
        }
      } else {
        currentStreak = 1;
      }
    }
    notifyListeners();
  }

  void uncompleteTask(bool wasLastTaskOfDay) {
    // タスク完了数を減らす
    totalCompletedTasks--;

    // その日の最後のタスクを取り消す場合、連続日数も減らす
    if (wasLastTaskOfDay) {
      currentStreak = currentStreak > 0 ? currentStreak - 1 : 0;
    }
    notifyListeners(); // 更新を通知
  }

  // 同じ日かどうかを判定
  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year && 
            date1.month == date2.month && 
            date1.day == date2.day;
  }

  // 連続した日かどうかを判定
  bool _isConsecutiveDay(DateTime prevDate, DateTime currentDate) {
    final difference = currentDate.difference(prevDate).inDays;
    return difference == 1;
  }
} 