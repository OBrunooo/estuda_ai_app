import 'package:flutter/material.dart';

/// Raiz do [Navigator] do [GoRouter] — usada para SnackBars e `go` após geração em segundo plano.
final GlobalKey<NavigatorState> appRootNavigatorKey = GlobalKey<NavigatorState>();
