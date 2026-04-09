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
    _loadData();
  }

  /// 数据加载主入口
  /// [forceRefresh] 参数用于区分是否为用户主动触发的下拉刷新操作
  Future<void> _loadData({bool forceRefresh = false}) async {
    final prefs = await SharedPreferences.getInstance();
    
    final cachedCalendar = prefs.getString('cache_calendar');
    final cachedTop = prefs.getString('cache_top');
    final cacheTimeStr = prefs.getString('cache_time');

    bool hasValidCache = false;

    // 1. 缓存校验阶段
    if (cachedCalendar != null && cachedTop != null && cacheTimeStr != null && !forceRefresh) {
      try {
        final cacheTime = DateTime.parse(cacheTimeStr);
        final now = DateTime.now();
        
        // 缓存有效期设定为 4 小时
        if (now.difference(cacheTime).inHours < 4) {
          final calendar = jsonDecode(cachedCalendar);
          final rawTopData = jsonDecode(cachedTop) as List<dynamic>;
          
          _parseAndSetData(calendar, rawTopData.map((e) => e as Map<String, dynamic>).toList());
          hasValidCache = true; 
        }
      } catch (e) {
        debugPrint('[HomePage] Cache parsing or validation failed: $e');
      }
    } 
    
    // 2. 状态分发与网络请求阶段
    if (!hasValidCache) {
      // 场景 A：无有效缓存或用户强制刷新，需展示 Loading 指示器
      setState(() => isLoading = true);
      await _fetchNetworkData(prefs, isSilent: false);
    } else {
      // 场景 B：缓存有效，界面已渲染。发起静默后台刷新，确保数据新鲜度
      _fetchNetworkData(prefs, isSilent: true);
    }
  }

  /// 执行实际的 API 网络请求
  /// [isSilent] 控制发生异常或请求过程中是否干预 UI 加载状态
  Future<void> _fetchNetworkData(SharedPreferences prefs, {bool isSilent = false}) async {
    try {
      final results = await Future.wait([
        BangumiApi.getCalendar(),
        BangumiApi.getYearTop(),
      ]);

      final List<dynamic> calendar = results[0];
      final List<Map<String, dynamic>> rawTopData = results[1] as List<Map<String, dynamic>>;

      if (calendar.isNotEmpty && rawTopData.isNotEmpty) {
        // 数据持久化
        await prefs.setString('cache_calendar', jsonEncode(calendar));
        await prefs.setString('cache_top', jsonEncode(rawTopData));
        await prefs.setString('cache_time', DateTime.now().toIso8601String());
        
        _parseAndSetData(calendar, rawTopData);
      } else if (!isSilent) {
        throw Exception("API returned empty data sequence.");
      }
    } catch (e) {
      debugPrint('[HomePage] Network fetch exception: $e');
      
      // 仅在非静默模式且页面无数据时撤销 Loading 状态
      if (!isSilent && mounted && todayAnime.isEmpty) {
        setState(() => isLoading = false);
      }
    }
  }

  /// 解析服务端数据并更新组件状态
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

  /// 构建整周排期视图
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
              Row(
                children: [
                  const Icon(Icons.live_tv, color: Colors.blueAccent, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    weekdayName, 
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueAccent)
                  ),
                ],
              ),
              const SizedBox(height: 12),
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
                                  Expanded(
                                    child: Row(
                                      children: [
                                        const Icon(Icons.calendar_month, color: Colors.blueAccent),
                                        const SizedBox(width: 8),
                                        Flexible(
                                          child: Text(
                                            showTodayOnly ? '$todayString · 今日排期' : '本周整体排期', 
                                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  TextButton.icon(
                                    onPressed: () => setState(() => showTodayOnly = !showTodayOnly),
                                    icon: Icon(showTodayOnly ? Icons.calendar_view_week : Icons.today, size: 18),
                                    label: Text(showTodayOnly ? '查看全周' : '查看今日'),
                                  )
                                ],
                              ),
                              const SizedBox(height: 16),
                              
                              showTodayOnly 
                                ? AnimeGrid(animeList: todayAnime, isTop: false)
                                : _buildWeekSchedule(),
                              
                              const SizedBox(height: 32),
                              
                              Padding(
                                padding: const EdgeInsets.only(bottom: 16.0),
                                child: Row(
                                  children: [
                                    const Icon(Icons.emoji_events, color: Colors.orange),
                                    const SizedBox(width: 8),
                                    const Text('本年度高分榜单', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                  ],
                                ),
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