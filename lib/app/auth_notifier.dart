import 'package:flutter/foundation.dart';

import '../core/network/api_exception.dart';
import '../core/network/pending_tema_generation_storage.dart';
import '../core/network/token_storage.dart';
import '../models/user_model.dart';
import '../repositories/auth_repository.dart';
import '../repositories/user_repository.dart';

typedef UserLoadedCallback = void Function(UserModel? user);

class AuthNotifier extends ChangeNotifier {
  AuthNotifier(
    this._tokenStorage,
    this._authRepo,
    this._userRepo,
    this._pendingGeracao, {
    UserLoadedCallback? onUserLoaded,
  }) : _onUserLoaded = onUserLoaded {
    _bootstrap();
  }

  final TokenStorage _tokenStorage;
  final AuthRepository _authRepo;
  final UserRepository _userRepo;
  final PendingTemaGenerationStorage _pendingGeracao;
  final UserLoadedCallback? _onUserLoaded;

  bool _ready = false;
  bool _loggedIn = false;
  UserModel? _user;

  bool get ready => _ready;
  bool get loggedIn => _loggedIn;
  UserModel? get currentUser => _user;

  Future<void> _bootstrap() async {
    final t = await _tokenStorage.readToken();
    _loggedIn = t != null && t.isNotEmpty;
    if (_loggedIn) {
      await refreshUser(silent: true);
    }
    _ready = true;
    notifyListeners();
  }

  Future<void> handleUnauthorized() async {
    await _tokenStorage.clearToken();
    await _pendingGeracao.clear();
    _loggedIn = false;
    _user = null;
    _onUserLoaded?.call(null);
    notifyListeners();
  }

  Future<AuthResult> login(String email, String senha) async {
    final r = await _authRepo.login(email: email, senha: senha);
    if (r.isSuccess) {
      _loggedIn = true;
      _user = r.user;
      _onUserLoaded?.call(_user);
      await refreshUser(silent: true);
    }
    notifyListeners();
    return r;
  }

  Future<AuthResult> signUp({
    required String email,
    required String senha,
    required String nome,
  }) async {
    final r = await _authRepo.registrar(email: email, senha: senha, nome: nome);
    if (r.isSuccess) {
      _loggedIn = true;
      _user = r.user;
      _onUserLoaded?.call(_user);
      await refreshUser(silent: true);
    }
    notifyListeners();
    return r;
  }

  /// Carrega o perfil do servidor (`GET /api/me`).
  Future<UserModel?> refreshUser({bool silent = false}) async {
    if (!_loggedIn) return null;
    try {
      final user = await _userRepo.fetchMe();
      _user = user;
      _onUserLoaded?.call(user);
      if (!silent) notifyListeners();
      return user;
    } on Object catch (e, st) {
      debugPrint('AuthNotifier: falha ao carregar perfil ($e)\n$st');
      return _user;
    } finally {
      if (silent) notifyListeners();
    }
  }

  /// Persiste o nome via `POST /api/update-name-user`.
  Future<String?> updateNameOnServer(String name) async {
    try {
      await _userRepo.updateName(name.trim());
      final existing = _user;
      if (existing != null) {
        _user = existing.copyWith(name: name.trim());
        _onUserLoaded?.call(_user);
        notifyListeners();
      }
      return null;
    } on ApiException catch (e) {
      return e.message;
    } on Object catch (e) {
      return e.toString();
    }
  }

  Future<void> logout() async {
    await _authRepo.logout();
    _loggedIn = false;
    _user = null;
    _onUserLoaded?.call(null);
    notifyListeners();
  }
}
