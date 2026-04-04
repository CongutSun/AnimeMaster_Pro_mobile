import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/settings_provider.dart';
import 'screens/home_page.dart';

void main() async {
  // 确保 Flutter 底层组件初始化完毕（读取本地缓存、配置等必须加这行）
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    // 在应用最外层注入全局设置状态，这样所有页面都能读取到
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // 使用 Consumer 监听设置页面的变化
    return Consumer<SettingsProvider>(
      builder: (context, settings, child) {
        // 判断用户在设置里选的是不是暗黑模式
        final isDarkMode = settings.themeMode.contains('Dark');

        return MaterialApp(
          title: '智能追番助手',
          debugShowCheckedModeBanner: false, // 隐藏右上角难看的 DEBUG 红色标签
          
          // 自动跟随设置里的明暗主题
          themeMode: isDarkMode ? ThemeMode.dark : ThemeMode.light,
          
          // ☀️ 明亮模式默认配色
          theme: ThemeData(
            brightness: Brightness.light,
            primarySwatch: Colors.blue,
            scaffoldBackgroundColor: Colors.grey.shade50,
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black87,
              elevation: 1,
            ),
          ),
          
          // 🌙 暗黑模式默认配色
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            scaffoldBackgroundColor: const Color(0xFF121212),
            cardColor: const Color(0xFF1E1E1E),
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFF1E1E1E),
              elevation: 1,
            ),
          ),
          
          // ✨ 核心防御代码（降维打击）：
          // 无论用户在手机系统里把字体调到多大（长辈模式），
          // App 内部坚如磐石，永远强制保持 1.0 的标准缩放比例，杜绝排版挤爆！
          builder: (context, child) {
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.noScaling, 
              ),
              child: child!,
            );
          },
          
          // 指定启动后显示的第一个页面
          home: const HomePage(),
        );
      },
    );
  }
}