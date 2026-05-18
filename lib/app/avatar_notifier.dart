import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Avatar escolhido pelo usuário (persistido só no aparelho).
class AvatarNotifier extends ChangeNotifier {
  static const _prefsKey = 'selected_avatar_id';

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

  Future<void> select(String id) async {
    _selectedId = id;
    notifyListeners();
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_prefsKey, id);
    } on Object catch (e, st) {
      debugPrint('AvatarNotifier: falha ao gravar prefs ($e)\n$st');
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
