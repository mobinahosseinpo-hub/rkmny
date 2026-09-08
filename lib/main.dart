import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const RkmnyApp());
}

class RkmnyApp extends StatelessWidget {
  const RkmnyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'رقمك معي',
      theme: ThemeData(primarySwatch: Colors.teal, useMaterial3: true),
      home: const RegisterScreen(),
    );
  }
}

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _isLoading = false;

  Future<void> _registerUser() async {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();

    if (name.isEmpty || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء إدخال الاسم ورقم الهاتف')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final userDoc = FirebaseFirestore.instance.collection('users').doc();
      await userDoc.set({
        'id': userDoc.id,
        'name': name,
        'phone': phone,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      setState(() => _isLoading = false);

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => SavedUsersListScreen(currentUserId: userDoc.id),
        ),
      );
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ في الاتصال: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تسجيل البيانات - رقمك معي'), centerTitle: true),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.import_contacts, size: 80, color: Colors.teal),
            const SizedBox(height: 20),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'الاسم الكامل',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'رقم الهاتف',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.phone),
              ),
            ),
            const SizedBox(height: 25),
            _isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton.icon(
                    onPressed: _registerUser,
                    icon: const Icon(Icons.share),
                    label: const Text('مشاركة رقمي والتقاط أرقام جديدة'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}

class SavedUsersListScreen extends StatefulWidget {
  final String currentUserId;
  const SavedUsersListScreen({super.key, required this.currentUserId});

  @override
  State<SavedUsersListScreen> createState() => _SavedUsersListScreenState();
}

class _SavedUsersListScreenState extends State<SavedUsersListScreen> {
  List<Map<String, String>> _savedUsers = [];
  int _totalGlobalUsers = 0;

  @override
  void initState() {
    super.initState();
    _loadSavedUsers();
    _fetchGlobalUsersCount();
    _captureNewRandomUsers();
  }

  Future<void> _fetchGlobalUsersCount() async {
    final snapshot = await FirebaseFirestore.instance.collection('users').get();
    setState(() {
      _totalGlobalUsers = snapshot.docs.length;
    });
  }

  Future<void> _loadSavedUsers() async {
    final prefs = await SharedPreferences.getInstance();
    final String? usersJson = prefs.getString('saved_captured_users');
    if (usersJson != null) {
      final List<dynamic> decoded = jsonDecode(usersJson);
      setState(() {
        _savedUsers = decoded.map((e) => Map<String, String>.from(e)).toList();
      });
    }
  }

  Future<void> _captureNewRandomUsers() async {
    final snapshot = await FirebaseFirestore.instance.collection('users').get();
    final docs = snapshot.docs.where((doc) => doc.id != widget.currentUserId).toList();

    if (docs.isEmpty) return;

    docs.shuffle();
    final randomDocs = docs.take(3);

    bool hasNew = false;
    for (var doc in randomDocs) {
      final data = doc.data();
      final String phone = data['phone'] ?? '';
      final String name = data['name'] ?? '';

      bool exists = _savedUsers.any((u) => u['phone'] == phone);
      if (!exists && phone.isNotEmpty) {
        _savedUsers.add({'name': name, 'phone': phone});
        hasNew = true;
      }
    }

    if (hasNew) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('saved_captured_users', jsonEncode(_savedUsers));
      setState(() {});
    }
    _fetchGlobalUsersCount();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('الأرقام الملتقطة (${_savedUsers.length})'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.radar),
            tooltip: 'بحث جديد',
            onPressed: () {
              _captureNewRandomUsers();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('جاري البحث والتقاط أرقام جديدة...')),
              );
            },
          )
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.teal.shade50,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.people, color: Colors.teal),
                const SizedBox(width: 8),
                Text(
                  'إجمالي المشاركين في القاعدة: $_totalGlobalUsers',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal),
                ),
              ],
            ),
          ),
          Expanded(
            child: _savedUsers.isEmpty
                ? const Center(child: Text('اضغط زر الرادار بالفي أعلى لالتقاط أرقام'))
                : ListView.builder(
                    itemCount: _savedUsers.length,
                    itemBuilder: (context, index) {
                      final user = _savedUsers[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        child: ListTile(
                          leading: const CircleAvatar(child: Icon(Icons.person)),
                          title: Text(user['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(user['phone'] ?? ''),
                          trailing: IconButton(
                            icon: const Icon(Icons.phone, color: Colors.green),
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('اتصال بـ ${user['phone']}')),
                              );
                            },
                          ),
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
