import 'dart:io'; 
import 'dart:ui'; 
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';
import 'package:media_kit/media_kit.dart'; // 新增：引入 media_kit
import 'providers/settings_provider.dart';
import 'screens/home_page.dart';

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      // 解决某些自签证书导致的 HTTPS 报错问题
      ..badCertificateCallback = (X509Certificate cert, String host, int port) => true;
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 新增：初始化强大的视频引擎底层
  MediaKit.ensureInitialized(); 

  // 强制忽略证书错误，并准备在具体的图片库里配置 UA
  HttpOverrides.global = MyHttpOverrides();

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
    return Consumer<SettingsProvider>(
      builder: (context, settings, child) {
        final isDarkMode = settings.themeMode.contains('Dark');
        // 校验背景图路径是否存在且文件确实存在
        final hasCustomBg = settings.customBgPath.isNotEmpty && File(settings.customBgPath).existsSync();

        return MaterialApp(
          title: '智能追番助手',
          debugShowCheckedModeBanner: false, 
          
          themeMode: isDarkMode ? ThemeMode.dark : ThemeMode.light,
          
          theme: ThemeData(
            brightness: Brightness.light,
            primaryColor: Colors.blue,
            // 如果有背景，则变为白色的 85% 半透明，呈现毛玻璃透视效果；没有则保持默认纯色
            scaffoldBackgroundColor: hasCustomBg ? Colors.white.withValues(alpha: 0.85) : Colors.grey.shade50,
            appBarTheme: AppBarTheme(
              backgroundColor: hasCustomBg ? Colors.white.withValues(alpha: 0.8) : Colors.white,
              foregroundColor: Colors.black87,
              elevation: hasCustomBg ? 0 : 1,
            ),
          ),
          
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            // 深色模式同理，变为深灰色的 85% 半透明
            scaffoldBackgroundColor: hasCustomBg ? const Color(0xFF121212).withValues(alpha: 0.85) : const Color(0xFF121212),
            cardColor: hasCustomBg ? const Color(0xFF1E1E1E).withValues(alpha: 0.6) : const Color(0xFF1E1E1E),
            appBarTheme: AppBarTheme(
              backgroundColor: hasCustomBg ? const Color(0xFF1E1E1E).withValues(alpha: 0.8) : const Color(0xFF1E1E1E),
              elevation: hasCustomBg ? 0 : 1,
            ),
          ),
          
          builder: (context, child) {
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.noScaling, 
              ),
              child: Stack(
                children: [
                  // 1. 最底层的全局自定义背景图
                  if (hasCustomBg)
                    Positioned.fill(
                      child: Image.file(
                        File(settings.customBgPath),
                        fit: BoxFit.cover,
                      ),
                    ),
                  
                  // 2. 整个 App 的路由栈内容覆盖在背景之上
                  child!,
                ],
              ),
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