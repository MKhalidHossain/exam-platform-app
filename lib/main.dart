import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'utils/app_theme.dart';
import 'utils/app_constants.dart';
import 'routes/app_router.dart';
import 'controllers/auth_controller.dart';
import 'controllers/splash_controller.dart';
import 'controllers/theme_controller.dart';

final _router = getRouter();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Stripe.publishableKey = AppConstants.stripePublishableKey;
  // Return URL scheme for 3DS / redirect-based payment methods (Android & iOS)
  Stripe.urlScheme = 'flutterstripe';
  await Stripe.instance.applySettings();

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
