import 'package:brower_app/browser_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SearchingPage extends StatefulWidget {
  final String searchQuery;

  const SearchingPage({super.key, required this.searchQuery});

  @override
  State<SearchingPage> createState() => _SearchingPageState();
}

class _SearchingPageState extends State<SearchingPage> {
  late InAppWebViewController _webViewController;
  late TextEditingController _textController;
  bool _isLoading = true; // Trạng thái loading
  List<String> _tabs = []; // Danh sách tab
  List<String> _bookmarkedTabs = [];
  int _currentTabIndex = 0; // Tab đang mở
  List<String> _history = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
    _textController = TextEditingController(text: widget.searchQuery);
    _tabs.add(_processSearchQuery(widget.searchQuery));
    _loadTabsFromCache();
  }

  void _initializeWebView(String url) {
    if (_webViewController != null) {
      _webViewController.loadUrl(urlRequest: URLRequest(url: WebUri(url)));
    }
  }

  /// Xử lý URL hoặc tìm kiếm trên Google
  String _processSearchQuery(String query) {
    if (query.startsWith('http') || query.contains('.')) {
      return query.startsWith('http') ? query : 'https://$query';
    } else {
      return 'https://www.google.com/search?q=$query';
    }
  }

  void _addToHistory(String url) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> history = prefs.getStringList('history') ?? [];

    // Tạo một entry mới với URL và timestamp
    String newEntry = '${DateTime.now().toIso8601String()}|$url';

    // Xóa entry cũ nếu đã tồn tại
    history.removeWhere((entry) => entry.split('|')[1] == url);

    // Thêm entry mới vào đầu danh sách
    history.insert(0, newEntry);

    // Giới hạn lịch sử đến 100 mục
    if (history.length > 100) {
      history = history.sublist(0, 100);
    }

    await prefs.setStringList('history', history);
    print("ddax add : ${newEntry}");
  }

  Future<void> _loadTabsFromCache() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String>? savedTabs = prefs.getStringList('saved_tabs');

    if (savedTabs != null && savedTabs.isNotEmpty) {
      setState(() {
        _tabs = savedTabs;
        _currentTabIndex = 0;
      });
    }
  }

  /// Mở tab mới
  void _addNewTab() {
    setState(() {
      _tabs.add('https://www.google.com');
      _currentTabIndex = _tabs.length - 1;
      _initializeWebView(_tabs[_currentTabIndex]);
    });
    _saveTabsToCache(); // 🔥 Lưu vào cache
  }

  /// Chuyển tab
  void _switchTab(int index) {
    if (index >= 0 && index < _tabs.length) {
      // Kiểm tra chỉ số hợp lệ
      setState(() {
        _currentTabIndex = index;
        _initializeWebView(_tabs[index]);
      });
    }
  }

  /// Hiển thị danh sách tab
  void _showTabs() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.6,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      "Tabs (${_tabs.length})",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Divider(),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _tabs.length,
                      itemBuilder: (context, index) {
                        String tabUrl = _tabs[index];

                        return Dismissible(
                          key: Key(tabUrl),
                          direction: DismissDirection.endToStart,
                          onDismissed: (direction) async {
                            setState(() {
                              _tabs.removeAt(index);
                            });

                            setModalState(
                              () {},
                            ); // Cập nhật lại giao diện modal

                            if (_tabs.isEmpty) {
                              _saveTabsToCache();
                              Navigator.pop(context);
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => BrowserPage(),
                                ),
                              );
                            } else {
                              _currentTabIndex =
                                  (_currentTabIndex >= _tabs.length)
                                      ? _tabs.length - 1
                                      : _currentTabIndex;
                              _initializeWebView(_tabs[_currentTabIndex]);
                            }
                          },
                          background: Container(
                            color: Colors.red,
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Icon(Icons.delete, color: Colors.white),
                          ),
                          child: ListTile(
                            leading: Image.network(
                              _getFaviconUrl(tabUrl),
                              width: 24,
                              height: 24,
                              errorBuilder:
                                  (context, error, stackTrace) =>
                                      Icon(Icons.web),
                            ),
                            title: Text(
                              tabUrl,
                              overflow: TextOverflow.ellipsis,
                            ),
                            onTap: () {
                              setState(() {
                                _currentTabIndex = index;
                              });
                              _initializeWebView(_tabs[_currentTabIndex]);
                              Navigator.pop(context);
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// Lấy favicon của trang web
  String _getFaviconUrl(String url) {
    Uri uri = Uri.parse(url);
    return "https://www.google.com/s2/favicons?domain=${uri.host}&sz=64";
  }

  Future<void> _saveTabsToCache() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('saved_tabs', _tabs);
    print("lưu rồi nè");
  }

  Future<void> _addBookmark() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    WebUri? currentUri = await _webViewController.getUrl();
    String currentUrl = currentUri?.toString() ?? '';

    if (currentUrl.isEmpty) return; // Don't add empty URLs

    List<String> bookmarks = prefs.getStringList('bookmarks') ?? [];

    setState(() {
      if (bookmarks.contains(currentUrl)) {
        bookmarks.remove(currentUrl);
      } else {
        bookmarks.add(currentUrl);
      }
    });

    // Save the updated bookmark list
    await prefs.setStringList('bookmarks', bookmarks);
  }

  Future<bool> _isBookmarked() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> bookmarks = prefs.getStringList('bookmarks') ?? [];
    WebUri? currentUri = await _webViewController.getUrl();
    String currentUrl = currentUri?.toString() ?? '';
    return bookmarks.contains(currentUrl);
  }

  void _loadHistory() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _history = prefs.getStringList('history') ?? [];
      print('history nèee: $_history');
    });
  }

  void _openSettings() {}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: InAppWebView(
                initialUrlRequest: URLRequest(
                  url: WebUri(_processSearchQuery(_tabs[_currentTabIndex])),
                ),
                initialOptions: InAppWebViewGroupOptions(
                  crossPlatform: InAppWebViewOptions(
                    javaScriptEnabled: true,
                    useOnLoadResource: true,
                  ),
                  android: AndroidInAppWebViewOptions(
                    useHybridComposition: true,
                  ),
                ),
                onWebViewCreated: (controller) {
                  _webViewController = controller;
                },
                onLoadStart: (controller, url) {
                  setState(() {
                    _isLoading = true;
                  });
                },
                onLoadStop: (controller, url) {
                  setState(() {
                    _isLoading = false;
                    if (url != null) {
                      _textController.text = url.toString();
                      _addToHistory(url.toString());
                    }
                  });
                },
                onProgressChanged: (controller, progress) {
                  if (progress == 100) {
                    setState(() {
                      _isLoading = false;
                    });
                  }
                },
              ),
            ),
            _buildBottomNavigation(),
          ],
        ),
      ),
    );
  }

  /// Thanh điều hướng WebView với chức năng vuốt để chuyển tab
  Widget _buildBottomNavigation() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[900],
        border: const Border(top: BorderSide(color: Colors.grey, width: 0.5)),
      ),
      child: GestureDetector(
        onHorizontalDragEnd: (details) {
          if (details.primaryVelocity! > 0) {
            // Vuốt phải: lùi tab
            if (_currentTabIndex > 0) {
              _switchTab(_currentTabIndex - 1);
            }
          } else if (details.primaryVelocity! < 0) {
            // Vuốt trái: tiến tab
            if (_currentTabIndex < _tabs.length - 1) {
              _switchTab(_currentTabIndex + 1);
            }
          }
        },
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(4.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(
                          Icons.search,
                          color: Colors.white,
                        ),
                        filled: true,
                        fillColor: Colors.grey[800],
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onSubmitted: (newQuery) {
                        setState(() {
                          _tabs[_currentTabIndex] = _processSearchQuery(
                            newQuery,
                          );
                          _initializeWebView(_tabs[_currentTabIndex]);
                        });
                      },
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.home, color: Colors.white),
                    onPressed: () {
                      _saveTabsToCache();
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const BrowserPage(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8.0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () async {
                      if (await _webViewController.canGoBack()) {
                        _webViewController.goBack();
                      }
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.arrow_forward, color: Colors.white),
                    onPressed: () async {
                      if (await _webViewController.canGoForward()) {
                        _webViewController.goForward();
                      }
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh, color: Colors.white),
                    onPressed: () => _webViewController.reload(),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add, color: Colors.white),
                    onPressed: _addNewTab,
                  ),
                  Stack(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.tab, color: Colors.white),
                        onPressed: _showTabs,
                      ),
                      if (_tabs.length >= 1)
                        Positioned(
                          right: 0,
                          top: 0,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 20,
                              minHeight: 20,
                            ),
                            child: Text(
                              _tabs.length.toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                    ],
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, color: Colors.white),
                    onSelected: (value) async {
                      if (value == 'bookmark') {
                        await _addBookmark();
                        setState(
                          () {},
                        ); // Cập nhật UI sau khi thêm/xóa bookmark
                      } else if (value == 'settings') {
                        _openSettings();
                      }
                    },
                    itemBuilder:
                        (BuildContext context) => <PopupMenuEntry<String>>[
                          PopupMenuItem<String>(
                            value: 'bookmark',
                            child: FutureBuilder<bool>(
                              future: _isBookmarked(),
                              builder: (context, snapshot) {
                                final isBookmarked = snapshot.data ?? false;
                                return Row(
                                  children: [
                                    Icon(
                                      Icons.bookmark,
                                      color:
                                          isBookmarked
                                              ? Colors.yellow
                                              : Colors.grey,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      isBookmarked
                                          ? 'Xóa Bookmark'
                                          : 'Thêm Bookmark',
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                          PopupMenuItem<String>(
                            value: 'settings',
                            child: Row(
                              children: [
                                Icon(Icons.settings, color: Colors.grey),
                                const SizedBox(width: 8),
                                const Text('Cài đặt'),
                              ],
                            ),
                          ),
                        ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
