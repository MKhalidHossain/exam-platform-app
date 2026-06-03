import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'utils/app_theme.dart';
import 'utils/app_constants.dart';
import 'routes/app_router.dart';
import 'services/installation_id_service.dart';
import 'services/app_link_service.dart';
import 'controllers/auth_controller.dart';
import 'controllers/quiz_voice_controller.dart';
import 'controllers/splash_controller.dart';
import 'controllers/theme_controller.dart';

final _router = getRouter();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  Stripe.publishableKey = AppConstants.stripePublishableKey;
  // Return URL scheme for 3DS / redirect-based payment methods (Android & iOS)
  Stripe.urlScheme = 'flutterstripe';
  await Stripe.instance.applySettings();

  // Ensure installation identifier exists before any API/auth actions.
  if (AppConstants.deviceBlockingEnabled) {
    await InstallationIdService().getOrCreateInstallationId();
  }

  // Initialize GetX
  Get.put(ThemeController());
  Get.put(AuthController(), permanent: true);
  Get.put(QuizVoiceController(), permanent: true);
  Get.put(SplashController(), permanent: true);

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final AppLinkService _appLinkService;

  @override
  void initState() {
    super.initState();
    _appLinkService = AppLinkService(_router);
    _appLinkService.start();
  }

  @override
  void dispose() {
    _appLinkService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();

    return Obx(() {
      final themeMode = themeController.isDarkMode
          ? ThemeMode.dark
          : ThemeMode.light;
      return MaterialApp.router(
        key: ValueKey<ThemeMode>(themeMode),
        title: 'EJ Flutter App',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: themeMode,
        routerConfig: _router,
      );
    });
  }
}
