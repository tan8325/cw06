import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(TaskApp());
}

final auth = FirebaseAuth.instance;
final firestore = FirebaseFirestore.instance;

class TaskApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CW06',
      theme: ThemeData(primarySwatch: Colors.indigo),
      home: StreamBuilder<User?>(
        stream: auth.authStateChanges(),
        builder: (context, snapshot) {
          return snapshot.hasData ? TaskListScreen() : AuthScreen();
        },
      ),
    );
  }
}

class AuthScreen extends StatefulWidget {
  @override
  _AuthScreenState createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  bool isLogin = true;

  void _authUser() async {
    try {
      if (isLogin) {
        await auth.signInWithEmailAndPassword(email: emailCtrl.text, password: passCtrl.text);
      } else {
        await auth.createUserWithEmailAndPassword(email: emailCtrl.text, password: passCtrl.text);
      }
    } catch (e) {
      showDialog(context: context, builder: (_) => AlertDialog(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(isLogin ? 'Login' : 'Register')),
      body: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(controller: emailCtrl, decoration: InputDecoration(labelText: 'Email')),
            TextField(controller: passCtrl, decoration: InputDecoration(labelText: 'Password'), obscureText: true),
            SizedBox(height: 20),
            ElevatedButton(onPressed: _authUser, child: Text(isLogin ? 'Login' : 'Register')),
            TextButton(
              onPressed: () => setState(() => isLogin = !isLogin),
              child: Text(isLogin ? 'Create Account' : 'Back to Login'),
            )
          ],
        ),
      ),
    );
  }
}

class TaskListScreen extends StatefulWidget {
  @override
  _TaskListScreenState createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> {
  final taskCtrl = TextEditingController();
  String get userId => auth.currentUser!.uid;
  CollectionReference get tasks => firestore.collection('users').doc(userId).collection('tasks');

  void _addTask() {
    final title = taskCtrl.text.trim();
    if (title.isEmpty) return;
    tasks.add({'title': title, 'completed': false, 'timestamp': FieldValue.serverTimestamp()});
    taskCtrl.clear();
  }

  void _toggleTask(String id, bool done) => tasks.doc(id).update({'completed': !done});
  void _deleteTask(String id) => tasks.doc(id).delete();

  void _addSubtask(String taskId) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Add Subtask'),
        content: TextField(controller: ctrl, decoration: InputDecoration(hintText: 'Subtask title')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final title = ctrl.text.trim();
              if (title.isNotEmpty) {
                tasks.doc(taskId).collection('subtasks').add({
                  'title': title,
                  'completed': false,
                  'time': FieldValue.serverTimestamp(),
                });
              }
              Navigator.pop(context);
            },
            child: Text('Add'),
          ),
        ],
      ),
    );
  }

  void _toggleSub(String taskId, String subId, bool done) =>
      tasks.doc(taskId).collection('subtasks').doc(subId).update({'completed': !done});

  void _deleteSub(String taskId, String subId) =>
      tasks.doc(taskId).collection('subtasks').doc(subId).delete();

  Widget _buildSubtasks(String taskId) {
    return StreamBuilder<QuerySnapshot>(
      stream: tasks.doc(taskId).collection('subtasks').orderBy('time').snapshots(),
      builder: (_, snap) {
        if (!snap.hasData) return SizedBox();
        return Column(
          children: snap.data!.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final title = data['title'] ?? '';
            final done = data['completed'] ?? false;

            return ListTile(
              leading: Checkbox(value: done, onChanged: (_) => _toggleSub(taskId, doc.id, done)),
              title: Text(title, style: TextStyle(decoration: done ? TextDecoration.lineThrough : null)),
              trailing: IconButton(
                icon: Icon(Icons.delete, size: 20),
                onPressed: () => _deleteSub(taskId, doc.id),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Your Tasks'),
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () async {
              await auth.signOut();
            },
          )
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(child: TextField(controller: taskCtrl, decoration: InputDecoration(labelText: 'New task'))),
                SizedBox(width: 8),
                ElevatedButton(onPressed: _addTask, child: Icon(Icons.add)),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: tasks.orderBy('timestamp', descending: true).snapshots(),
              builder: (_, snapshot) {
                if (!snapshot.hasData) return Center(child: CircularProgressIndicator());
                return ListView(
                  children: snapshot.data!.docs.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final title = data['title'] ?? '';
                    final done = data['completed'] ?? false;
                    final id = doc.id;

                    return Card(
                      margin: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: ExpansionTile(
                        title: Row(
                          children: [
                            Checkbox(value: done, onChanged: (_) => _toggleTask(id, done)),
                            Expanded(
                              child: Text(title, style: TextStyle(decoration: done ? TextDecoration.lineThrough : null)),
                            ),
                            IconButton(icon: Icon(Icons.delete), onPressed: () => _deleteTask(id)),
                            IconButton(icon: Icon(Icons.add_task), onPressed: () => _addSubtask(id)),
                          ],
                        ),
                        children: [_buildSubtasks(id)],
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
