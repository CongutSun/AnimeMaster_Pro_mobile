import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart'; // 📦 引入官方热更新包
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
          
          // ✨ 核心防御代码：永远强制保持 1.0 的标准缩放比例
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

// ============================================================================
// 🚀 以下为专门用于检测热更新的透明包裹层 (已适配最新 API)
// ============================================================================
class UpdateCheckWrapper extends StatefulWidget {
  final Widget child; // 接收原本要显示的页面（即 HomePage）
  
  const UpdateCheckWrapper({super.key, required this.child});

  @override
  State<UpdateCheckWrapper> createState() => _UpdateCheckWrapperState();
}

class _UpdateCheckWrapperState extends State<UpdateCheckWrapper> {
  // 1. 使用新版 API 的 ShorebirdUpdater 类
  final _updater = ShorebirdUpdater();

  @override
  void initState() {
    super.initState();
    // 延迟到第一帧渲染完成后再检查，确保不会卡顿 App 启动时的白屏
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkForUpdates();
    });
  }

  // 核心方法：检查更新并弹窗
  Future<void> _checkForUpdates() async {
    try {
      // 2. 检查云端是否有新版本补丁
      final status = await _updater.checkForUpdate();
      
      // 如果状态是 outdated，说明云端有新代码可用
      if (status == UpdateStatus.outdated && mounted) {
        _showUpdateDialog();
      }
    } catch (e) {
      debugPrint("检查更新失败: $e");
    }
  }

  // 弹窗 UI 的实现
  void _showUpdateDialog() {
    showDialog(
      context: context,
      barrierDismissible: false, // 强制用户做出选择，不能点击空白处关闭
      // 3. 将弹窗的 Context 命名为 dialogContext，避免和页面的 Context 冲突导致警告
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('发现新版本'),
          content: const Text('我们修复了一些问题并优化了体验，是否立即更新？'),
          actions: <Widget>[
            TextButton(
              child: const Text('稍后', style: TextStyle(color: Colors.grey)),
              onPressed: () {
                // 关闭更新提示窗
                Navigator.of(dialogContext).pop();
              },
            ),
            ElevatedButton(
              child: const Text('立即更新'),
              onPressed: () async {
                // 先关掉更新提示窗
                Navigator.of(dialogContext).pop();
                
                // 显示正在下载的弹窗
                _showDownloadingDialog();

                try {
                  // 4. 调用新版 API 的 update() 方法执行下载
                  await _updater.update();

                  // 5. 严格遵循 Flutter 异步规范，检查页面自身是否还在
                  if (!mounted) return;
                  
                  // 关闭正在下载的 Loading 弹窗
                  Navigator.of(context).pop();
                  // 提示用户重启生效
                  _showRestartDialog();
                } catch (e) {
                  debugPrint("更新出错: $e");
                  if (!mounted) return;
                  // 万一下载失败，也要把 Loading 弹窗关掉
                  Navigator.of(context).pop();
                }
              },
            ),
          ],
        );
      },
    );
  }

  // 简单的下载中提示
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

  // 下载完成后提示重启
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
    // 界面上正常显示子页面（即你的 HomePage），不受任何影响
    return widget.child;
  }
}