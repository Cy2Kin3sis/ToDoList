import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

class TodoItem {
  String text;
  DateTime createdAt;
  DateTime? deadline;
  bool isCompleted;
  DateTime? completedAt;

  TodoItem({
    required this.text,
    required this.createdAt,
    this.deadline,
    this.isCompleted = false,
    this.completedAt,
  });

  Map<String, dynamic> toJson() => {
    'text': text,
    'createdAt': createdAt.toIso8601String(),
    'deadline': deadline?.toIso8601String(),
    'isCompleted': isCompleted,
    'completedAt': completedAt?.toIso8601String(),
  };

  factory TodoItem.fromJson(Map<String, dynamic> json) => TodoItem(
    text: json['text'],
    createdAt: DateTime.parse(json['createdAt']),
    deadline: json['deadline'] != null ? DateTime.parse(json['deadline']) : null,
    isCompleted: json['isCompleted'] ?? false,
    completedAt: json['completedAt'] != null ? DateTime.parse(json['completedAt']) : null,
  );

  Duration? get timeRemaining {
    if (deadline == null || isCompleted) return null;
    final now = DateTime.now();
    final remaining = deadline!.difference(now);
    return remaining.isNegative ? null : remaining;
  }

  bool get isOverdue {
    if (deadline == null || isCompleted) return false;
    return DateTime.now().isAfter(deadline!);
  }

  bool get shouldAutoDelete {
    if (!isCompleted || completedAt == null) return false;
    final now = DateTime.now();
    return now.difference(completedAt!).inHours >= 24;
  }
}

class TodoHome extends StatefulWidget {
  final ThemeMode themeMode;
  final Function(bool) onThemeChanged;
  const TodoHome({super.key, required this.themeMode, required this.onThemeChanged});
  @override
  TodoHomeState createState() => TodoHomeState();
}
class TodoHomeState extends State<TodoHome> {
  final List<TodoItem> _todos = [];
  final TextEditingController _controller = TextEditingController();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _loadTodos();
    // Update UI every second for countdown timers
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _autoDeleteCompleted();
      setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadTodos() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList('todos') ?? [];
    setState(() {
      _todos.clear();
      _todos.addAll(stored.map((e) => TodoItem.fromJson(jsonDecode(e))));
    });
    _autoDeleteCompleted();
  }

  Future<void> _saveTodos() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = _todos.map((e) => jsonEncode(e.toJson())).toList();
    await prefs.setStringList('todos', encoded);
  }

  void _autoDeleteCompleted() {
    final toDelete = _todos.where((todo) => todo.shouldAutoDelete).toList();
    if (toDelete.isNotEmpty) {
      setState(() {
        _todos.removeWhere((todo) => todo.shouldAutoDelete);
      });
      _saveTodos();
    }
  }

  void _addTodo() {
    final text = _controller.text.trim();
    if (text.isNotEmpty) {
      _showDeadlineDialog(text);
    }
  }

  Future<void> _showDeadlineDialog(String todoText) async {
    DateTime? selectedDeadline;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Set Deadline (Optional)'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Todo: $todoText'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now().add(const Duration(days: 1)),
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (date != null) {
                  final time = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay.now(),
                  );
                  if (time != null) {
                    selectedDeadline = DateTime(date.year, date.month, date.day, time.hour, time.minute);
                  }
                }
              },
              child: Text(selectedDeadline == null ? 'Set Deadline' : 'Deadline: ${_formatDateTime(selectedDeadline!)}'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final todo = TodoItem(
                text: todoText,
                createdAt: DateTime.now(),
                deadline: selectedDeadline,
              );
              setState(() {
                _todos.add(todo);
                _controller.clear();
              });
              _saveTodos();
              Navigator.pop(context);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _toggleTodo(int index) {
    setState(() {
      _todos[index].isCompleted = !_todos[index].isCompleted;
      if (_todos[index].isCompleted) {
        _todos[index].completedAt = DateTime.now();
      } else {
        _todos[index].completedAt = null;
      }
    });
    _saveTodos();
  }

  void _removeTodo(int index) {
    setState(() => _todos.removeAt(index));
    _saveTodos();
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  String _formatDuration(Duration duration) {
    final days = duration.inDays;
    final hours = duration.inHours % 24;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;

    if (days > 0) {
      return '${days}d ${hours}h ${minutes}m ${seconds}s';
    } else if (hours > 0) {
      return '${hours}h ${minutes}m ${seconds}s';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }

  Widget _buildTodoTile(TodoItem todo, int index) {
    final timeRemaining = todo.timeRemaining;
    final isOverdue = todo.isOverdue;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: Checkbox(
          value: todo.isCompleted,
          onChanged: (_) => _toggleTodo(index),
        ),
        title: Text(
          todo.text,
          style: TextStyle(
            decoration: todo.isCompleted ? TextDecoration.lineThrough : null,
            color: todo.isCompleted ? Colors.grey : null,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Created: ${_formatDateTime(todo.createdAt)}', style: const TextStyle(fontSize: 12)),
            if (todo.deadline != null) ...[
              Text('Deadline: ${_formatDateTime(todo.deadline!)}', style: const TextStyle(fontSize: 12)),
              if (!todo.isCompleted) ...[
                if (timeRemaining != null)
                  Text(
                    'Time left: ${_formatDuration(timeRemaining)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: timeRemaining.inHours < 24 ? Colors.orange : Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                else if (isOverdue)
                  const Text(
                    'OVERDUE',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ],
            if (todo.isCompleted && todo.completedAt != null) ...[
              Text('Completed: ${_formatDateTime(todo.completedAt!)}', style: const TextStyle(fontSize: 12)),
              Text(
                'Auto-delete in: ${_formatDuration(const Duration(hours: 24) - DateTime.now().difference(todo.completedAt!))}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete, color: Colors.red),
          onPressed: () => _removeTodo(index),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.themeMode == ThemeMode.dark;

    // Sort todos: incomplete first, then by deadline/creation time
    final sortedTodos = [..._todos];
    sortedTodos.sort((a, b) {
      if (a.isCompleted != b.isCompleted) {
        return a.isCompleted ? 1 : -1;
      }
      if (a.deadline != null && b.deadline != null) {
        return a.deadline!.compareTo(b.deadline!);
      }
      if (a.deadline != null) return -1;
      if (b.deadline != null) return 1;
      return b.createdAt.compareTo(a.createdAt);
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('To-Do List', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          Switch(value: isDark, onChanged: widget.onThemeChanged, activeColor: Colors.white),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      labelText: 'New To-Do',
                      border: OutlineInputBorder(),
                      hintText: 'Enter your task...',
                    ),
                    onSubmitted: (_) => _addTodo(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _addTodo,
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.amber,
                    backgroundColor: Colors.black87,
                  ),
                  child: const Text('Add'),
                ),
              ],
            ),
          ),
          if (_todos.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Total: ${_todos.length} • Active: ${_todos.where((t) => !t.isCompleted).length} • Completed: ${_todos.where((t) => t.isCompleted).length}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ),
          Expanded(
            child: _todos.isEmpty
                ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_outline, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No to-dos yet.', style: TextStyle(fontSize: 18, color: Colors.grey)),
                  Text('Add one above to get started!', style: TextStyle(color: Colors.grey)),
                ],
              ),
            )
                : ListView.builder(
              itemCount: sortedTodos.length,
              itemBuilder: (context, index) {
                final todoIndex = _todos.indexOf(sortedTodos[index]);
                return _buildTodoTile(sortedTodos[index], todoIndex);
              },
            ),
          ),
        ],
      ),
    );
  }
}