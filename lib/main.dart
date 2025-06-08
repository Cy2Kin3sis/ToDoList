import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const ToDoList());
}

class ToDoList extends StatefulWidget {
  const ToDoList({super.key});
  @override
  State<ToDoList> createState() => _ToDoListState();
}
class _ToDoListState extends State<ToDoList> {
  ThemeMode _themeMode = ThemeMode.light;

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool('isDark') ?? false;
    setState(() {
      _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    });
  }

  Future<void> _toggleTheme(bool isDark) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDark', isDark);
    setState(() {
      _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'To-Do List',
      theme: ThemeData.light(),
      darkTheme: ThemeData.dark(),
      themeMode: _themeMode,
      home: TodoHome(
        themeMode: _themeMode,
        onThemeChanged: _toggleTheme,
      ),
      debugShowCheckedModeBanner: false,
    );
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
  final List<String> _todos = [];
  final TextEditingController _controller = TextEditingController();

  void _addTodo() {
    final text = _controller.text.trim();
    if (text.isNotEmpty) {
      setState(() {
        _todos.add(text);
        _controller.clear();
      });
    }
  }

  void _removeTodo(int index) {
    setState(() {
      _todos.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.themeMode == ThemeMode.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('To-Do List'),
        actions: [
          Switch(
            value: isDark,
            onChanged: widget.onThemeChanged,
            activeColor: Colors.white,
          ),
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
                    ),
                    onSubmitted: (_) => _addTodo(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _addTodo,
                  child: const Text('Add'),
                ),
              ],
            ),
          ),
          Expanded(
            child: _todos.isEmpty
                ? const Center(child: Text('No to-dos yet.'))
                : ListView.builder(
              itemCount: _todos.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(_todos[index]),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _removeTodo(index),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
