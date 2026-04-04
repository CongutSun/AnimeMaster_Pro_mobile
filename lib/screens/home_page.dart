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

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    
    final cachedCalendar = prefs.getString('cache_calendar');
    final cachedTop = prefs.getString('cache_top');

    if (cachedCalendar != null && cachedTop != null) {
      try {
        final calendar = jsonDecode(cachedCalendar);
        final rawTopData = jsonDecode(cachedTop) as List<dynamic>;
        _parseAndSetData(calendar, rawTopData.map((e) => e as Map<String, dynamic>).toList());
      } catch (e) {
        debugPrint('缓存解析失败: $e');
      }
    } else {
      setState(() => isLoading = true);
    }

    try {
      final results = await Future.wait([
        BangumiApi.getCalendar(),
        BangumiApi.getYearTop(),
      ]);

      final List<dynamic> calendar = results[0];
      final List<Map<String, dynamic>> rawTopData = results[1] as List<Map<String, dynamic>>;

      prefs.setString('cache_calendar', jsonEncode(calendar));
      prefs.setString('cache_top', jsonEncode(rawTopData));

      _parseAndSetData(calendar, rawTopData);
    } catch (e) {
      debugPrint('加载失败: $e');
      if (mounted && todayAnime.isEmpty) setState(() => isLoading = false);
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

  // ✨ 优化：使用统一且简易的 📺 电视图标代表放送，去掉了容易引起误解的日历图标
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