import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'app_navigator.dart';
import 'auth_notifier.dart';
import '../screens/forgot_password_screen.dart';
import '../screens/login_screen.dart';
import '../screens/register_screen.dart';
import '../screens/reset_password_screen.dart';
import '../screens/splash_screen.dart';
import '../models/loading_questoes_args.dart';
import '../models/questoes_conjunto_args.dart';
import '../models/study_session.dart';
import '../screens/home_screen.dart';
import '../screens/tema_input_screen.dart';
import '../screens/loading_questoes_screen.dart';
import '../screens/conjuntos_session_screen.dart';
import '../screens/questoes_session_screen.dart';
import '../screens/profile_settings_screen.dart';
import '../screens/avatar_picker_screen.dart';

GoRouter createAppRouter(AuthNotifier auth) {
  return GoRouter(
    navigatorKey: appRootNavigatorKey,
    initialLocation: '/splash',
    refreshListenable: auth,
    redirect: (BuildContext context, GoRouterState state) {
      if (!auth.ready) {
        return state.matchedLocation == '/splash' ? null : '/splash';
      }
      if (state.matchedLocation == '/splash') {
        return auth.loggedIn ? '/home' : '/login';
      }
      final logging = state.matchedLocation == '/login' ||
          state.matchedLocation == '/register' ||
          state.matchedLocation == '/esqueci-senha' ||
          state.matchedLocation == '/redefinir-senha';
      if (!auth.loggedIn && !logging) {
        return '/login';
      }
      if (auth.loggedIn && logging) {
        return '/home';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/esqueci-senha',
        builder: (context, state) {
          final extra = state.extra;
          return ForgotPasswordScreen(
            initialEmail: extra is String ? extra : null,
          );
        },
      ),
      GoRoute(
        path: '/redefinir-senha',
        builder: (context, state) {
          final extra = state.extra;
          return ResetPasswordScreen(
            initialEmail: extra is String ? extra : null,
          );
        },
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/novo-tema',
        builder: (context, state) => const TemaInputScreen(),
      ),
      GoRoute(
        path: '/perfil',
        builder: (context, state) => const ProfileSettingsScreen(),
      ),
      GoRoute(
        path: '/perfil/avatar',
        builder: (context, state) => const AvatarPickerScreen(),
      ),
      GoRoute(
        path: '/loading',
        builder: (context, state) {
          final extra = state.extra;
          if (extra is! LoadingQuestoesArgs) {
            return const HomeScreen();
          }
          return LoadingQuestoesScreen(args: extra);
        },
      ),
      GoRoute(
        path: '/conjuntos',
        builder: (context, state) {
          final session = state.extra as StudySession?;
          if (session == null) {
            return const HomeScreen();
          }
          return ConjuntosSessionScreen(session: session);
        },
      ),
      GoRoute(
        path: '/questoes',
        builder: (context, state) {
          final extra = state.extra;
          if (extra is QuestoesConjuntoArgs) {
            return QuestoesSessionScreen(
              temaNome: extra.temaNome,
              conjunto: extra.conjunto,
            );
          }
          return const HomeScreen();
        },
      ),
    ],
  );
}
