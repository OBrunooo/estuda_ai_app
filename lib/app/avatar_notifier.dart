import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/avatar_option.dart';
import '../repositories/user_repository.dart';

/// Avatar escolhido pelo usuário (cache local + sincronização com a API).
class AvatarNotifier extends ChangeNotifier {
  AvatarNotifier(this._userRepo);

  static const _prefsKey = 'selected_avatar_id';

  final UserRepository _userRepo;

  String? _selectedId;
  bool _ready = false;

  String? get selectedId => _selectedId;
  bool get ready => _ready;

  /// Chame [loadFromDisk] em `main()` (após [WidgetsFlutterBinding.ensureInitialized])
  /// **antes** de [runApp], para o canal nativo do Android estar pronto.
  Future<void> loadFromDisk() async {
    try {
      final p = await SharedPreferences.getInstance();
      _selectedId = p.getString(_prefsKey);
    } on Object catch (e, st) {
      debugPrint('AvatarNotifier: falha ao ler prefs ($e)\n$st');
    } finally {
      _ready = true;
      notifyListeners();
    }
  }

  /// Aplica o avatar vindo do perfil remoto (`users.avatar_id`).
  Future<void> applyFromUserAvatarId(int? avatarId) async {
    final id = AvatarOption.fromApiId(avatarId);
    if (id == _selectedId) return;
    _selectedId = id;
    notifyListeners();
    try {
      final p = await SharedPreferences.getInstance();
      if (id == null) {
        await p.remove(_prefsKey);
      } else {
        await p.setString(_prefsKey, id);
      }
    } on Object catch (e, st) {
      debugPrint('AvatarNotifier: falha ao gravar prefs ($e)\n$st');
    }
  }

  Future<String?> selectAndSync(String id) async {
    _selectedId = id;
    notifyListeners();
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_prefsKey, id);
      await _userRepo.updateAvatar(AvatarOption.toApiId(id));
      return null;
    } on Object catch (e, st) {
      debugPrint('AvatarNotifier: falha ao sincronizar avatar ($e)\n$st');
      return e.toString();
    }
  }

  Future<void> clear() async {
    _selectedId = null;
    notifyListeners();
    try {
      final p = await SharedPreferences.getInstance();
      await p.remove(_prefsKey);
    } on Object catch (e, st) {
      debugPrint('AvatarNotifier: falha ao limpar prefs ($e)\n$st');
    }
  }
}
