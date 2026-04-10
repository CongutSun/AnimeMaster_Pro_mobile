import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';
import 'providers/settings_provider.dart';
import 'screens/home_page.dart';

// 专业级：收拢 SSL 绕过策略，仅对特定图床域名放行，防止 App 遭受中间人攻击
class AppHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);
    client.badCertificateCallback = (X509Certificate cert, String host, int port) {
      // 仅允许我们已知的、证书可能存在问题的图床域名绕过校验
      final allowedHosts = ['bgm.tv', 'chii.in', 'lain.bgm.tv'];
      if (allowedHosts.any((allowed) => host.contains(allowed))) {
        return true;
      }
      return false; // 商业项目中，未知域名必须进行严格的证书校验
    };
    return client;
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 注入受控的 HTTP 全局配置
  HttpOverrides.global = AppHttpOverrides();

  // 专业级：Flutter 框架层面的异常捕获
  FlutterError.onError = (FlutterErrorDetails details) {
    // 未来可替换为 Firebase Crashlytics 或 Sentry 上报逻辑
    debugPrint('[Flutter Framework Error]: ${details.exceptionAsString()}');
    FlutterError.presentError(details);
  };

  // 专业级：Dart 异步任务异常捕获
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('[Dart Async Error]: $error\nStack: $stack');
    return true; // 阻止应用崩溃退出
  };

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
      ],
      child: const AnimeApp(),
    ),
  );
}

class AnimeApp extends StatelessWidget {
  const AnimeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (context, settings, child) {
        final isDarkMode = settings.themeMode.contains('Dark');

        return MaterialApp(
          title: '智能追番助手',
          debugShowCheckedModeBanner: false, 
          themeMode: isDarkMode ? ThemeMode.dark : ThemeMode.light,
          
          theme: ThemeData(
            brightness: Brightness.light,
            primaryColor: Colors.blue,
            scaffoldBackgroundColor: Colors.grey.shade50,
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black87,
              elevation: 1,
            ),
          ),
          
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
            // 锁定字体大小，防止用户系统字体设置导致 UI 错位
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.noScaling, 
              ),
              child: child!,
            );
          },
          
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
      debugPrint('[Update Checker Error]: $e');
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
                  debugPrint('[Update Process Error]: $e');
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
              Text('正在下载更新，请稍候...'),
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