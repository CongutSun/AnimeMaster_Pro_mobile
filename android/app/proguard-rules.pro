# 保留 sqflite 及必要的核心插件类不被混淆，避免 Release 模式下数据库初始化失败导致图片无法加载
-keep class com.tekartik.sqflite.** { *; }
-keep class io.flutter.plugins.urllauncher.** { *; }
-keep class io.flutter.plugins.pathprovider.** { *; }

# 保留 Flutter 原生方法调用，防止与 Dart 通信失败
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class plugins.flutter.io.** { *; }

# 忽略 Google Play Core 相关的缺失类警告，解决 R8 严格模式下的打包中断问题
-dontwarn com.google.android.play.core.**
-dontwarn io.flutter.embedding.engine.deferredcomponents.**