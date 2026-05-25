import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app/app_navigator.dart';
import 'app/app_router.dart';
import 'app/auth_notifier.dart';
import 'app/avatar_notifier.dart';
import 'app/tema_geracao_notifier.dart';
import 'app/estuda_ai_app.dart';
import 'core/network/api_client.dart';
import 'core/network/pending_tema_generation_storage.dart';
import 'core/network/token_storage.dart';
import 'repositories/auth_repository.dart';
import 'repositories/tema_repository.dart';
import 'repositories/user_repository.dart';
import 'services/tema_study_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final tokenStorage = TokenStorage();
  final pendingGeracaoStorage = PendingTemaGenerationStorage();
  late final AuthNotifier authNotifier;
  late final AvatarNotifier avatarNotifier;
  final apiClient = ApiClient(
    tokenStorage: tokenStorage,
    onUnauthorized: () => authNotifier.handleUnauthorized(),
  );
  final authRepo = AuthRepository(apiClient, tokenStorage, pendingGeracaoStorage);
  final userRepo = UserRepository(apiClient);
  avatarNotifier = AvatarNotifier(userRepo);
  authNotifier = AuthNotifier(
    tokenStorage,
    authRepo,
    userRepo,
    pendingGeracaoStorage,
    onUserLoaded: (user) => avatarNotifier.applyFromUserAvatarId(user?.avatarId),
  );
  final temaRepo = TemaRepository(apiClient);
  final temaGeracaoNotifier = TemaGeracaoNotifier();
  final temaStudy = TemaStudyService(
    temaRepo,
    pendingGeracaoStorage,
    temaGeracaoNotifier,
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
        Provider<AuthRepository>.value(value: authRepo),
        Provider<UserRepository>.value(value: userRepo),
        Provider<TemaRepository>.value(value: temaRepo),
        Provider<TemaStudyService>.value(value: temaStudy),
      ],
      child: EstudaAiApp(router: router),
    ),
  );
}
