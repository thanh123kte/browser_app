import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'dart:convert';

class CredentialManager {
  static Database? _database;

  // Khóa mã hóa (Nên lưu trữ an toàn hơn trong ứng dụng thực tế)
  static final _encryptionKey = encrypt.Key.fromUtf8(
    'thanhdaodeptraiquatroiquadat1234',
  );
  static final _iv = encrypt.IV.fromUtf8('thanhdaodeptrai');

  // Khởi tạo database
  static Future<Database> get database async {
    if (_database != null) return _database!;

    _database = await _initDatabase();
    return _database!;
  }

  static Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'credentials.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: (Database db, int version) async {
        await db.execute(
          'CREATE TABLE credentials('
          'id INTEGER PRIMARY KEY AUTOINCREMENT, '
          'domain TEXT, '
          'username TEXT, '
          'password TEXT, '
          'last_used TIMESTAMP)',
        );
      },
    );
  }

  // Mã hóa mật khẩu
  static String _encryptPassword(String password) {
    final encrypter = encrypt.Encrypter(encrypt.AES(_encryptionKey));
    final encrypted = encrypter.encrypt(password, iv: _iv);
    return encrypted.base64;
  }

  // Giải mã mật khẩu
  static String _decryptPassword(String encryptedPassword) {
    try {
      final encrypter = encrypt.Encrypter(encrypt.AES(_encryptionKey));
      final decrypted = encrypter.decrypt64(encryptedPassword, iv: _iv);
      return decrypted;
    } catch (e) {
      print("❌ Lỗi khi giải mã mật khẩu: $e");
      return encryptedPassword; // Trả về mật khẩu đã mã hóa nếu lỗi
    }
  }

  // ✅ Lưu mật khẩu (kiểm tra cả domain và username)
  static Future<void> saveCredentials(
    String domain,
    String username,
    String password,
  ) async {
    final db = await database;

    final List<Map<String, dynamic>> existingCredentials = await db.query(
      'credentials',
      where: 'domain = ? AND username = ?',
      whereArgs: [domain, username],
    );

    if (existingCredentials.isNotEmpty) {
      // Nếu tồn tại, cập nhật mật khẩu và timestamp
      await db.update(
        'credentials',
        {
          'password': _encryptPassword(password),
          'last_used': DateTime.now().toIso8601String(),
        },
        where: 'domain = ? AND username = ?',
        whereArgs: [domain, username],
      );
      print("🔄 Cập nhật mật khẩu cho $domain ($username)");
    } else {
      // Nếu chưa có, thêm mới
      await db.insert('credentials', {
        'domain': domain,
        'username': username,
        'password': _encryptPassword(password),
        'last_used': DateTime.now().toIso8601String(),
      });
      print("✅ Thêm tài khoản mới: $domain ($username)");
    }
  }

  // ✅ Lấy mật khẩu đã lưu (debug để kiểm tra lỗi)
  static Future<Map<String, String>?> getCredentials(String domain) async {
    final db = await database;

    final List<Map<String, dynamic>> credentials = await db.query(
      'credentials',
      where: 'domain = ?',
      whereArgs: [domain],
    );

    if (credentials.isEmpty) {
      print("🔴 Không tìm thấy dữ liệu cho domain: $domain");
      return null;
    }

    print("✅ Tìm thấy credentials: ${credentials.first}");

    // Cập nhật thời gian sử dụng
    await db.update(
      'credentials',
      {'last_used': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [credentials.first['id']],
    );

    return {
      'username': credentials.first['username'],
      'password': _decryptPassword(credentials.first['password']),
    };
  }

  // ✅ Xóa thông tin đăng nhập theo domain
  static Future<void> deleteCredentials(String domain) async {
    final db = await database;
    await db.delete('credentials', where: 'domain = ?', whereArgs: [domain]);
    print("🗑 Xóa tài khoản cho domain: $domain");
  }

  // ✅ Lấy tất cả tài khoản đã lưu
  static Future<List<Map<String, dynamic>>> getAllCredentials() async {
    final db = await database;
    final data = await db.query(
      'credentials',
      columns: ['domain', 'username', 'last_used'],
      orderBy: 'last_used DESC',
    );
    print("📌 Danh sách tất cả tài khoản đã lưu: $data");
    return data;
  }

  // ✅ Trích xuất domain từ URL
  static String extractDomain(String url) {
    Uri uri = Uri.parse(url);
    return uri.host;
  }
}
