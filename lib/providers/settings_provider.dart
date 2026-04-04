import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider with ChangeNotifier {
  String _bgmAcc = '';
  String _bgmToken = '';
  List<Map<String, String>> _rssSources = [];
  bool _isLoaded = false; 

  // ✨ 新增界面外观属性
  String _closeAction = '直接完全退出';
  String _themeMode = '明亮模式 (Light)';
  String _customBgPath = '';

  String get bgmAcc => _bgmAcc;
  String get bgmToken => _bgmToken;
  List<Map<String, String>> get rssSources => _rssSources;
  bool get isLoaded => _isLoaded;

  String get closeAction => _closeAction;
  String get themeMode => _themeMode;
  String get customBgPath => _customBgPath;

  SettingsProvider() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _bgmAcc = prefs.getString('bgm_acc') ?? '';
    _bgmToken = prefs.getString('bgm_token') ?? '';

    // ✨ 加载外观设置
    _closeAction = prefs.getString('close_action') ?? '直接完全退出';
    _themeMode = prefs.getString('theme_mode') ?? '明亮模式 (Light)';
    _customBgPath = prefs.getString('custom_bg_path') ?? '';

    final rssString = prefs.getString('rss_sources');
    if (rssString != null) {
      List<dynamic> decoded = jsonDecode(rssString);
      _rssSources = decoded.map((e) => Map<String, String>.from(e)).toList();
    } else {
      _rssSources = [
        {'name': '动漫花园 (dmhy)', 'url': 'https://share.dmhy.org/topics/rss/rss.xml?keyword={keyword}'},
        {'name': '蜜柑计划 (Mikan)', 'url': 'https://mikanani.me/RSS/Search?searchstr={keyword}'},
      ];
    }
    
    _isLoaded = true;
    notifyListeners(); 
  }

  Future<void> updateAccount(String acc, String token) async {
    _bgmAcc = acc;
    _bgmToken = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('bgm_acc', acc);
    await prefs.setString('bgm_token', token);
    notifyListeners();
  }

  // ✨ 新增：更新外观设置并保存
  Future<void> updateAppearance(String action, String mode, String bgPath) async {
    _closeAction = action;
    _themeMode = mode;
    _customBgPath = bgPath;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('close_action', action);
    await prefs.setString('theme_mode', mode);
    await prefs.setString('custom_bg_path', bgPath);
    notifyListeners();
  }

  Future<void> addRssSource(String name, String url) async {
    _rssSources.add({'name': name, 'url': url});
    await _saveRssToPrefs();
    notifyListeners();
  }

  Future<void> removeRssSource(int index) async {
    if (index >= 0 && index < _rssSources.length) {
      _rssSources.removeAt(index);
      await _saveRssToPrefs();
      notifyListeners();
    }
  }

  Future<void> _saveRssToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('rss_sources', jsonEncode(_rssSources));
  }
}