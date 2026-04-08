import 'dart:convert';
import 'dart:io'; 
import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; 
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/settings_provider.dart'; 
import '../api/bangumi_api.dart';
import '../models/anime.dart'; 
import '../widgets/top_tool_bar.dart'; 
import '../widgets/anime_grid.dart';   

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const String _cacheCalendarKey = 'cache_calendar';
  static const String _cacheTopKey = 'cache_top';

  List<Anime> todayAnime = [];
  List<Anime> topAnime = [];
  List<dynamic> fullCalendar = []; 
  bool isLoading = true;
  bool showTodayOnly = true;       
  String todayString = '';
  
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (mounted) {
      setState(() {
        isLoading = true;
        errorMessage = null; 
      });
    }

    final prefs = await SharedPreferences.getInstance();
    
    final cachedCalendar = prefs.getString(_cacheCalendarKey);
    final cachedTop = prefs.getString(_cacheTopKey);

    if (cachedCalendar != null && cachedTop != null) {
      try {
        final calendar = jsonDecode(cachedCalendar);
        final rawTopData = jsonDecode(cachedTop) as List<dynamic>;
        _parseAndSetData(calendar, rawTopData.map((e) => e as Map<String, dynamic>).toList());
      } catch (e) {
        debugPrint('缓存解析失败: $e');
      }
    }

    try {
      final results = await Future.wait([
        BangumiApi.getCalendar(),
        BangumiApi.getYearTop(),
      ]);

      final List<dynamic> calendar = results[0];
      final List<Map<String, dynamic>> rawTopData = results[1] as List<Map<String, dynamic>>;

      if (calendar.isNotEmpty && rawTopData.isNotEmpty) {
        prefs.setString(_cacheCalendarKey, jsonEncode(calendar));
        prefs.setString(_cacheTopKey, jsonEncode(rawTopData));
        _parseAndSetData(calendar, rawTopData);
      } else if (todayAnime.isEmpty) {
        throw Exception("API返回了空数据");
      }
    } catch (e) {
      debugPrint('加载失败: $e');
      if (mounted && todayAnime.isEmpty && topAnime.isEmpty) {
        setState(() {
          isLoading = false;
          errorMessage = "数据加载失败，请检查网络后重试";
        });
      } else if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  void _parseAndSetData(List<dynamic> calendar, List<Map<String, dynamic>> rawTopData) {
    final weekday = DateTime.now().weekday;
    final days = ["星期一", "星期二", "星期三", "星期四", "星期五", "星期六", "星期日"];
    todayString = days[weekday - 1];

    List<Anime> parsedToday = [];
    for (var day in calendar) {
      if (day is Map<String, dynamic> && day['weekday'] != null && day['weekday']['id'] == weekday) {
        final items = day['items'] as List<dynamic>? ?? [];
        parsedToday = items.map((e) => Anime.fromJson(e as Map<String, dynamic>)).toList();
        break;
      }
    }

    final parsedTop = rawTopData.map((e) => Anime.fromJson(e)).toList();

    if (mounted) {
      setState(() {
        fullCalendar = calendar; 
        todayAnime = parsedToday;
        topAnime = parsedTop;
        isLoading = false;
        errorMessage = null;
      });
    }
  }

  Widget _buildWeekSchedule() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: fullCalendar.map((day) {
        final weekdayName = day['weekday']['cn'] ?? day['weekday']['en'];
        final items = day['items'] as List<dynamic>? ?? [];
        final dayAnime = items.map((e) => Anime.fromJson(e as Map<String, dynamic>)).toList();
        
        return Padding(
          padding: const EdgeInsets.only(bottom: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('📺 $weekdayName', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue)),
              const SizedBox(height: 8),
              AnimeGrid(animeList: dayAnime, isTop: false),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ✨ 商业化改造：构建错误重试 UI
  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.wifi_off_rounded, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(errorMessage ?? '出错了', style: const TextStyle(color: Colors.grey, fontSize: 16)),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh),
            label: const Text('点击重试'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<SettingsProvider>(context);
    final bgPath = provider.customBgPath;
    final hasBg = bgPath.isNotEmpty && File(bgPath).existsSync();
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: hasBg ? Colors.transparent : null,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: hasBg
            ? BoxDecoration(
                image: DecorationImage(
                  image: FileImage(File(bgPath)),
                  fit: BoxFit.cover,
                  colorFilter: isDarkMode
                      ? ColorFilter.mode(Colors.black.withValues(alpha: 0.5), BlendMode.darken)
                      : ColorFilter.mode(Colors.white.withValues(alpha: 0.5), BlendMode.lighten),
                ),
              )
            : null,
        child: SafeArea(
          child: Column(
            children: [
              const TopToolBar(),
              
              Expanded(
                child: isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : errorMessage != null 
                        ? _buildErrorView() // ✨ 显示优雅的错误页面
                        : RefreshIndicator(
                            onRefresh: _loadData, 
                            child: SingleChildScrollView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        showTodayOnly ? '📺 $todayString · 今日放送' : '📺 本周新番放送', 
                                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)
                                      ),
                                      TextButton.icon(
                                        onPressed: () => setState(() => showTodayOnly = !showTodayOnly),
                                        icon: Icon(showTodayOnly ? Icons.calendar_view_week : Icons.today),
                                        label: Text(showTodayOnly ? '看本周' : '看今日'),
                                      )
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  
                                  showTodayOnly 
                                    ? AnimeGrid(animeList: todayAnime, isTop: false)
                                    : _buildWeekSchedule(),
                                  
                                  const SizedBox(height: 32),
                                  
                                  const Padding(
                                    padding: EdgeInsets.only(bottom: 12.0),
                                    child: Text('🏆 本年度高分榜', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                                  ),
                                  AnimeGrid(animeList: topAnime, isTop: true),
                                  
                                  const SizedBox(height: 40),
                                ],
                              ),
                            ),
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}