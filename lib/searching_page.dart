import 'package:brower_app/browser_page.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SearchingPage extends StatefulWidget {
  final String searchQuery;

  const SearchingPage({super.key, required this.searchQuery});

  @override
  State<SearchingPage> createState() => _SearchingPageState();
}

class _SearchingPageState extends State<SearchingPage> {
  late WebViewController _webViewController;
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
    _tabs.add(_processSearchQuery(widget.searchQuery, _history));
    _loadTabsFromCache();
    _loadBookmarks();

    _initializeWebView(_tabs[_currentTabIndex]);

    _webViewController =
        WebViewController()
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..setUserAgent(
            "Mozilla/5.0 (Linux; Android 10; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/97.0.4692.98 Mobile Safari/537.36",
          )
          ..loadRequest(
            Uri.parse(_processSearchQuery(widget.searchQuery, _history)),
          );
  }

  void _initializeWebView(String url) {
    _webViewController =
        WebViewController()
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..setNavigationDelegate(
            NavigationDelegate(
              onPageStarted: (_) => setState(() => _isLoading = true),
              onPageFinished: (url) {
                setState(() {
                  _isLoading = false;
                  _tabs[_currentTabIndex] = url;
                  _textController.text = url;
                });
              },
            ),
          )
          ..loadRequest(Uri.parse(url));
  }

  /// Xử lý URL hoặc tìm kiếm trên Google
  String _processSearchQuery(String query, List<String> history) {
    history = [];
    print("check history : $history");
    if (query.startsWith('http') || query.contains('.')) {
      history.insert(0, 'https://$query');
      print("check history sau khi thêm  : $history");
      return query.startsWith('http') ? query : 'https://$query';
    } else {
      history.insert(0, 'https://www.google.com/search?q=$query');
      print("check history sau khi thêm  : $history");
      return 'https://www.google.com/search?q=$query';
    }
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

  void _addBookmark() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String currentUrl = _tabs[_currentTabIndex];

    setState(() {
      if (_bookmarkedTabs.contains(currentUrl)) {
        _bookmarkedTabs.remove(currentUrl);
      } else {
        _bookmarkedTabs.add(currentUrl);
      }
    });

    // Lưu danh sách bookmark vào SharedPreferences
    prefs.setStringList('bookmarks', _bookmarkedTabs);
  }

  bool _isBookmarked(String url) {
    return _bookmarkedTabs.contains(url);
  }

  void _loadBookmarks() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _bookmarkedTabs = prefs.getStringList('bookmarks') ?? [];
    });
  }

  void _loadHistory() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _history = prefs.getStringList('history') ?? [];
      print('history nèee: $_history');
    });
  }

  void _savedHistory() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> storedHistory = prefs.getStringList('history') ?? [];

    // Thêm tất cả phần tử của _history vào đầu danh sách
    storedHistory.insertAll(0, _history);

    await prefs.setStringList('history', storedHistory);

    print("đã thêm vào history nèeeee");

    setState(() {
      _history = storedHistory;
    });
  }

  void _openSettings() {}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // WebView hiển thị nội dung
            Expanded(
              child: Stack(
                children: [
                  WebViewWidget(controller: _webViewController),
                  if (_isLoading)
                    const Center(child: CircularProgressIndicator()),
                ],
              ),
            ),
            // Thanh điều hướng WebView
            _buildBottomNavigation(),
          ],
        ),
      ),
    );
  }

  /// Thanh điều hướng WebView với chức năng vuốt để chuyển tab
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
                            _history,
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
                      _savedHistory();
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
                      if (_tabs.length > 1)
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
                    onSelected: (value) {
                      if (value == 'bookmark') {
                        _addBookmark();
                      } else if (value == 'settings') {
                        _openSettings();
                      }
                    },
                    itemBuilder:
                        (BuildContext context) => <PopupMenuEntry<String>>[
                          PopupMenuItem<String>(
                            value: 'bookmark',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.bookmark,
                                  color:
                                      _isBookmarked(_tabs[_currentTabIndex])
                                          ? Colors.yellow
                                          : Colors.grey,
                                ),
                                const SizedBox(width: 8),
                                const Text('Bookmark'),
                              ],
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
