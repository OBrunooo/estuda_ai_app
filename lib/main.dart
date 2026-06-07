import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app/app_navigator.dart';
import 'app/app_router.dart';
import 'app/auth_notifier.dart';
import 'app/avatar_notifier.dart';
import 'app/notifications_notifier.dart';
import 'app/tema_geracao_notifier.dart';
import 'app/estuda_ai_app.dart';
import 'core/network/api_client.dart';
import 'core/network/token_storage.dart';
import 'repositories/auth_repository.dart';
import 'repositories/tema_repository.dart';
import 'repositories/temas_cache_storage.dart';
import 'repositories/user_repository.dart';
import 'services/tema_study_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final tokenStorage = TokenStorage();
  late final AuthNotifier authNotifier;
  late final AvatarNotifier avatarNotifier;
  final apiClient = ApiClient(
    tokenStorage: tokenStorage,
    onUnauthorized: () => authNotifier.handleUnauthorized(),
  );
  final authRepo = AuthRepository(apiClient, tokenStorage);
  final userRepo = UserRepository(apiClient);
  avatarNotifier = AvatarNotifier(userRepo);
  authNotifier = AuthNotifier(
    tokenStorage,
    authRepo,
    userRepo,
    onUserLoaded: (user) => avatarNotifier.applyFromUserAvatarId(user?.avatarId),
  );
  final temaRepo = TemaRepository(apiClient);
  final temasCache = TemasCacheStorage();
  final temaGeracaoNotifier = TemaGeracaoNotifier();
  final notificationsNotifier = NotificationsNotifier();
  final temaStudy = TemaStudyService(
    temaRepo,
    temaGeracaoNotifier,
    notificationsNotifier,
    appRootNavigatorKey,
  );
  final router = createAppRouter(authNotifier);

  await avatarNotifier.loadFromDisk();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthNotifier>.value(value: authNotifier),
        ChangeNotifierProvider<AvatarNotifier>.value(value: avatarNotifier),
        ChangeNotifierProvider<TemaGeracaoNotifier>.value(value: temaGeracaoNotifier),
        ChangeNotifierProvider<NotificationsNotifier>.value(
          value: notificationsNotifier,
        ),
        Provider<AuthRepository>.value(value: authRepo),
        Provider<UserRepository>.value(value: userRepo),
        Provider<TemaRepository>.value(value: temaRepo),
        Provider<TemasCacheStorage>.value(value: temasCache),
        Provider<TemaStudyService>.value(value: temaStudy),
      ],
      child: EstudaAiApp(router: router),
    ),
  );
}
