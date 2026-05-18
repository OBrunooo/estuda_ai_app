import 'package:flutter/foundation.dart';

import '../core/network/pending_tema_generation_storage.dart';
import '../core/network/token_storage.dart';
import '../models/user_model.dart';
import '../repositories/auth_repository.dart';

class AuthNotifier extends ChangeNotifier {
  AuthNotifier(this._tokenStorage, this._authRepo, this._pendingGeracao) {
    _bootstrap();
  }

  final TokenStorage _tokenStorage;
  final AuthRepository _authRepo;
  final PendingTemaGenerationStorage _pendingGeracao;

  bool _ready = false;
  bool _loggedIn = false;
  UserModel? _user;

  bool get ready => _ready;
  bool get loggedIn => _loggedIn;
  UserModel? get currentUser => _user;

  Future<void> _bootstrap() async {
    final t = await _tokenStorage.readToken();
    _loggedIn = t != null && t.isNotEmpty;
    _ready = true;
    notifyListeners();
  }

  Future<void> handleUnauthorized() async {
    await _tokenStorage.clearToken();
    await _pendingGeracao.clear();
    _loggedIn = false;
    _user = null;
    notifyListeners();
  }

  Future<AuthResult> login(String email, String senha) async {
    final r = await _authRepo.login(email: email, senha: senha);
    if (r.isSuccess) {
      _loggedIn = true;
      _user = r.user;
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
    }
    notifyListeners();
    return r;
  }

  /// Só em memória até existir endpoint de perfil na API.
  void updateLocalUser(UserModel user) {
    _user = user;
    notifyListeners();
  }

  Future<void> logout() async {
    await _authRepo.logout();
    _loggedIn = false;
    _user = null;
    notifyListeners();
  }
}
