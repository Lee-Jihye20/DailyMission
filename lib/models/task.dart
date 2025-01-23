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
  DateTime? completedAt;
  bool isSelected = false;

  Task({
    this.id,
    required this.title,
    this.deadline,
    required this.priority,
    required this.category,
    required this.taskColor,
    this.isCompleted = false,
    this.completedAt,
    this.isSelected = false,
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
      'completedAt': completedAt?.toIso8601String(),
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
      completedAt: map['completedAt'] != null ? DateTime.parse(map['completedAt']) : null,
      isSelected: map['isSelected'] == 1,
    );
  }
    Task copy({
    int? id,
    String? title,
    bool? isCompleted,
    DateTime? deadline,
    Priority? priority,
    String? category,
    Color? taskColor,
    DateTime? completedAt,
    bool? isSelected,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      isCompleted: isCompleted ?? this.isCompleted,
      deadline: deadline ?? this.deadline,
      priority: priority ?? this.priority,
      category: category ?? this.category,
      taskColor: taskColor ?? this.taskColor,
      completedAt: completedAt ?? this.completedAt,
      isSelected: isSelected ?? this.isSelected,
    );
  }
} 