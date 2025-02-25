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
  int _currentTabIndex = 0; // Tab đang mở

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.searchQuery);
    _tabs.add(_processSearchQuery(widget.searchQuery));
    _loadTabsFromCache();

    _initializeWebView(_tabs[_currentTabIndex]);

    _webViewController =
        WebViewController()
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..setUserAgent(
            "Mozilla/5.0 (Linux; Android 10; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/97.0.4692.98 Mobile Safari/537.36",
          )
          ..loadRequest(Uri.parse(_processSearchQuery(widget.searchQuery)));
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
  String _processSearchQuery(String query) {
    if (query.startsWith('http') || query.contains('.')) {
      return query.startsWith('http') ? query : 'https://$query';
    } else {
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
    setState(() {
      _currentTabIndex = index;
      _initializeWebView(_tabs[index]);
    });
    Navigator.pop(context);
  }

  /// Hiển thị danh sách tab
  void _showTabs() {
    showModalBottomSheet(
      context: context,
      builder:
          (context) => Container(
            height: MediaQuery.of(context).size.height * 0.6,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    "Tabs (${_tabs.length})",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                          if (_tabs.isEmpty) {
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
                                (context, error, stackTrace) => Icon(Icons.web),
                          ),
                          title: Text(tabUrl, overflow: TextOverflow.ellipsis),
                          onTap: () {
                            _switchTab(index);
                            Navigator.pop(context);
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
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

  /// Thanh điều hướng WebView
  Widget _buildBottomNavigation() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[900],
        border: const Border(top: BorderSide(color: Colors.grey, width: 0.5)),
      ),
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
                      prefixIcon: const Icon(Icons.search, color: Colors.white),
                      filled: true,
                      fillColor: Colors.grey[800],
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 8, // 🔥 Giảm chiều cao
                        horizontal: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          16,
                        ), // 🔥 Làm bo góc nhỏ hơn
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onSubmitted: (newQuery) {
                      setState(() {
                        _tabs[_currentTabIndex] = _processSearchQuery(newQuery);
                        _initializeWebView(_tabs[_currentTabIndex]);
                      });
                    },
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.home, color: Colors.white),
                  onPressed: () {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const BrowserPage(),
                      ),
                      (route) => false,
                    );
                    setState(() {});
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
                    if (_tabs.length >
                        1) // Chỉ hiển thị số tab nếu có hơn 1 tab
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
              ],
            ),
          ),
        ],
      ),
    );
  }
}
