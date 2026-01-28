import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'utils/app_theme.dart';
import 'routes/app_router.dart';
import 'controllers/auth_controller.dart';
import 'controllers/splash_controller.dart';
import 'controllers/theme_controller.dart';

final _router = getRouter();

void main() {
  // Initialize GetX
  Get.put(ThemeController());
  Get.put(AuthController(), permanent: true);
  Get.put(SplashController(), permanent: true);
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();

    return Obx(() => MaterialApp.router(
      title: 'EJ Flutter App',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeController.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      routerConfig: _router,
    ));
  }
}
