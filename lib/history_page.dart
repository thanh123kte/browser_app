import 'package:brower_app/searching_page.dart';
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

  Future<void> _removeHistoryItem(int index) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    _history.removeAt(index);

    await Future.delayed(
      Duration(milliseconds: 100),
    ); // Chờ trước khi cập nhật UI

    if (!mounted) return;
    setState(() {});

    await prefs.setStringList('history', _history);
  }

  void _openSearchingPage(String url) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => SearchingPage(searchQuery: url)),
    );
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
                  return Dismissible(
                    key: Key(_history[index]),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      color: Colors.red,
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      child: const Icon(Icons.delete, color: Colors.white),
                    ),
                    onDismissed: (direction) async {
                      if (index >= _history.length) return;

                      String deletedItem = _history[index];
                      _history.removeAt(index);

                      await Future.delayed(
                        Duration(milliseconds: 100),
                      ); // Thêm delay để load lại

                      if (!mounted) return;
                      setState(() {});

                      SharedPreferences prefs =
                          await SharedPreferences.getInstance();
                      await prefs.setStringList('history', _history);

                      // Hiển thị SnackBar với Undo
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text("Đã xóa lịch sử: $deletedItem"),
                          action: SnackBarAction(
                            label: "Hoàn tác",
                            onPressed: () {
                              if (!mounted) return;
                              setState(() {
                                if (index <= _history.length) {
                                  _history.insert(index, deletedItem);
                                }
                              });
                              prefs.setStringList('history', _history);
                            },
                          ),
                        ),
                      );
                    },
                    child: ListTile(
                      leading: const Icon(Icons.history),
                      title: Text(_history[index]),
                      onTap: () {
                        _openSearchingPage(_history[index]);
                      },
                    ),
                  );
                },
              ),
    );
  }
}
