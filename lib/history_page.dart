import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:brower_app/searching_page.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  _HistoryPageState createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  List<Map<String, dynamic>> _history = [];
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> savedHistory = prefs.getStringList('history') ?? [];
    print("load history length: ${savedHistory.length}");
    print("history list: $savedHistory");

    setState(() {
      _history =
          savedHistory.map((entry) {
            List<String> parts = entry.split('|');
            return {'date': DateTime.parse(parts[0]), 'url': parts[1]};
          }).toList();
    });
  }

  Future<void> _removeHistoryItem(int index) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    _history.removeAt(index);

    List<String> updatedHistory =
        _history
            .map((item) => '${item['date'].toIso8601String()}|${item['url']}')
            .toList();
    await prefs.setStringList('history', updatedHistory);

    setState(() {});
  }

  void _openSearchingPage(String url) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => SearchingPage(searchQuery: url)),
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  List<Map<String, dynamic>> _getFilteredHistory() {
    if (_selectedDate == null) {
      return _history;
    }
    return _history.where((item) {
      DateTime itemDate = item['date'];
      return itemDate.year == _selectedDate!.year &&
          itemDate.month == _selectedDate!.month &&
          itemDate.day == _selectedDate!.day;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    List<Map<String, dynamic>> filteredHistory = _getFilteredHistory();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lịch sử duyệt web'),
        actions: [
          IconButton(
            icon: Icon(Icons.calendar_today),
            onPressed: () => _selectDate(context),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_selectedDate != null)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                'Lọc theo ngày: ${DateFormat('dd/MM/yyyy').format(_selectedDate!)}',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          Expanded(
            child:
                filteredHistory.isEmpty
                    ? Center(child: Text("Không có lịch sử nào"))
                    : ListView.builder(
                      itemCount: filteredHistory.length,
                      itemBuilder: (context, index) {
                        final item = filteredHistory[index];
                        return Dismissible(
                          key: Key(item['url']),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            color: Colors.red,
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            child: const Icon(
                              Icons.delete,
                              color: Colors.white,
                            ),
                          ),
                          onDismissed: (direction) => _removeHistoryItem(index),
                          child: ListTile(
                            leading: const Icon(Icons.history),
                            title: Text(item['url']),
                            subtitle: Text(
                              DateFormat(
                                'dd/MM/yyyy HH:mm',
                              ).format(item['date']),
                            ),
                            onTap: () => _openSearchingPage(item['url']),
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
