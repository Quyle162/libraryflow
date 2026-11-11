import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/api.dart';

class Session extends ChangeNotifier {
  Session(this.api, this.preferences, {FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage() {
    api.onUnauthorized = (token) {
      if (api.token == token && !starting) {
        unawaited(signOut().catchError((Object _) {}));
      }
    };
  }

  final Api api;
  final SharedPreferences preferences;
  final FlutterSecureStorage _storage;
  static const _tokenKey = 'libraryflow.token';
  bool starting = true;
  String? startupError;
  Json? user;
  int unread = 0;
  int _epoch = 0;

  bool get librarian => user?['role'] == 'librarian';
  Locale get locale =>
      Locale(preferences.getString('language') == 'en' ? 'en' : 'vi');
  ThemeMode get theme =>
      preferences.getBool('dark') == true ? ThemeMode.dark : ThemeMode.light;

  Future<void> restore() async {
    starting = true;
    startupError = null;
    notifyListeners();
    try {
      api.token = await _storage.read(key: _tokenKey);
      if (api.token != null) user = await api.object('/auth/me');
    } on ApiFailure catch (error) {
      if (error.status == 401) {
        try {
          await _storage.delete(key: _tokenKey);
          api.token = null;
        } catch (_) {
          startupError = 'server_error';
        }
      } else {
        startupError = error.code;
      }
    } catch (_) {
      startupError = 'server_error';
    } finally {
      starting = false;
      notifyListeners();
    }
    unawaited(refreshUnread());
  }

  Future<void> signIn(String login, String password) async {
    final data = await api.send(
      '/auth/login',
      method: 'POST',
      body: {'login': login, 'password': password},
    ) as Json;
    final token = data['token'] as String;
    await _storage.write(key: _tokenKey, value: token);
    _epoch++;
    api.token = token;
    user = data['user'] as Json;
    startupError = null;
    notifyListeners();
    unawaited(refreshUnread());
  }

  Future<void> signOut() async {
    _epoch++;
    api.token = null;
    user = null;
    unread = 0;
    startupError = null;
    notifyListeners();
    await _storage.delete(key: _tokenKey);
  }

  void updateProfile(Json profile) {
    user = profile;
    notifyListeners();
  }

  Future<void> refreshUnread() async {
    if (user == null) return;
    final epoch = _epoch;
    try {
      final data = await api.object('/notifications');
      setUnread(countOf(data['unread']), epoch: epoch);
    } catch (_) {
      // Danh sách thông báo sẽ hiển thị lỗi nếu người dùng mở màn hình đó.
    }
  }

  void setUnread(int value, {int? epoch}) {
    if (user == null || (epoch != null && epoch != _epoch) || unread == value) {
      return;
    }
    unread = value;
    notifyListeners();
  }

  Future<void> changeLanguage(String language) async {
    await preferences.setString('language', language);
    notifyListeners();
  }

  Future<void> changeTheme(bool dark) async {
    await preferences.setBool('dark', dark);
    notifyListeners();
  }
}
