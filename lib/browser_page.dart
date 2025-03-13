import 'dart:convert';
import 'dart:math';

import 'package:brower_app/chat_bubble.dart';
import 'package:brower_app/history_page.dart';
import 'package:brower_app/searching_page.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

class BrowserPage extends StatefulWidget {
  const BrowserPage({super.key});

  @override
  State<BrowserPage> createState() => _BrowserPageState();
}

class _BrowserPageState extends State<BrowserPage> {
  final TextEditingController _searchController = TextEditingController();
  List<String> _tabs = [];
  List<Map<String, String>> _bookmarks = [];
  int _currentTabIndex = 0;
  double posX = 20.0;
  double posY = 100.0;

  final TextEditingController _chatController = TextEditingController();
  List<Map<String, dynamic>> _chatHistory = [];

  @override
  void initState() {
    super.initState();
    _loadTabsFromCache();
    _loadBookmarksFromCache();
  }

  void sendMessage(String message) async {
    if (message.isEmpty) return;

    setState(() {
      _chatHistory.add({"text": message, "isUser": true});
    });

    _chatController.clear();

    try {
      final data = await callChatAPI(message); // Gọi API và nhận về dữ liệu

      // Lấy phản hồi từ trường "response" trong dữ liệu trả về
      String botReply = data["response"] ?? "Không nhận được phản hồi";

      setState(() {
        _chatHistory.add({"text": botReply, "isUser": false});
      });
    } catch (e) {
      print("API Error: $e");
      setState(() {
        _chatHistory.add({
          "text": "Lỗi kết nối đến máy chủ: $e",
          "isUser": false,
        });
      });
    }
  }

  Future<Map<String, dynamic>> callChatAPI(String message) async {
    try {
      final response = await http.post(
        Uri.parse('http://10.0.2.2:8000/chat'),
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Accept': 'application/json',
        },
        body: utf8.encode(
          jsonEncode({"message": message, "conversation_history": []}),
        ),
      );

      if (response.statusCode == 200) {
        // Đảm bảo decode UTF-8 đúng cách
        final String decodedResponse = utf8.decode(response.bodyBytes);
        final data = jsonDecode(decodedResponse);
        debugPrint("API response decoded: $data");

        // Đảm bảo response text cũng được decode UTF-8
        if (data.containsKey("response")) {
          data["response"] = data["response"].toString();
        }

        return data;
      } else {
        debugPrint("Error status code: ${response.statusCode}");
        debugPrint("Error body: ${utf8.decode(response.bodyBytes)}");
        throw Exception("Lỗi API: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("Exception during API call: $e");
      throw Exception("Lỗi kết nối: $e");
    }
  }

  String _getTitleFromUrl(String url) {
    Uri uri = Uri.parse(url);
    String domain = uri.host;
    return domain.length > 10 ? "${domain.substring(0, 10)}..." : domain;
  }

  String _getIconFromUrl(String url) {
    Uri uri = Uri.parse(url);
    return "https://www.google.com/s2/favicons?domain=${uri.host}&sz=64";
  }

  Future<void> _loadBookmarksFromCache() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String>? savedBookmarks = prefs.getStringList('bookmarks');

    if (savedBookmarks != null) {
      setState(() {
        _bookmarks =
            savedBookmarks
                .map(
                  (url) => {
                    'url': url,
                    'title': _getTitleFromUrl(url),
                    'icon': _getIconFromUrl(url),
                  },
                )
                .toList();
      });
    }
  }

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

  void _onSearch() async {
    String query = _searchController.text.trim();
    if (query.isEmpty) return;

    // Kiểm tra nếu query là một URL hợp lệ
    bool isUrl =
        query.startsWith("http://") ||
        query.startsWith("https://") ||
        (query.contains(".") && !query.contains(" "));

    String searchUrl =
        isUrl
            ? (query.startsWith("http") ? query : "https://$query")
            : "https://www.google.com/search?q=$query"; // Chuyển đổi thành URL tìm kiếm

    setState(() {
      _tabs.add(searchUrl); // Thêm tab mới
      _currentTabIndex = _tabs.length - 1; // Chuyển đến tab mới nhất
    });

    _saveTabsToCache(); // Lưu danh sách tab vào cache

    // Mở `searching_page` với URL vừa thêm
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SearchingPage(searchQuery: searchUrl),
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
      _tabs.add("https://www.google.com"); // Thêm tab mới vào cuối danh sách
      _currentTabIndex = _tabs.length - 1; // Chuyển đến tab mới nhất
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
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadTabsFromCache(); // Gọi lại hàm load dữ liệu khi quay lại trang
  }

  Future<void> _removeBookmark(int index) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> listBM = prefs.getStringList('bookmarks') ?? [];

    setState(() {
      listBM.removeAt(index);
    });
    await prefs.setStringList('bookmarks', listBM ?? []);
  }

  void _showBookmarks() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          height: 300,
          color: Colors.grey[900],
          child:
              _bookmarks.isEmpty
                  ? const Center(
                    child: Text(
                      "No bookmarks available",
                      style: TextStyle(color: Colors.white),
                    ),
                  )
                  : ListView.builder(
                    itemCount: _bookmarks.length,
                    itemBuilder: (context, index) {
                      String tabUrl = _bookmarks[index]['url'] ?? '';
                      String tabTitle =
                          _bookmarks[index]['title'] ?? 'Untitled';
                      String iconUrl = _bookmarks[index]['icon'] ?? '';

                      return Dismissible(
                        key: Key(tabUrl),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          color: Colors.red,
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        onDismissed: (direction) => _removeBookmark(index),
                        child: ListTile(
                          leading:
                              iconUrl.isNotEmpty
                                  ? Image.network(
                                    iconUrl,
                                    width: 24,
                                    height: 24,
                                    errorBuilder:
                                        (context, error, stackTrace) =>
                                            const Icon(
                                              Icons.web,
                                              color: Colors.white,
                                            ),
                                  )
                                  : const Icon(Icons.web, color: Colors.white),
                          title: Text(
                            tabTitle,
                            style: const TextStyle(color: Colors.white),
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            tabUrl,
                            style: const TextStyle(color: Colors.grey),
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (context) =>
                                        SearchingPage(searchQuery: tabUrl),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 38, 38, 39),
      // Wrap your existing body with a Stack to add the floating button
      body: Stack(
        children: [
          // Your existing SafeArea content
          SafeArea(
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
                        icon: const Icon(
                          Icons.arrow_forward,
                          color: Colors.white,
                        ),
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

          // Add the floating button
          Positioned(
            left: posX,
            top: posY,
            child: Draggable(
              feedback: floatingButton(),
              childWhenDragging: Container(),
              onDragEnd: (details) {
                setState(() {
                  posX = details.offset.dx.clamp(
                    0.0,
                    MediaQuery.of(context).size.width - 60,
                  );
                  posY = details.offset.dy.clamp(
                    0.0,
                    MediaQuery.of(context).size.height - 60,
                  );
                });
              },
              child: floatingButton(),
            ),
          ),
        ],
      ),
    );
  }

  // Add this method for the floating button
  Widget floatingButton() {
    return GestureDetector(
      onTap: () => openChat(context),
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: Colors.blue,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(color: Colors.black26, blurRadius: 10, spreadRadius: 2),
          ],
        ),
        child: const Icon(Icons.chat, color: Colors.white, size: 30),
      ),
    );
  }

  void openChat(BuildContext context) {
    // Tạo một controller riêng cho ListView để có thể cuộn xuống khi có tin nhắn mới
    final ScrollController _scrollController = ScrollController();

    // Tạo một bản sao của chat history để sử dụng trong modal
    List<Map<String, dynamic>> _localChatHistory = List.from(_chatHistory);

    // Hàm để cuộn xuống cuối danh sách tin nhắn
    void _scrollToBottom() {
      if (_scrollController.hasClients) {
        Future.delayed(const Duration(milliseconds: 100), () {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        });
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            // Hàm gửi tin nhắn trong context của modal bottom sheet
            void _sendMessageInChat(String message) async {
              if (message.isEmpty) return;

              // Cập nhật cả state của modal và state của widget cha
              setModalState(() {
                _localChatHistory.add({"text": message, "isUser": true});
              });

              setState(() {
                _chatHistory = List.from(_localChatHistory);
              });

              _chatController.clear();
              _scrollToBottom();

              try {
                final data = await callChatAPI(message);
                String botReply =
                    data["response"] ?? "Không nhận được phản hồi";

                // Cập nhật cả state của modal và state của widget cha
                setModalState(() {
                  _localChatHistory.add({"text": botReply, "isUser": false});
                });

                setState(() {
                  _chatHistory = List.from(_localChatHistory);
                });

                _scrollToBottom();
                debugPrint("Chat history updated: $_localChatHistory");
              } catch (e) {
                debugPrint("API Error: $e");

                // Cập nhật cả state của modal và state của widget cha
                setModalState(() {
                  _localChatHistory.add({
                    "text": "Lỗi kết nối đến máy chủ: $e",
                    "isUser": false,
                  });
                });

                setState(() {
                  _chatHistory = List.from(_localChatHistory);
                });

                _scrollToBottom();
              }
            }

            return FractionallySizedBox(
              heightFactor: 0.8,
              child: Column(
                children: [
                  // Tiêu đề chat
                  Container(
                    padding: const EdgeInsets.all(16),
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      color: Colors.blue,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(20),
                      ),
                    ),
                    child: const Text(
                      'Chat với chúng tôi',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                  // Phần hiển thị tin nhắn
                  Expanded(
                    child:
                        _localChatHistory.isEmpty
                            ? const Center(
                              child: Text(
                                "Hãy gửi tin nhắn để bắt đầu cuộc trò chuyện",
                                style: TextStyle(color: Colors.grey),
                              ),
                            )
                            : ListView.builder(
                              controller: _scrollController,
                              padding: const EdgeInsets.all(10),
                              itemCount: _localChatHistory.length,
                              itemBuilder: (context, index) {
                                final message = _localChatHistory[index];
                                return ChatBubble(
                                  key: ValueKey(
                                    "chat_${index}_${message["isUser"]}",
                                  ),
                                  text: message["text"] ?? "",
                                  isUser: message["isUser"] ?? false,
                                );
                              },
                            ),
                  ),

                  // Ô nhập tin nhắn
                  Padding(
                    padding: MediaQuery.of(context).viewInsets,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        border: Border(
                          top: BorderSide(color: Colors.grey, width: 0.5),
                        ),
                      ),
                      child: Row(
                        children: [
                          // Ô nhập văn bản
                          Expanded(
                            child: TextField(
                              controller: _chatController,
                              decoration: const InputDecoration(
                                hintText: "Nhập tin nhắn...",
                                border: InputBorder.none,
                              ),
                              onSubmitted: (text) {
                                if (text.isNotEmpty) {
                                  _sendMessageInChat(text);
                                }
                              },
                            ),
                          ),

                          // Nút gửi tin nhắn
                          IconButton(
                            icon: const Icon(Icons.send, color: Colors.blue),
                            onPressed: () {
                              if (_chatController.text.isNotEmpty) {
                                _sendMessageInChat(_chatController.text);
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    ).then((_) {
      // Khi đóng modal, cập nhật lại chat history của widget cha
      setState(() {
        _chatHistory = List.from(_localChatHistory);
      });
    });
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
                _buildShortcutItem(
                  Icons.star,
                  'Dấu trang',
                  onTap: _showBookmarks,
                ),
                _buildShortcutItem(Icons.list, 'Danh sách đọc'),
                _buildShortcutItem(Icons.tab, 'Các thẻ gần đây'),
                _buildShortcutItem(
                  Icons.history,
                  'Nhật ký',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => HistoryPage()),
                    );
                  },
                ),
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
            _bookmarks.isEmpty
                ? const Center(
                  child: Text(
                    'Chưa có bookmark nào',
                    style: TextStyle(color: Colors.white60),
                  ),
                )
                : GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                  ),
                  itemCount: min(4, _bookmarks.length),
                  itemBuilder: (context, index) {
                    return _buildBookmarkItem(
                      _bookmarks[index]['icon'] ?? 'assets/default.png',
                      _bookmarks[index]['title'] ?? 'No Title',
                      _bookmarks[index]['url'] ?? '',
                    );
                  },
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
              onPressed: () {},
            ),
            IconButton(
              icon: const Icon(Icons.arrow_forward, color: Colors.white),
              onPressed: () {},
            ),
            FloatingActionButton.small(
              backgroundColor: Colors.blue,
              onPressed: _addNewTab,
              child: const Icon(Icons.add),
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

  Widget _buildShortcutItem(
    IconData icon,
    String title, {
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap, // Xử lý khi bấm vào mục
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildBookmarkItem(String iconPath, String title, String url) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SearchingPage(searchQuery: url),
          ),
        );
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.network(
            iconPath,
            width: 40,
            height: 40,
            errorBuilder:
                (context, error, stackTrace) =>
                    const Icon(Icons.bookmark, color: Colors.white),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(color: Colors.white),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
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
