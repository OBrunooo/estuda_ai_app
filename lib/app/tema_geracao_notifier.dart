import 'package:flutter/foundation.dart';

/// Dispara atualização da lista de temas e do card de geração pendente na [HomeScreen].
class TemaGeracaoNotifier extends ChangeNotifier {
  void notificarMudanca() => notifyListeners();
}
