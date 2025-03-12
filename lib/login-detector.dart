import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'credential-manager.dart';

class LoginDetector {
  static const String _detectLoginFormScript = '''
    (function() {
      const forms = document.querySelectorAll('form');
      for (let i = 0; i < forms.length; i++) {
        const form = forms[i];
        const passwordFields = form.querySelectorAll('input[type="password"]');
        const usernameFields = form.querySelectorAll('input[type="text"], input[type="email"]');
        
        if (passwordFields.length > 0 && usernameFields.length > 0) {
          return {
            hasLoginForm: true,
            formIndex: i,
            usernameFieldId: usernameFields[0].id || null,
            usernameFieldName: usernameFields[0].name || null,
            passwordFieldId: passwordFields[0].id || null,
            passwordFieldName: passwordFields[0].name || null
          };
        }
      }
      return { hasLoginForm: false };
    })();
  ''';

  static const String _detectSuccessfulLoginScript = '''
    (function() {
      console.log("Đang kiểm tra đăng nhập thành công...");
      console.log("window.hadLoginFormBefore = " + window.hadLoginFormBefore);
      
      // Check if there are any login forms on the page
      const forms = document.querySelectorAll('form');
      let hasLoginForm = false;
      
      for (let i = 0; i < forms.length; i++) {
        const form = forms[i];
        const passwordFields = form.querySelectorAll('input[type="password"]');
        if (passwordFields.length > 0) {
          hasLoginForm = true;
          break;
        }
      }
      
      console.log("hasLoginForm hiện tại = " + hasLoginForm);
      
      // If there were login forms before but not anymore, likely logged in
      const possibleLoginSuccess = !hasLoginForm && window.hadLoginFormBefore === true;
      console.log("possibleLoginSuccess = " + possibleLoginSuccess);
      
      return { 
        possibleLoginSuccess: possibleLoginSuccess,
        debug: {
          hadLoginFormBefore: window.hadLoginFormBefore,
          hasLoginFormNow: hasLoginForm
        }
      };
    })();
  ''';

  static const String _setLoginFormFlagScript = '''
    window.hadLoginFormBefore = true;
  ''';

  static const String _extractCredentialsScript = '''
    (function() {
      const forms = document.querySelectorAll('form');
      const form = forms[%formIndex%];
      
      if (!form) return { success: false };
      
      let username = '';
      let password = '';
      
      // Try to get by ID first, then by name
      if ('%usernameFieldId%') {
        const usernameField = form.querySelector('#%usernameFieldId%');
        if (usernameField) username = usernameField.value;
      } else if ('%usernameFieldName%') {
        const usernameField = form.querySelector('[name="%usernameFieldName%"]');
        if (usernameField) username = usernameField.value;
      }
      
      if ('%passwordFieldId%') {
        const passwordField = form.querySelector('#%passwordFieldId%');
        if (passwordField) password = passwordField.value;
      } else if ('%passwordFieldName%') {
        const passwordField = form.querySelector('[name="%passwordFieldName%"]');
        if (passwordField) password = passwordField.value;
      }
      
      return {
        success: true,
        username: username,
        password: password
      };
    })();
  ''';

  static const String _fillCredentialsScript = '''
    (function() {
      const forms = document.querySelectorAll('form');
      for (let i = 0; i < forms.length; i++) {
        const form = forms[i];
        const passwordFields = form.querySelectorAll('input[type="password"]');
        const usernameFields = form.querySelectorAll('input[type="text"], input[type="email"]');
        
        if (passwordFields.length > 0 && usernameFields.length > 0) {
          usernameFields[0].value = '%username%';
          passwordFields[0].value = '%password%';
          return { success: true };
        }
      }
      return { success: false };
    })();
  ''';

  // Mới: Script bắt sự kiện submit form để lưu thông tin đăng nhập
  static const String _captureFormSubmissionScript = '''
    (function() {
      const forms = document.querySelectorAll('form');
      for (let i = 0; i < forms.length; i++) {
        const form = forms[i];
        const passwordFields = form.querySelectorAll('input[type="password"]');
        const usernameFields = form.querySelectorAll('input[type="text"], input[type="email"]');
        
        if (passwordFields.length > 0 && usernameFields.length > 0) {
          console.log("Đang thiết lập bắt sự kiện submit cho form " + i);
          
          form.addEventListener('submit', function(e) {
            console.log("Form đang được submit");
            const username = usernameFields[0].value;
            const password = passwordFields[0].value;
            
            // Lưu thông tin đăng nhập vào localStorage
            localStorage.setItem('pendingCredentials', JSON.stringify({
              domain: window.location.hostname,
              username: username,
              password: password,
              timestamp: Date.now()
            }));
            
            console.log("Đã lưu thông tin đăng nhập vào localStorage");
          });
        }
      }
      
      return { success: true };
    })();
  ''';

  // Mới: Script kiểm tra thông tin đăng nhập đang chờ xử lý
  static const String _checkPendingCredentialsScript = '''
    (function() {
      const pendingCredentials = localStorage.getItem('pendingCredentials');
      console.log("Kiểm tra pendingCredentials: " + pendingCredentials);
      
      if (!pendingCredentials) return { hasPendingCredentials: false };
      
      try {
        const credentials = JSON.parse(pendingCredentials);
        const currentDomain = window.location.hostname;
        console.log("Domain hiện tại: " + currentDomain);
        console.log("Domain đã lưu: " + credentials.domain);
        
        // Kiểm tra xem domain hiện tại có khớp với domain đã lưu không
        if (credentials.domain === currentDomain) {
          // Xóa thông tin đăng nhập đã lưu
          localStorage.removeItem('pendingCredentials');
          console.log("Đã xóa pendingCredentials");
          
          return {
            hasPendingCredentials: true,
            username: credentials.username,
            password: credentials.password
          };
        }
      } catch (e) {
        console.error("Lỗi khi xử lý pendingCredentials: " + e);
        localStorage.removeItem('pendingCredentials');
      }
      
      return { hasPendingCredentials: false };
    })();
  ''';

  // Mới: Script phát hiện đăng nhập thành công dựa trên URL
  static const String _detectLoginSuccessByUrlScript = '''
    (function() {
      const url = window.location.href;
      const successKeywords = ["account", "dashboard", "profile", "my-account", "user", "member", "logged-in"];
      const urlSuccess = successKeywords.some(keyword => url.toLowerCase().includes(keyword));
      
      // Kiểm tra có phần tử nào chỉ xuất hiện sau khi đăng nhập không
      const successElements = document.querySelectorAll(".logged-in, .account-info, .user-profile, .account-name, .user-name, .profile-link");
      const elementSuccess = successElements.length > 0;
      
      console.log("URL success: " + urlSuccess);
      console.log("Element success: " + elementSuccess);
      
      return {
        urlSuccess: urlSuccess,
        elementSuccess: elementSuccess,
        possibleLoginSuccess: urlSuccess || elementSuccess
      };
    })();
  ''';

  // Detect login forms on the page
  static Future<Map<String, dynamic>> detectLoginForm(
    InAppWebViewController controller,
  ) async {
    print("Đang chạy script phát hiện form đăng nhập...");
    final result = await controller.evaluateJavascript(
      source: _detectLoginFormScript,
    );
    print("Kết quả phát hiện form đăng nhập: $result");
    return result;
  }

  // Mark that this page had a login form
  static Future<void> markLoginFormPresent(
    InAppWebViewController controller,
  ) async {
    print("Đánh dấu trang có form đăng nhập");
    await controller.evaluateJavascript(source: _setLoginFormFlagScript);
  }

  // Detect if login was successful
  static Future<bool> detectSuccessfulLogin(
    InAppWebViewController controller,
  ) async {
    print("Đang chạy script phát hiện đăng nhập thành công...");
    final result = await controller.evaluateJavascript(
      source: _detectSuccessfulLoginScript,
    );
    print("Kết quả script phát hiện đăng nhập thành công: $result");
    return result['possibleLoginSuccess'] == true;
  }

  // Mới: Phát hiện đăng nhập thành công dựa trên URL
  static Future<bool> detectLoginSuccessByUrl(
    InAppWebViewController controller,
  ) async {
    print("Đang chạy script phát hiện đăng nhập thành công dựa trên URL...");
    final result = await controller.evaluateJavascript(
      source: _detectLoginSuccessByUrlScript,
    );
    print("Kết quả phát hiện đăng nhập thành công dựa trên URL: $result");
    return result['possibleLoginSuccess'] == true;
  }

  // Extract credentials from a form
  static Future<Map<String, dynamic>> extractCredentials(
    InAppWebViewController controller,
    int formIndex,
    String? usernameFieldId,
    String? usernameFieldName,
    String? passwordFieldId,
    String? passwordFieldName,
  ) async {
    print("Đang chạy script trích xuất thông tin đăng nhập với:");
    print("- formIndex: $formIndex");
    print("- usernameFieldId: $usernameFieldId");
    print("- usernameFieldName: $usernameFieldName");
    print("- passwordFieldId: $passwordFieldId");
    print("- passwordFieldName: $passwordFieldName");

    String script = _extractCredentialsScript
        .replaceAll('%formIndex%', formIndex.toString())
        .replaceAll('%usernameFieldId%', usernameFieldId ?? '')
        .replaceAll('%usernameFieldName%', usernameFieldName ?? '')
        .replaceAll('%passwordFieldId%', passwordFieldId ?? '')
        .replaceAll('%passwordFieldName%', passwordFieldName ?? '');

    final result = await controller.evaluateJavascript(source: script);
    print("Kết quả trích xuất thông tin đăng nhập: $result");
    return result;
  }

  // Fill credentials into a form
  static Future<bool> fillCredentials(
    InAppWebViewController controller,
    String username,
    String password,
  ) async {
    print("Đang điền thông tin đăng nhập: $username / $password");
    String script = _fillCredentialsScript
        .replaceAll('%username%', username)
        .replaceAll('%password%', password);

    final result = await controller.evaluateJavascript(source: script);
    print("Kết quả điền thông tin đăng nhập: $result");
    return result['success'] == true;
  }

  // Mới: Bắt sự kiện submit form để lưu thông tin đăng nhập
  static Future<void> captureFormSubmission(
    InAppWebViewController controller,
  ) async {
    print("Đang thiết lập bắt sự kiện submit form...");
    await controller.evaluateJavascript(source: _captureFormSubmissionScript);
  }

  // Mới: Kiểm tra thông tin đăng nhập đang chờ xử lý
  static Future<Map<String, dynamic>> checkPendingCredentials(
    InAppWebViewController controller,
  ) async {
    print("Đang kiểm tra thông tin đăng nhập đang chờ xử lý...");
    final result = await controller.evaluateJavascript(
      source: _checkPendingCredentialsScript,
    );
    print("Kết quả kiểm tra thông tin đăng nhập đang chờ xử lý: $result");
    return result;
  }
}
