import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

void main() {
  runApp(const ContactApp());
}

class ContactApp extends StatelessWidget {
  const ContactApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Contact Management App',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const ContactHomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('contacts.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE contacts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        phone TEXT NOT NULL,
        email TEXT NOT NULL,
        address TEXT NOT NULL
      )
    ''');
  }

  Future<int> insertContact(Map<String, dynamic> row) async {
    final db = await instance.database;
    return await db.insert('contacts', row);
  }

  Future<List>> getContacts() async {
    final db = await instance.database;
    return await db.query('contacts', orderBy: 'name ASC');
  }

  Future<List>> searchContacts(String keyword) async {
    final db = await instance.database;
    return await db.query(
      'contacts',
      where: 'name LIKE ?',
      whereArgs: ['%$keyword%'],
    );
  }

  Future<int> updateContact(Map<String, dynamic> row) async {
    final db = await instance.database;
    int id = row['id'];
    return await db.update('contacts', row, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteContact(int id) async {
    final db = await instance.database;
    return await db.delete('contacts', where: 'id = ?', whereArgs: [id]);
  }
}

class ContactHomePage extends StatefulWidget {
  const ContactHomePage({super.key});

  @override
  State<ContactHomePage> createState() => _ContactHomePageState();
}

class _ContactHomePageState extends State<ContactHomePage> {
  List> _contacts = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _refreshContacts();
  }

  void _refreshContacts() async {
    setState(() => _isLoading = true);
    final data = await DatabaseHelper.instance.getContacts();
    setState(() {
      _contacts = data;
      _isLoading = false;
    });
  }

  void _search(String keyword) async {
    if (keyword.isEmpty) {
      _refreshContacts();
    } else {
      final data = await DatabaseHelper.instance.searchContacts(keyword);
      setState(() {
        _contacts = data;
      });
    }
  }

  void _deleteContact(int id) async {
    await DatabaseHelper.instance.deleteContact(id);
    _refreshContacts();
  }

  void _showForm(Map<String, dynamic>? item) async {
    final nameController = TextEditingController(text: item?['name'] ?? '');
    final phoneController = TextEditingController(text: item?['phone'] ?? '');
    final emailController = TextEditingController(text: item?['email'] ?? '');
    final addressController = TextEditingController(text: item?['address'] ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(item == null ? 'Add New Contact' : 'Edit Contact'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Name')),
              TextField(controller: phoneController, decoration: const InputDecoration(labelText: 'Phone Number'), keyboardType: TextInputType.phone),
              TextField(controller: emailController, decoration: const InputDecoration(labelText: 'Email'), keyboardType: TextInputType.emailAddress),
              TextField(controller: addressController, decoration: const InputDecoration(labelText: 'Address')),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isEmpty || phoneController.text.isEmpty) return;

              if (item == null) {
                await DatabaseHelper.instance.insertContact({
                  'name': nameController.text,
                  'phone': phoneController.text,
                  'email': emailController.text,
                  'address': addressController.text,
                });
              } else {
                await DatabaseHelper.instance.updateContact({
                  'id': item['id'],
                  'name': nameController.text,
                  'phone': phoneController.text,
                  'email': emailController.text,
                  'address': addressController.text,
                });
              }

              Navigator.pop(context);
              _refreshContacts();
            },
            child: Text(item == null ? 'Save' : 'Update'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Contact Manager'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              onChanged: _search,
              decoration: InputDecoration(
                hintText: 'Search contacts by name...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _contacts.isEmpty
          ? const Center(child: Text('No contacts found. Add some!'))
          : ListView.builder(
        itemCount: _contacts.length,
        itemBuilder: (context, index) {
          final contact = _contacts[index];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            child: ListTile(
              leading: CircleAvatar(
                child: Text(contact['name'][0].toUpperCase()),
              ),
              title: Text(contact['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Phone: ${contact['phone']}'),
                  Text('Email: ${contact['email']}'),
                  Text('Address: ${contact['address']}'),
                ],
              ),
              isThreeLine: true,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.blue),
                    onPressed: () => _showForm(contact),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _deleteContact(contact['id']),
                  ),
                ],
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showForm(null),
        child: const Icon(Icons.add),
        tooltip: 'Add Contact',
      ),
    );
  }
}