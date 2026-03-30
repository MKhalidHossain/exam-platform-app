import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AppTabNavigationController extends ChangeNotifier {
  void openResourcesTab() {
    notifyListeners();
  }
}

final AppTabNavigationController appTabNavigationController =
    AppTabNavigationController();

void openResourcesTab(BuildContext context) {
  appTabNavigationController.openResourcesTab();
  context.go('/home?tab=resources');
}
