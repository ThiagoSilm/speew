import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Serviço para gerenciar a dualidade de interface (Sobrevivência vs Engenharia)
class SurvivalModeService extends ChangeNotifier {
  static final SurvivalModeService _instance = SurvivalModeService._internal();
  factory SurvivalModeService() => _instance;
  SurvivalModeService._internal();

  /// Se o modo de sobrevivência (simplificado) está ativo
  bool _isSurvivalMode = true;
  bool get isSurvivalMode => _isSurvivalMode;

  /// Se o console de engenharia está visível
  bool _isEngineeringConsoleVisible = false;
  bool get isEngineeringConsoleVisible => _isEngineeringConsoleVisible;

  /// Alterna entre modo de sobrevivência e modo completo
  void toggleSurvivalMode() {
    _isSurvivalMode = !_isSurvivalMode;
    HapticFeedback.heavyImpact();
    notifyListeners();
  }

  /// Ativa o console de engenharia (requer "segredo" ou intelecto alto)
  void toggleEngineeringConsole() {
    _isEngineeringConsoleVisible = !_isEngineeringConsoleVisible;
    HapticFeedback.selectionClick();
    notifyListeners();
  }

  /// Retorna a cor de status baseada na conectividade
  /// Verde: Seguro/Conectado, Amarelo: Alerta/Buscando, Vermelho: Perigo/Desconectado
  Color getStatusColor(bool isConnected, bool isDiscovering) {
    if (isConnected) return const Color(0xFF00FF00); // Verde Neon
    if (isDiscovering) return const Color(0xFFFFFF00); // Amarelo Neon
    return const Color(0xFFFF0000); // Vermelho Neon
  }
}
