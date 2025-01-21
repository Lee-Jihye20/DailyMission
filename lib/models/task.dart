import 'package:flutter/cupertino.dart';

enum Priority {
  low,
  medium,
  high;

  Color get color {
    switch (this) {
      case Priority.low:
        return const Color(0xFF4CAF50); // 緑
      case Priority.medium:
        return const Color(0xFFFFC107); // 黄
      case Priority.high:
        return const Color(0xFFF44336); // 赤
    }
  }
}

class Task {
  final int? id;
  final String title;
  final DateTime? deadline;
  final Priority priority;
  final String category;
  bool isCompleted;

  Task({
    this.id,
    required this.title,
    this.deadline,
    this.priority = Priority.medium,
    this.category = '未分類',
    this.isCompleted = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'deadline': deadline?.toIso8601String(),
      'priority': priority.index,
      'category': category,
      'isCompleted': isCompleted ? 1 : 0,
    };
  }

  factory Task.fromMap(Map<String, dynamic> map) {
    return Task(
      id: map['id'],
      title: map['title'],
      deadline: map['deadline'] != null ? DateTime.parse(map['deadline']) : null,
      priority: Priority.values[map['priority']],
      category: map['category'],
      isCompleted: map['isCompleted'] == 1,
    );
  }
} 