import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HistoryPage extends StatefulWidget {
  @override
  _HistoryPageState createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  List<String> _history = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String>? savedHistory = prefs.getStringList('history');

    if (savedHistory != null) {
      setState(() {
        _history = savedHistory;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Lịch sử duyệt web')),
      body:
          _history.isEmpty
              ? const Center(child: Text("Không có lịch sử nào"))
              : ListView.builder(
                itemCount: _history.length,
                itemBuilder: (context, index) {
                  return ListTile(
                    leading: Icon(Icons.history),
                    title: Text(_history[index]),
                    onTap: () {
                      // Khi click vào một mục lịch sử, có thể mở trang web đó
                    },
                  );
                },
              ),
    );
  }
}
