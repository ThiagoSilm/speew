// ==================== STUBS E MOCKS PARA COMPILAÇÃO ====================
import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';

// '../../core/utils/logger_service.dart'
class LoggerService {
  void info(String message, {String? tag, dynamic error}) => print('[INFO][${tag ?? 'App'}] $message ${error ?? ''}');
  void warn(String message, {String? tag, dynamic error}) => print('[WARN][${tag ?? 'App'}] $message ${error ?? ''}');
  void error(String message, {String? tag, dynamic error}) => print('[ERROR][${tag ?? 'App'}] $message ${error ?? ''}');
  void debug(String message, {String? tag, dynamic error}) {
    if (kDebugMode) print('[DEBUG][${tag ?? 'App'}] $message ${error ?? ''}');
  }
}
final logger = LoggerService();

// '../storage/database_service.dart'
class DatabaseService {
  Future<void> init() async {}
}

// '../reputation/reputation_service.dart'
class ReputationService {
  final Map<String, double> _reputations = {
    'peerA_good': 0.9,
    'peerB_medium': 0.6,
    'peerC_bad': 0.2,
    'peerD_new': 0.5,
  };

  Future<double> getReputation(String peerId) async {
    return _reputations[peerId] ?? 0.5;
  }

  Future<void> updateReputation(String peerId, double change) async {
    final current = _reputations[peerId] ?? 0.5;
    _reputations[peerId] = (current + change).clamp(0.0, 1.0);
  }
}

// ==================== IntelligentMeshService ====================

class IntelligentMeshService extends ChangeNotifier {
  static final IntelligentMeshService _instance = IntelligentMeshService._internal();
  factory IntelligentMeshService() => _instance;
  IntelligentMeshService._internal();

  final DatabaseService _db = DatabaseService();
  final ReputationService _reputation = ReputationService();

  /// Histórico de rotas bem-sucedidas
  final Map<String, List<List<String>>> _successfulRoutes = {};

  /// Histórico de falhas de roteamento
  final Map<String, int> _peerFailures = {};

  /// Latências médias por peer
  final Map<String, double> _peerLatencies = {};

  /// Confiabilidade de peers (taxa de sucesso)
  final Map<String, double> _peerReliability = {};

  /// Threshold de confiabilidade mínima para roteamento
  double _minReliabilityThreshold = 0.5;

  /// Threshold de reputação mínima para roteamento
  double _minReputationThreshold = 0.4;
  
  /// Modo de Automação (Baixo Intelecto) vs Override Manual (Alto Intelecto)
  bool _isAutomationEnabled = true;
  bool get isAutomationEnabled => _isAutomationEnabled;

  void setAutomation(bool enabled) {
    _isAutomationEnabled = enabled;
    logger.info('Automação de Malha ${enabled ? 'ativada' : 'desativada (Override Manual)'}', tag: 'IntelligentMesh');
    notifyListeners();
  }

  void setManualThresholds({double? reliability, double? reputation}) {
    if (reliability != null) _minReliabilityThreshold = reliability;
    if (reputation != null) _minReputationThreshold = reputation;
    notifyListeners();
  }

  /// Número máximo de falhas antes de blacklist temporário
  static const int _maxFailuresBeforeBlacklist = 5;

  /// Duração do blacklist temporário
  static const Duration _blacklistDuration = Duration(minutes: 10);

  /// Peers em blacklist temporário
  final Map<String, DateTime> _blacklistedPeers = {};

  // ==================== SELEÇÃO INTELIGENTE DE ROTAS ====================

  /// Seleciona a melhor rota para um destino baseado em heurísticas
  Future<List<String>?> selectBestRoute(
    String destinationId,
    List<String> availablePeers,
  ) async {
    try {
      // Remove peers em blacklist
      final validPeers = await _filterBlacklistedPeers(availablePeers);
      
      if (validPeers.isEmpty) {
        logger.info('Nenhum peer válido disponível', tag: 'IntelligentMesh');
        return null;
      }

      // 1. Se a automação estiver desativada, o sistema não toma decisões sozinho
      if (!_isAutomationEnabled) {
        logger.warn('Automação desativada. Aguardando comando manual de rota.', tag: 'IntelligentMesh');
        return null;
      }

      // 2. Prioriza rotas históricas bem-sucedidas
      if (_successfulRoutes.containsKey(destinationId)) {
        final historicalRoutes = _successfulRoutes[destinationId]!;
        
        for (final route in historicalRoutes.reversed) {
          if (_isRouteAvailable(route, validPeers)) {
            logger.info('Usando rota histórica bem-sucedida', tag: 'IntelligentMesh');
            return route;
          }
        }
      }

      // 2. Calcula melhor rota baseada em heurísticas complexas
      final bestRoute = await _calculateBestRoute(destinationId, validPeers);
      
      
      return bestRoute;
    } catch (e) {
      logger.info('Erro ao selecionar rota: $e', tag: 'IntelligentMesh');
      return null;
    }
  }

  /// Calcula a melhor rota baseada em múltiplas heurísticas
  Future<List<String>> _calculateBestRoute(
    String destinationId,
    List<String> availablePeers,
  ) async {
    // Calcula score para cada peer
    final peerScores = <String, double>{};
    
    for (final peerId in availablePeers) {
      final score = await _calculatePeerScore(peerId);
      peerScores[peerId] = score;
    }

    // Ordena peers por score (maior primeiro)
    final sortedPeers = peerScores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Retorna rota com os melhores peers (até 3 hops)
    final route = sortedPeers
        .take(3) // Estratégia de 3 hops para resiliência e velocidade
        .map((e) => e.key)
        .toList();

    logger.info('Rota calculada: $route', tag: 'IntelligentMesh');
    return route;
  }

  /// Calcula score de um peer baseado em múltiplos fatores
  Future<double> _calculatePeerScore(String peerId) async {
    double score = 0.0;

    // Fator 1: Reputação (peso: 40%) - Valor externo (ReputationService)
    final reputation = await _reputation.getReputation(peerId);
    score += reputation * 0.4;

    // Fator 2: Confiabilidade (peso: 30%) - Histórico local de sucesso
    final reliability = _peerReliability[peerId] ?? 0.5;
    score += reliability * 0.3;

    // Fator 3: Latência (peso: 20%) - Métrica de performance (velocidade)
    final latency = _peerLatencies[peerId] ?? 1000.0;
    // Normaliza latência (0.0=máxima lentidão, 1.0=máxima velocidade)
    final latencyScore = 1.0 - (latency / 2000.0).clamp(0.0, 1.0); 
    score += latencyScore * 0.2;

    // Fator 4: Histórico de falhas (peso: 10%) - Métrica de resiliência
    final failures = _peerFailures[peerId] ?? 0;
    final failureScore = 1.0 - (failures / _maxFailuresBeforeBlacklist).clamp(0.0, 1.0);
    score += failureScore * 0.1;

    return score;
  }

  /// Verifica se uma rota está disponível
  bool _isRouteAvailable(List<String> route, List<String> availablePeers) {
    return route.every((peerId) => availablePeers.contains(peerId));
  }

  /// Filtra peers em blacklist e com reputação/confiabilidade baixa
  Future<List<String>> _filterBlacklistedPeers(List<String> peers) async {
    final now = DateTime.now();
    final validPeers = <String>[];

    for (final peerId in peers) {
      // 1. Verifica Blacklist Temporário
      if (_blacklistedPeers.containsKey(peerId)) {
        final blacklistTime = _blacklistedPeers[peerId]!;
        if (now.difference(blacklistTime) > _blacklistDuration) {
          _blacklistedPeers.remove(peerId);
          logger.info('Peer $peerId removido do blacklist por expiração', tag: 'IntelligentMesh');
        } else {
          continue; // Ainda em blacklist
        }
      }

      // 2. Verifica reputação mínima (Reputação Externa)
      final reputation = await _reputation.getReputation(peerId);
      if (reputation < _minReputationThreshold) {
        logger.info('Peer $peerId filtrado por baixa reputação (${reputation.toStringAsFixed(2)})', tag: 'IntelligentMesh');
        continue;
      }

      // 3. Verifica confiabilidade mínima (Confiabilidade Interna)
      final reliability = _peerReliability[peerId] ?? 0.5;
      if (reliability < _minReliabilityThreshold) {
        logger.info('Peer $peerId filtrado por baixa confiabilidade (${reliability.toStringAsFixed(2)})', tag: 'IntelligentMesh');
        continue;
      }

      validPeers.add(peerId);
    }

    return validPeers;
  }

  // ==================== FEEDBACK DE ROTEAMENTO ====================

  /// Registra sucesso de roteamento
  Future<void> recordRouteSuccess(
    String destinationId,
    List<String> route,
    int latencyMs,
  ) async {
    try {
      // Adiciona rota ao histórico de sucesso (limita a 10)
      _successfulRoutes.putIfAbsent(destinationId, () => []).add(route);
      if (_successfulRoutes[destinationId]!.length > 10) {
        _successfulRoutes[destinationId]!.removeAt(0);
      }

      // Atualiza métricas de cada peer na rota
      for (final peerId in route) {
        // Atualiza confiabilidade (dá peso maior ao sucesso recente)
        final currentReliability = _peerReliability[peerId] ?? 0.5;
        _peerReliability[peerId] = (currentReliability * 0.9) + (1.0 * 0.1);

        // Atualiza latência média (algoritmo de média móvel exponencial)
        final currentLatency = _peerLatencies[peerId] ?? latencyMs.toDouble();
        _peerLatencies[peerId] = (currentLatency * 0.8) + (latencyMs * 0.2);

        // Reseta contador de falhas
        _peerFailures[peerId] = 0;
      }

      logger.info('Sucesso registrado para rota: $route', tag: 'IntelligentMesh');
      notifyListeners();
    } catch (e) {
      logger.info('Erro ao registrar sucesso: $e', tag: 'IntelligentMesh');
    }
  }

  /// Registra falha de roteamento
  Future<void> recordRouteFailure(String peerId) async {
    try {
      // Incrementa contador de falhas
      _peerFailures[peerId] = (_peerFailures[peerId] ?? 0) + 1;

      // Atualiza confiabilidade negativamente (dá peso maior à falha recente)
      final currentReliability = _peerReliability[peerId] ?? 0.5;
      _peerReliability[peerId] = (currentReliability * 0.9) + (0.0 * 0.1);

      // Adiciona ao blacklist se exceder o limite
      if (_peerFailures[peerId]! >= _maxFailuresBeforeBlacklist) {
        _blacklistedPeers[peerId] = DateTime.now();
        logger.warn('Peer $peerId adicionado ao blacklist temporário', tag: 'IntelligentMesh');
      }

      logger.info('Falha registrada para peer: $peerId', tag: 'IntelligentMesh');
      notifyListeners();
    } catch (e) {
      logger.info('Erro ao registrar falha: $e', tag: 'IntelligentMesh');
    }
  }

  // ==================== PRIORIZAÇÃO DE MENSAGENS ====================

  /// Calcula prioridade de uma mensagem para roteamento
  Future<int> calculateMessagePriority(
    String senderId,
    String messageType,
  ) async {
    try {
      int priority = 5; // Prioridade base (1-10)

      // Aumenta prioridade baseado na reputação do remetente (garantindo que remetentes confiáveis tenham maior chance)
      final reputation = await _reputation.getReputation(senderId);
      if (reputation >= 0.8) {
        priority += 3;
      } else if (reputation >= 0.6) {
        priority += 2;
      } else if (reputation >= 0.4) {
        priority += 1;
      }

      // Ajusta prioridade baseado no tipo de mensagem (Política de Rede)
      switch (messageType) {
        case 'transaction':
        case 'mesh_signal':
          priority += 3; // Mais alta prioridade para estabilidade da rede
          break;
        case 'metadata_update':
          priority += 1;
          break;
        case 'file_chunk':
          priority -= 1; // Prioridade ligeiramente menor para grandes transferências
          break;
        case 'text':
        default:
          // Mantém prioridade base
          break;
      }

      return priority.clamp(1, 10);
    } catch (e) {
      logger.info('Erro ao calcular prioridade: $e', tag: 'IntelligentMesh');
      return 5;
    }
  }

  /// Ordena mensagens por prioridade para roteamento
  Future<List<Map<String, dynamic>>> prioritizeMessages(
    List<Map<String, dynamic>> messages,
  ) async {
    final prioritizedMessages = <Map<String, dynamic>>[];

    for (final message in messages) {
      final senderId = message['sender_id'] as String;
      final messageType = message['type'] as String;
      final priority = await calculateMessagePriority(senderId, messageType);
      
      prioritizedMessages.add({
        ...message,
        'priority': priority,
      });
    }

    // Ordena por prioridade (maior primeiro)
    prioritizedMessages.sort((a, b) => 
      (b['priority'] as int).compareTo(a['priority'] as int)
    );

    return prioritizedMessages;
  }

  // ==================== ESTATÍSTICAS E DIAGNÓSTICO ====================

  /// Obtém estatísticas do mesh inteligente
  Map<String, dynamic> getMeshStats() {
    return {
      'successfulRoutesCount': _successfulRoutes.length,
      'totalPeersTracked': _peerReliability.length,
      'blacklistedPeersCount': _blacklistedPeers.length,
      'averageReliability': _calculateAverageReliability().toStringAsFixed(2),
      'averageLatencyMs': _calculateAverageLatency().toStringAsFixed(0),
    };
  }

  /// Calcula confiabilidade média da rede
  double _calculateAverageReliability() {
    if (_peerReliability.isEmpty) return 0.5;
    
    final sum = _peerReliability.values.reduce((a, b) => a + b);
    return sum / _peerReliability.length;
  }

  /// Calcula latência média da rede
  double _calculateAverageLatency() {
    if (_peerLatencies.isEmpty) return 0.0;
    
    final sum = _peerLatencies.values.reduce((a, b) => a + b);
    return sum / _peerLatencies.length;
  }
  
  // ==================== LIMPEZA E MANUTENÇÃO ====================

  /// Limpa dados antigos e otimiza estruturas
  void performMaintenance() {
    final now = DateTime.now();

    // 1. Remove peers expirados do blacklist
    _blacklistedPeers.removeWhere((peerId, blacklistTime) {
      return now.difference(blacklistTime) > _blacklistDuration;
    });

    // 2. Reseta contadores de falhas muito altos (evita overflow e permite nova chance)
    _peerFailures.forEach((peerId, failures) {
      if (failures > _maxFailuresBeforeBlacklist * 2) {
        _peerFailures[peerId] = _maxFailuresBeforeBlacklist;
      }
    });

    // 3. Limita tamanho do histórico de rotas
    _successfulRoutes.forEach((destinationId, routes) {
      if (routes.length > 10) {
        _successfulRoutes[destinationId] = routes.sublist(routes.length - 10);
      }
    });

    logger.info('Manutenção realizada. Blacklist limpo.', tag: 'IntelligentMesh');
    notifyListeners();
  }

  /// Limpa todos os dados do mesh inteligente
  void clearAllData() {
    _successfulRoutes.clear();
    _peerFailures.clear();
    _peerLatencies.clear();
    _peerReliability.clear();
    _blacklistedPeers.clear();
    
    logger.info('Todos os dados limpos', tag: 'IntelligentMesh');
    notifyListeners();
  }
}
