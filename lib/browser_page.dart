import 'package:brower_app/searching_page.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BrowserPage extends StatefulWidget {
  const BrowserPage({super.key});

  @override
  State<BrowserPage> createState() => _BrowserPageState();
}

class _BrowserPageState extends State<BrowserPage> {
  final TextEditingController _searchController = TextEditingController();
  List<String> _tabs = [];
  int _currentTabIndex = 0;

  Future<void> _loadTabsFromCache() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String>? savedTabs = prefs.getStringList('saved_tabs');

    if (savedTabs != null && savedTabs.isNotEmpty) {
      setState(() {
        _tabs = savedTabs;
        _currentTabIndex = 0;
        print("load được nèeee");
      });
    }
  }

  Future<void> _saveTabsToCache() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('saved_tabs', _tabs);
  }

  void _onSearch() {
    String query = _searchController.text.trim();
    if (query.isEmpty) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SearchingPage(searchQuery: query),
      ),
    );
  }

  void _removeTab(int index) {
    setState(() {
      _tabs.removeAt(index);
      if (_tabs.isEmpty) {
        _currentTabIndex = 0;
      } else if (_currentTabIndex >= _tabs.length) {
        _currentTabIndex = _tabs.length - 1;
      }
    });
    _saveTabsToCache();
  }

  void _showTabs() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          height: 300,
          color: Colors.grey[900],
          child: ListView.builder(
            itemCount: _tabs.length,
            itemBuilder: (context, index) {
              String tabUrl = _tabs[index];

              return Dismissible(
                key: Key(tabUrl),
                direction: DismissDirection.endToStart,
                background: Container(
                  color: Colors.red,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                onDismissed: (direction) => _removeTab(index),
                child: ListTile(
                  leading: Image.network(
                    _getFaviconUrl(tabUrl), // Gọi hàm lấy favicon
                    width: 24,
                    height: 24,
                    errorBuilder:
                        (context, error, stackTrace) =>
                            const Icon(Icons.web, color: Colors.white),
                  ),
                  title: Text(
                    tabUrl,
                    style: const TextStyle(color: Colors.white),
                    overflow:
                        TextOverflow
                            .ellipsis, // Giới hạn hiển thị nếu URL quá dài
                  ),
                  onTap: () {
                    setState(() {
                      _currentTabIndex = index;
                    });

                    Navigator.pop(context);

                    // Chuyển sang SearchingPage với URL đã chọn
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (context) => SearchingPage(searchQuery: tabUrl),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        );
      },
    );
  }

  String _getFaviconUrl(String url) {
    Uri uri = Uri.parse(url);
    return "${uri.scheme}://${uri.host}/favicon.ico";
  }

  void _addNewTab() async {
    setState(() {
      _tabs.add("https://www.google.com"); // Thêm tab mới
      _currentTabIndex = _tabs.length - 1; // Chuyển đến tab mới
    });

    await _saveTabsToCache(); // 🔥 Lưu danh sách tab mới vào cache

    // Chuyển sang SearchingPage với tab mới
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => SearchingPage(searchQuery: _tabs[_currentTabIndex]),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _loadTabsFromCache();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadTabsFromCache(); // Gọi lại hàm load dữ liệu khi quay lại trang
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 38, 38, 39),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                children: [
                  _buildShortcutSection(),
                  const SizedBox(height: 16),
                  _buildBookmarkSection(),
                ],
              ),
            ),

            // Thanh tìm kiếm
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Tìm kiếm hoặc nhập URL',
                        hintStyle: const TextStyle(color: Colors.white60),
                        prefixIcon: const Icon(
                          Icons.search,
                          color: Colors.white,
                        ),
                        filled: true,
                        fillColor: Colors.grey[800],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onSubmitted: (_) => _onSearch(),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.arrow_forward, color: Colors.white),
                    onPressed: _onSearch,
                  ),
                ],
              ),
            ),

            // Thanh điều hướng
            _buildBottomNavigation(),
          ],
        ),
      ),
    );
  }

  Widget _buildShortcutSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Container(
        decoration: _boxDecoration(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Lối tắt',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w400,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 4,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              children: [
                _buildShortcutItem(Icons.star, 'Dấu trang'),
                _buildShortcutItem(Icons.list, 'Danh sách đọc'),
                _buildShortcutItem(Icons.tab, 'Các thẻ gần đây'),
                _buildShortcutItem(Icons.history, 'Nhật ký'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookmarkSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Container(
        decoration: _boxDecoration(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Bookmark',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w400,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 4,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              children: [
                _buildBookmarkItem('assets/windy.png', 'Windy'),
                _buildBookmarkItem('assets/chatgpt.png', 'ChatGPT'),
                _buildBookmarkItem('assets/edu.png', 'Cổng Thông tin đào tạo'),
                _buildBookmarkItem('assets/learning.png', 'Learning M...'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNavigation() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[900],
        border: const Border(top: BorderSide(color: Colors.grey, width: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () {}, // Thêm logic back khi cần
            ),
            IconButton(
              icon: const Icon(Icons.arrow_forward, color: Colors.white),
              onPressed: () {}, // Thêm logic forward khi cần
            ),
            FloatingActionButton.small(
              backgroundColor: Colors.blue,
              child: const Icon(Icons.add),
              onPressed: _addNewTab, // Gọi hàm thêm tab mới
            ),
            GestureDetector(
              onTap: _showTabs,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '${_tabs.length}',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.more_horiz, color: Colors.white),
              onPressed: _showTabs,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShortcutItem(IconData icon, String label) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[800],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Colors.white),
        ),
        const SizedBox(height: 8),
        Flexible(
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: Colors.white),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildBookmarkItem(String imagePath, String title) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.grey[800],
            image: DecorationImage(
              image: AssetImage(imagePath),
              fit: BoxFit.cover,
            ),
          ),
        ),
        const SizedBox(height: 2),
        SizedBox(
          width: 80,
          height: 32,
          child: Text(
            title,
            style: const TextStyle(color: Colors.white, fontSize: 12),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  BoxDecoration _boxDecoration() {
    return BoxDecoration(
      color: const Color(0xFF2A2D32),
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.2),
          blurRadius: 8,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }
}
