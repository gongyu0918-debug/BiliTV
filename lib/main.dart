import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/splash_screen.dart'; // 引入 Splash Screen

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // TV 设备图片缓存保持适中，避免与视频播放争用内存。
  PaintingBinding.instance.imageCache.maximumSize = 240;
  PaintingBinding.instance.imageCache.maximumSizeBytes = 96 << 20;

  // 全屏模式 - 隐藏状态栏和导航栏
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  runApp(const BiliTvApp());
}

class BiliTvApp extends StatelessWidget {
  const BiliTvApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BiliTV',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF121212),
        primaryColor: const Color(0xFFfb7299), // Bilibili 粉色
        useMaterial3: true,
        focusColor: Colors.white.withValues(alpha: 0.1),
      ),
      home: const SplashScreen(),
    );
  }
}
