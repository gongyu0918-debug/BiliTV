import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../models/video.dart';
import '../services/app_bootstrap.dart';
import '../services/auth_service.dart';
import '../services/bilibili_api.dart';
import '../services/settings_service.dart';
import '../services/tv_home_service.dart';
import '../utils/image_url_utils.dart';
import 'home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    await SettingsService.init();

    final splashEnabled = SettingsService.splashAnimationEnabled;
    final startTime = DateTime.now();

    await AppBootstrap.ensureInitialized();

    if (AuthService.isLoggedIn) {
      unawaited(
        BilibiliApi.fetchAndSaveUserInfo().catchError((e) {
          debugPrint('Failed to update user info on splash: $e');
        }),
      );
    }

    if (!splashEnabled) {
      if (!mounted) return;
      _navigateToHome(const []);
      return;
    }

    final preloadedVideos = await _preloadRecommendVideos();

    if (splashEnabled) {
      const minSplashDuration = Duration(milliseconds: 600);
      final elapsed = DateTime.now().difference(startTime);
      if (elapsed < minSplashDuration) {
        await Future.delayed(minSplashDuration - elapsed);
      }
    }

    if (!mounted) return;

    _navigateToHome(preloadedVideos);
  }

  void _navigateToHome(List<Video> preloadedVideos) {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, a1, a2) =>
            HomeScreen(preloadedVideos: preloadedVideos),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 250),
      ),
    );
  }

  Future<List<Video>> _preloadRecommendVideos() async {
    var videos = <Video>[];
    try {
      videos = await BilibiliApi.getRecommendVideos(
        idx: 0,
      ).timeout(const Duration(seconds: 4));

      if (mounted && videos.isNotEmpty) {
        const maxPreloadCount = 10;
        final count = videos.length > maxPreloadCount
            ? maxPreloadCount
            : videos.length;

        final imageTasks = <Future<void>>[];
        for (int i = 0; i < count; i++) {
          final url = videos[i].pic;
          if (url.isEmpty) continue;

          final optimizedUrl = ImageUrlUtils.getResizedUrl(
            url,
            width: 640,
            height: 360,
          );
          final imageProvider = CachedNetworkImageProvider(
            optimizedUrl,
            maxWidth: 360,
            maxHeight: 200,
            cacheManager: BiliCacheManager.instance,
          );

          imageTasks.add(
            precacheImage(imageProvider, context).catchError((_) {
              debugPrint('Image preload failed: $url');
            }),
          );
        }

        if (imageTasks.isNotEmpty) {
          await Future.wait(imageTasks);
        }
      }

      return videos;
    } catch (e) {
      debugPrint('Preload videos failed: $e');
      return [];
    } finally {
      if (videos.isNotEmpty) {
        unawaited(TvHomeService.publishRecommendations(videos));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: SizedBox.expand(
        child: Image.asset(
          'assets/icons/startup_frame.jpg',
          fit: BoxFit.cover,
          gaplessPlayback: true,
        ),
      ),
    );
  }
}
