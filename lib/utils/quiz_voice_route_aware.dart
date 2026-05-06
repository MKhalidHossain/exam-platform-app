import 'package:flutter/material.dart';

import 'quiz_voice_route_observer.dart';

mixin QuizVoiceRouteAware<T extends StatefulWidget> on State<T>
    implements RouteAware {
  PageRoute<dynamic>? _voiceRoute;

  void onVoiceRouteActive();

  void onVoiceRouteInactive() {}

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is! PageRoute<dynamic>) return;
    if (_voiceRoute == route) return;
    if (_voiceRoute != null) {
      quizVoiceRouteObserver.unsubscribe(this);
    }
    _voiceRoute = route;
    quizVoiceRouteObserver.subscribe(this, route);
  }

  @override
  void dispose() {
    if (_voiceRoute != null) {
      quizVoiceRouteObserver.unsubscribe(this);
      _voiceRoute = null;
    }
    super.dispose();
  }

  @override
  void didPush() {
    onVoiceRouteActive();
  }

  @override
  void didPopNext() {
    onVoiceRouteActive();
  }

  @override
  void didPushNext() {
    onVoiceRouteInactive();
  }

  @override
  void didPop() {
    onVoiceRouteInactive();
  }
}
