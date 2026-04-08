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
  List<Anime> todayAnime = [];
  List<Anime> topAnime = [];
  List<dynamic> fullCalendar = []; 
  bool isLoading = true;
  bool showTodayOnly = true;       
  String todayString = '';

  @override
  void initState() {
    super.initState();
    // 默认正常加载
    _loadData();
  }

  // ✨ 核心升级：增加 forceRefresh 参数，用于判断是否是用户手动下拉刷新
  Future<void> _loadData({bool forceRefresh = false}) async {
    final prefs = await SharedPreferences.getInstance();
    
    final cachedCalendar = prefs.getString('cache_calendar');
    final cachedTop = prefs.getString('cache_top');
    // ✨ 读取上次缓存的时间
    final cacheTimeStr = prefs.getString('cache_time');

    bool hasValidCache = false;

    // 1. 如果有缓存，并且不是用户手动强制刷新，我们来检查缓存是否过期
    if (cachedCalendar != null && cachedTop != null && cacheTimeStr != null && !forceRefresh) {
      try {
        final cacheTime = DateTime.parse(cacheTimeStr);
        final now = DateTime.now();
        
        // ✨ 商业化策略：缓存 4 小时内有效。你可以根据需要调整这个时间
        if (now.difference(cacheTime).inHours < 4) {
          final calendar = jsonDecode(cachedCalendar);
          final rawTopData = jsonDecode(cachedTop) as List<dynamic>;
          
          _parseAndSetData(calendar, rawTopData.map((e) => e as Map<String, dynamic>).toList());
          hasValidCache = true; // 标记缓存有效
        }
      } catch (e) {
        debugPrint('缓存解析或时间校验失败: $e');
      }
    } 
    
    // 如果没有有效缓存，才需要显示转圈 Loading
    if (!hasValidCache) {
      setState(() => isLoading = true);
    } else {
      // ✨ 如果缓存有效，直接 Return 终止函数！绝不偷偷发起多余的网络请求，界面绝对不会闪烁！
      return;
    }

    // 2. 只有在【无缓存】、【缓存过期】或【用户手动下拉】时，才走网络请求
    try {
      final results = await Future.wait([
        BangumiApi.getCalendar(),
        BangumiApi.getYearTop(),
      ]);

      final List<dynamic> calendar = results[0];
      final List<Map<String, dynamic>> rawTopData = results[1] as List<Map<String, dynamic>>;

      // 只有接口真的返回了数据，才写入缓存并记录当前时间
      if (calendar.isNotEmpty && rawTopData.isNotEmpty) {
        prefs.setString('cache_calendar', jsonEncode(calendar));
        prefs.setString('cache_top', jsonEncode(rawTopData));
        prefs.setString('cache_time', DateTime.now().toIso8601String()); // ✨ 记录最新拉取时间
        
        _parseAndSetData(calendar, rawTopData);
      } else {
        throw Exception("API返回了空数据");
      }
      
    } catch (e) {
      debugPrint('加载失败: $e');
      // 如果失败且屏幕上毫无数据，才关闭 Loading 状态（这里通常可以加一个 Toast 提示网络错误）
      if (mounted && todayAnime.isEmpty) {
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
                    : RefreshIndicator(
                        // ✨ 核心配合：当用户手动下拉刷新时，传入 forceRefresh: true，强制走网络
                        onRefresh: () => _loadData(forceRefresh: true), 
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