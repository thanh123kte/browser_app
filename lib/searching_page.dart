import 'package:brower_app/browser_page.dart';
import 'package:brower_app/setting_page.dart';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:shared_preferences/shared_preferences.dart';
import "credential-manager.dart";
import "login-detector.dart";
import "browser_page.dart";

class SearchingPage extends StatefulWidget {
  final String searchQuery;

  const SearchingPage({super.key, required this.searchQuery});

  @override
  State<SearchingPage> createState() => _SearchingPageState();
}

class _SearchingPageState extends State<SearchingPage> {
  late InAppWebViewController _webViewController;
  late TextEditingController _textController;
  late PullToRefreshController _pullToRefreshController;
  bool _isLoading2 = false;
  bool _isLoading = true; // Trạng thái loading
  List<String> _tabs = []; // Danh sách tab
  final List<String> _bookmarkedTabs = [];
  int _currentTabIndex = 0; // Tab đang mở
  List<String> _history = [];

  bool _isAdBlockEnabled = false;
  bool _isSecurityEnabled = false;

  bool _hasLoginForm = false;
  int? _loginFormIndex;
  String? _usernameFieldId;
  String? _usernameFieldName;
  String? _passwordFieldId;
  String? _passwordFieldName;
  bool _credentialsAvailable = false;
  String _currentDomain = "";

  @override
  void initState() {
    super.initState();
    _loadHistory();
    _textController = TextEditingController(text: widget.searchQuery);
    _tabs.add(_processSearchQuery(widget.searchQuery));
    _loadTabsFromCache();
    _pullToRefreshController = PullToRefreshController(
      options: PullToRefreshOptions(color: Colors.blue),
      onRefresh: () async {
        _webViewController.reload();
      },
    );
  }

  void _initializeWebView(String url) {
    _webViewController?.loadUrl(urlRequest: URLRequest(url: WebUri(url)));
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
    print("ddax add : $newEntry");
  }

  Future<void> _loadTabsFromCache() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String>? savedTabs = prefs.getStringList('saved_tabs');

    if (savedTabs != null && savedTabs.isNotEmpty) {
      setState(() {
        _tabs = savedTabs;

        // Kiểm tra nếu currentTabIndex đã được lưu trước đó
        int? savedIndex = prefs.getInt('current_tab_index');
        if (savedIndex != null &&
            savedIndex >= 0 &&
            savedIndex < _tabs.length) {
          _currentTabIndex = savedIndex;
        } else {
          _currentTabIndex = _tabs.length - 1; // Mặc định chọn tab cuối cùng
        }
      });
    }
  }

  /// Mở tab mới
  void _addNewTab() {
    setState(() {
      _tabs.add('https://www.google.com'); // Mở tab với Google mặc định
      _currentTabIndex = _tabs.length - 1;
      _initializeWebView(
        _tabs[_currentTabIndex],
      ); // Khởi tạo WebView cho tab mới
    });
    _saveTabsToCache(); // 🔥 Lưu vào cache ngay sau khi tạo tab
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
            return SizedBox(
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
    await prefs.setInt('saved_tab_index', _currentTabIndex);
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

  void _openSettings(
    BuildContext context,
    bool currentAdBlock,
    bool currentSecurity,
    Function(bool, bool) onSettingsChanged,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => SettingPage(
              onSettingsChanged: onSettingsChanged,
              initialAdBlock: currentAdBlock,
              initialSecurity: currentSecurity,
            ),
      ),
    );
  }

  Future<void> _checkForLoginForms() async {
    WebUri? currentUri = await _webViewController.getUrl();
    if (currentUri == null) return;

    String currentUrl = currentUri.toString();
    _currentDomain = CredentialManager.extractDomain(currentUrl);
    print("===== TRANG WEB ĐÃ TẢI XONG =====");
    print("URL: $currentUrl");
    print("Domain: $_currentDomain");

    // Danh sách từ khóa liên quan đến trang đăng nhập
    List<String> loginKeywords = [
      "login",
      "signin",
      "auth",
      "account/login",
      "user/login",
      "session/new",
    ];

    // Kiểm tra URL có chứa từ khóa liên quan đến đăng nhập không
    bool isLoginPage = loginKeywords.any(
      (keyword) => currentUrl.toLowerCase().contains(keyword),
    );

    if (isLoginPage) {
      print("Trang này có thể là trang đăng nhập.");

      // Kiểm tra xem có thông tin đăng nhập đã lưu không
      final savedCredentials = await CredentialManager.getCredentials(
        _currentDomain,
      );
      setState(() {
        _credentialsAvailable = savedCredentials != null;
      });
      print("Có thông tin đăng nhập đã lưu: $_credentialsAvailable");

      // Nếu có mật khẩu đã lưu, hiển thị gợi ý tự động điền
      if (_credentialsAvailable) {
        _showAutofillPrompt();
      }
    } else {
      print(
        "Trang này không phải là trang đăng nhập, bỏ qua kiểm tra tự động điền.",
      );
    }

    // Phát hiện form đăng nhập
    final loginFormData = await LoginDetector.detectLoginForm(
      _webViewController,
    );
    print("===== PHÁT HIỆN FORM ĐĂNG NHẬP =====");
    print("loginFormData: $loginFormData");

    if (loginFormData['hasLoginForm'] == true) {
      setState(() {
        _hasLoginForm = true;
        _loginFormIndex = loginFormData['formIndex'];
        _usernameFieldId = loginFormData['usernameFieldId'];
        _usernameFieldName = loginFormData['usernameFieldName'];
        _passwordFieldId = loginFormData['passwordFieldId'];
        _passwordFieldName = loginFormData['passwordFieldName'];
      });

      print("Đã phát hiện form đăng nhập:");
      print("- Form index: $_loginFormIndex");
      print("- Username field ID: $_usernameFieldId");
      print("- Username field name: $_usernameFieldName");
      print("- Password field ID: $_passwordFieldId");
      print("- Password field name: $_passwordFieldName");

      await LoginDetector.markLoginFormPresent(_webViewController);
      await LoginDetector.captureFormSubmission(_webViewController);
    } else {
      setState(() {
        _hasLoginForm = false;
      });
      print("Không phát hiện form đăng nhập trên trang này");

      final loginSuccessByUrl = await LoginDetector.detectLoginSuccessByUrl(
        _webViewController,
      );
      if (loginSuccessByUrl) {
        print("Phát hiện đăng nhập thành công dựa trên URL!");
      }
    }

    final pendingCredentials = await LoginDetector.checkPendingCredentials(
      _webViewController,
    );
    if (pendingCredentials['hasPendingCredentials'] == true) {
      print("Tìm thấy thông tin đăng nhập đang chờ xử lý!");
      _showSaveCredentialsPrompt(
        pendingCredentials['username'],
        pendingCredentials['password'],
      );
    }
  }

  Future<void> _checkLoginSuccess() async {
    if (!_hasLoginForm) {
      print("Không kiểm tra đăng nhập thành công vì không có form đăng nhập");
      return;
    }

    print("===== KIỂM TRA ĐĂNG NHẬP THÀNH CÔNG =====");
    print("Đang kiểm tra đăng nhập thành công...");

    final loginSuccess = await LoginDetector.detectSuccessfulLogin(
      _webViewController,
    );
    final loginSuccessByUrl = await LoginDetector.detectLoginSuccessByUrl(
      _webViewController,
    );

    print("Kết quả kiểm tra đăng nhập thành công: $loginSuccess");
    print(
      "Kết quả kiểm tra đăng nhập thành công dựa trên URL: $loginSuccessByUrl",
    );

    if (loginSuccess || loginSuccessByUrl) {
      print("Đã phát hiện đăng nhập thành công!");

      // Lấy URL hiện tại sau khi đăng nhập
      WebUri? currentUri = await _webViewController.getUrl();
      if (currentUri == null) return;
      String currentUrl = currentUri.toString();
      String currentDomain = CredentialManager.extractDomain(currentUrl);

      print("URL sau khi đăng nhập: $currentUrl");
      print("Domain sau khi đăng nhập: $currentDomain");

      // Kiểm tra xem đã có thông tin đăng nhập cho domain này chưa
      final savedCredentials = await CredentialManager.getCredentials(
        currentDomain,
      );
      if (savedCredentials != null) {
        print(
          "Đã có thông tin đăng nhập được lưu, không hiển thị thông báo lưu mật khẩu.",
        );
        return;
      }

      // Nếu chưa có, trích xuất thông tin đăng nhập
      print("Đang trích xuất thông tin đăng nhập...");
      final credentials = await LoginDetector.extractCredentials(
        _webViewController,
        _loginFormIndex!,
        _usernameFieldId,
        _usernameFieldName,
        _passwordFieldId,
        _passwordFieldName,
      );

      print("Kết quả trích xuất thông tin đăng nhập: $credentials");

      if (credentials['success'] == true &&
          credentials['username'] != null &&
          credentials['username'].isNotEmpty &&
          credentials['password'] != null &&
          credentials['password'].isNotEmpty) {
        print("Thông tin đăng nhập hợp lệ:");
        print("- Username: ${credentials['username']}");
        print("- Password: ${credentials['password']}");

        // Hiển thị thông báo lưu mật khẩu nếu chưa có thông tin lưu trước đó
        print("Hiển thị thông báo lưu mật khẩu");
        _showSaveCredentialsPrompt(
          credentials['username'],
          credentials['password'],
        );
      } else {
        print("Không thể trích xuất thông tin đăng nhập hợp lệ");
      }

      // Reset trạng thái form đăng nhập
      setState(() {
        _hasLoginForm = false;
      });
    } else {
      print("Chưa phát hiện đăng nhập thành công");
    }
  }

  void _showManualSavePasswordDialog() {
    final usernameController = TextEditingController();
    final passwordController = TextEditingController();

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Lưu mật khẩu'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Nhập thông tin đăng nhập cho $_currentDomain'),
                TextField(
                  controller: usernameController,
                  decoration: InputDecoration(labelText: 'Tên đăng nhập'),
                ),
                TextField(
                  controller: passwordController,
                  decoration: InputDecoration(labelText: 'Mật khẩu'),
                  obscureText: true,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text('Hủy'),
              ),
              TextButton(
                onPressed: () async {
                  if (usernameController.text.isNotEmpty &&
                      passwordController.text.isNotEmpty) {
                    await CredentialManager.saveCredentials(
                      _currentDomain,
                      usernameController.text,
                      passwordController.text,
                    );
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Đã lưu mật khẩu'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }
                },
                child: const Text('Lưu'),
              ),
            ],
          ),
    );
  }

  void _showAutofillPrompt() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Saved Login'),
            content: Text(
              'Do you want to use your saved login for $_currentDomain?',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text('Not Now'),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.of(context).pop();
                  final credentials = await CredentialManager.getCredentials(
                    _currentDomain,
                  );
                  if (credentials != null) {
                    await LoginDetector.fillCredentials(
                      _webViewController,
                      credentials['username']!,
                      credentials['password']!,
                    );
                  }
                },
                child: const Text('Yes'),
              ),
            ],
          ),
    );
  }

  void _showSaveCredentialsPrompt(String username, String password) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Save Password'),
            content: Text(
              'Do you want to save your password for $_currentDomain?',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text('No'),
              ),
              TextButton(
                onPressed: () async {
                  await CredentialManager.saveCredentials(
                    _currentDomain,
                    username,
                    password,
                  );
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Password saved'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
                child: const Text('Yes'),
              ),
            ],
          ),
    );
  }

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
                pullToRefreshController:
                    _pullToRefreshController, // Thêm controller này
                onWebViewCreated: (controller) {
                  _webViewController = controller;
                },
                onLoadStart: (controller, url) {
                  setState(() {
                    _isLoading2 = true;
                    print("currrentabindex : ${_currentTabIndex}");
                    _tabs[_currentTabIndex] = url.toString();
                  });
                  print("Bắt đầu tải trang: ${url?.toString()}");
                },
                onLoadStop: (controller, url) async {
                  setState(() {
                    _isLoading = false;
                    if (url != null) {
                      setState(() {
                        _textController.text = url.toString();
                        _addToHistory(url.toString());
                      });
                    }
                    _saveTabsToCache();
                  });
                  // Dừng hiệu ứng kéo để làm mới
                  _pullToRefreshController.endRefreshing();

                  // Kiểm tra form đăng nhập
                  await _checkForLoginForms();
                },
                onProgressChanged: (controller, progress) {
                  print("Tiến trình tải trang: $progress%");
                  if (progress == 100) {
                    setState(() {
                      _isLoading = false;
                    });

                    print(
                      "Trang đã tải 100%, kiểm tra đăng nhập thành công...",
                    );
                    // Kiểm tra xem đăng nhập có thành công không
                    _checkLoginSuccess();
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
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, color: Colors.white),
                    onSelected: (value) async {
                      if (value == 'bookmark') {
                        await _addBookmark();
                        setState(() {});
                      } else if (value == 'settings') {
                        _openSettings(
                          context,
                          _isAdBlockEnabled,
                          _isSecurityEnabled,
                          (bool adBlock, bool security) {
                            setState(() {
                              _isAdBlockEnabled = adBlock;
                              _isSecurityEnabled = security;
                            });
                            if (_isAdBlockEnabled) {
                              _applyAdBlock();
                            } else {
                              _removeAdBlock();
                            }

                            if (_isSecurityEnabled) {
                              _applySecurity();
                            } else {
                              _removeSecurity();
                            }
                          },
                        );
                      } else if (value == "passwords") {
                        _showSavedPasswords();
                      } else if (value == 'save_password') {
                        _showManualSavePasswordDialog();
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
                            value: 'save_password',
                            child: Row(
                              children: [
                                Icon(Icons.save, color: Colors.grey),
                                const SizedBox(width: 8),
                                const Text('Lưu mật khẩu trang này'),
                              ],
                            ),
                          ),
                          PopupMenuItem<String>(
                            value: 'passwords',
                            child: Row(
                              children: [
                                Icon(Icons.password, color: Colors.grey),
                                const SizedBox(width: 8),
                                const Text('Saved Passwords'),
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

  void _showSavedPasswords() async {
    final savedCredentials = await CredentialManager.getAllCredentials();

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Saved Passwords'),
            content: SizedBox(
              width: double.maxFinite,
              child:
                  savedCredentials.isEmpty
                      ? const Center(child: Text('No saved passwords'))
                      : ListView.builder(
                        shrinkWrap: true,
                        itemCount: savedCredentials.length,
                        itemBuilder: (context, index) {
                          final credential = savedCredentials[index];
                          return ListTile(
                            leading: Image.network(
                              'https://www.google.com/s2/favicons?domain=${credential['domain']}&sz=64',
                              width: 24,
                              height: 24,
                              errorBuilder:
                                  (context, error, stackTrace) =>
                                      const Icon(Icons.web),
                            ),
                            title: Text(credential['domain']),
                            subtitle: Text(credential['username']),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () async {
                                await CredentialManager.deleteCredentials(
                                  credential["domain"],
                                );
                                Navigator.pop(context);
                                Future.delayed(
                                  const Duration(milliseconds: 300),
                                  _showSavedPasswords,
                                );
                              },
                            ),
                          );
                        },
                      ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
    );
  }

  bool isAdBlockEnabled() {
    return _isAdBlockEnabled;
  }

  bool isSecurityEnabled() {
    return _isSecurityEnabled;
  }

  void _applyAdBlock() {
    print("Chặn quảng cáo đang hoạt động");
    // Thêm logic xử lý chặn quảng cáo tại đây
  }

  void _removeAdBlock() {
    print("Chặn quảng cáo đã tắt");
    // Thêm logic xử lý tắt chặn quảng cáo tại đây
  }

  // Hàm xử lý khi Security được bật/tắt
  void _applySecurity() {
    print("Bảo mật đang hoạt động");
    // Thêm logic xử lý bảo mật tại đây
  }

  void _removeSecurity() {
    print("Bảo mật đã tắt");
    // Thêm logic xử lý tắt bảo mật tại đây
  }
}
