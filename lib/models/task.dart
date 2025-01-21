import 'package:flutter/cupertino.dart';

enum Priority {
  medium;

  Color get color {
    return const Color(0xFFFFC107); // 黄
  }
}

class Task {
  final int? id;
  String title;
  DateTime? deadline;
  final Priority priority;
  final String category;
  Color taskColor;
  bool isCompleted;

  Task({
    this.id,
    required this.title,
    this.deadline,
    required this.priority,
    required this.category,
    required this.taskColor,
    this.isCompleted = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'deadline': deadline?.toIso8601String(),
      'priority': priority.index,
      'category': category,
      'taskColor': taskColor.value,
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
      taskColor: Color(map['taskColor']),
      isCompleted: map['isCompleted'] == 1,
    );
  }
} 