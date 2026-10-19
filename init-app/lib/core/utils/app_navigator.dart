import 'package:flutter/material.dart';
import 'package:mobile_template/core/di/di.dart';

/// Root of THIS app, not the outer production navigator hosting a demo app.
NavigatorState appNavigator(BuildContext context) {
  if (getIt.isRegistered<GlobalKey<NavigatorState>>(
    instanceName: 'navigatorKey',
  )) {
    final navigator = getIt<GlobalKey<NavigatorState>>(
      instanceName: 'navigatorKey',
    ).currentState;
    if (navigator != null) return navigator;
  }
  return Navigator.of(context, rootNavigator: true);
}
