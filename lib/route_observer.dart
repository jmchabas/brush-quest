import 'package:flutter/widgets.dart';

/// Global route observer so screens can react to becoming visible again after
/// a pushed route is popped (via [RouteAware.didPopNext]). Registered in
/// MaterialApp.navigatorObservers. HomeScreen uses it to restart its ambient
/// music when the user returns from world map / hero shop / trophy wall /
/// settings — those screens stop music on dispose and Home's initState does
/// not re-run on pop-back, so without this Home stays silent on return.
final RouteObserver<PageRoute<dynamic>> routeObserver =
    RouteObserver<PageRoute<dynamic>>();
