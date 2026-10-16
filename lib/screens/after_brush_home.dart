// lib/screens/after_brush_home.dart
import 'package:flutter/material.dart';

import 'home_screen.dart';

/// How a finished brush reaches Home: [HomeScreen] with `skipGreeting`,
/// fading in, with nothing left to go back to. The victory screen and the
/// bedtime-reminder screens all leave this way.
abstract final class AfterBrushHome {
  /// Tests build a light page here instead of the real Home.
  @visibleForTesting
  static WidgetBuilder? debugBuilder;

  /// A route to [builder]'s page that fades in.
  static Route<void> fadeTo(WidgetBuilder builder) => PageRouteBuilder<void>(
    pageBuilder: (context, animation, secondaryAnimation) => builder(context),
    transitionsBuilder: (context, animation, secondaryAnimation, child) =>
        FadeTransition(opacity: animation, child: child),
  );

  /// The route to Home itself.
  static Route<void> route() =>
      fadeTo(debugBuilder ?? (_) => const HomeScreen(skipGreeting: true));

  /// Leaves for Home, removing every route below. Does nothing when the
  /// caller's own page is no longer on the navigator (removed, or popped and
  /// still sliding out): it has nowhere to go, and a timer on such a page
  /// would otherwise send Home a second time.
  static Future<void> go(BuildContext context) {
    final page = ModalRoute.of(context);
    if (page != null && !page.isActive) return Future<void>.value();
    return Navigator.of(
      context,
    ).pushAndRemoveUntil<void>(route(), (_) => false);
  }
}
