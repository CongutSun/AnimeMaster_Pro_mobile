import 'dart:ui'; 
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';
import 'providers/settings_provider.dart';
import 'screens/home_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (FlutterErrorDetails details) {
    debugPrint('【Flutter 全局异常拦截】: ${details.exceptionAsString()}');
    FlutterError.presentError(details);
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('【Dart 异步异常拦截】: $error\n堆栈: $stack');
    return true;
  };

  runApp(
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
          debugShowCheckedModeBanner: false, 
          
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
          
          builder: (context, child) {
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.noScaling, 
              ),
              child: child!,
            );
          },
          
          // 💡 用 UpdateCheckWrapper 把 HomePage 包裹起来
          home: const UpdateCheckWrapper(child: HomePage()),
        );
      },
    );
  }
}

class UpdateCheckWrapper extends StatefulWidget {
  final Widget child; 
  
  const UpdateCheckWrapper({super.key, required this.child});

  @override
  State<UpdateCheckWrapper> createState() => _UpdateCheckWrapperState();
}

class _UpdateCheckWrapperState extends State<UpdateCheckWrapper> {
  final _updater = ShorebirdUpdater();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkForUpdates();
    });
  }

  Future<void> _checkForUpdates() async {
    try {
      final status = await _updater.checkForUpdate();
      if (status == UpdateStatus.outdated && mounted) {
        _showUpdateDialog();
      }
    } catch (e) {
      debugPrint("检查更新失败: $e");
    }
  }

  void _showUpdateDialog() {
    showDialog(
      context: context,
      barrierDismissible: false, 
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('发现新版本'),
          content: const Text('我们修复了一些问题并优化了体验，是否立即更新？'),
          actions: <Widget>[
            TextButton(
              child: const Text('稍后', style: TextStyle(color: Colors.grey)),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
            ElevatedButton(
              child: const Text('立即更新'),
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                _showDownloadingDialog();

                try {
                  await _updater.update();
                  if (!mounted) return;
                  Navigator.of(context).pop();
                  _showRestartDialog();
                } catch (e) {
                  debugPrint("更新出错: $e");
                  if (!mounted) return;
                  Navigator.of(context).pop();
                }
              },
            ),
          ],
        );
      },
    );
  }

  void _showDownloadingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Text("正在下载更新，请稍候..."),
            ],
          ),
        );
      },
    );
  }

  void _showRestartDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('更新已准备就绪'),
          content: const Text('新版本已下载完毕，请划掉后台彻底重启 App 以应用更新。'),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('我知道了'),
            )
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}