import 'package:flutter/material.dart';

/// Single observer for [RouteAware] widgets (e.g. mobile [MessageScreen]).
final RouteObserver<PageRoute<dynamic>> appRouteObserver =
    RouteObserver<PageRoute<dynamic>>();
