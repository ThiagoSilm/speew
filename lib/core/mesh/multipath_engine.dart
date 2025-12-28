// ==================== STUBS E MOCKS PARA COMPILAÇÃO ====================
import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';

// '../utils/logger_service.dart'
class LoggerService {
  void info(String message, {String? tag, dynamic error}) => print('[INFO][${tag ?? 'App'}] $message ${error ?? ''}');
  void warn(String message, {String? tag, dynamic error}) => print('[WARN][${tag ?? 'App'}] $message ${error ?? ''}');
  void error(String message, {String? tag, dynamic error}) => print('[ERROR][${tag ?? 'App'}] $message ${error ?? ''}');
  void debug(String message, {String? tag, dynamic error}) {
    if (kDebugMode) print('[DEBUG][${tag ?? 'App'}] $message ${error ?? ''}');
  }
}
final logger = LoggerService();

// '../models/peer.dart'
class Peer {
  final String id;
  Peer({required this.id});
}

// '../reputation/reputation_models.dart'
class ReputationScore {
  final double score;
  ReputationScore({required this.score});
}

// '../reputation/reputation_core.dart'
class ReputationCore {
  final Map<String, ReputationScore> _scores = {
    'peer-A': ReputationScore(score: 0.95), // Excelente
    'peer-B': ReputationScore(score: 0.75), // Bom
    'peer-C': ReputationScore(score: 0.50), // Neutro
    'peer-D': ReputationScore(score: 0.05), // Blacklisted (deve ser evitado)
    'peer-E': ReputationScore(score: 0.80), // Muito Bom
    'peer-F': ReputationScore(score: 0.60), // OK
    'destination-Z': ReputationScore(score: 0.99),
  };

  ReputationScore? getReputationScore(String peerId) {
    return _scores[peerId];
  }
}

// '../p2p/p2p_service.dart'
class P2PService {
  List<List<Peer>> findAllRoutes(String destinationId) {
    // Simulação de rotas para um destino (destination-Z)
    return [
      // Rota 1: Curta e confiável (Alta Reputação)
      [Peer(id: 'peer-A'), Peer(id: 'peer-E'), Peer(id: destinationId)], // Score alto
      // Rota 2: Mais longa, mas decente (Média Reputação)
      [Peer(id: 'peer-B'), Peer(id: 'peer-C'), Peer(id: 'peer-F'), Peer(id: destinationId)], // Score médio
      // Rota 3: Curta, mas com nó Blacklisted (Filtrada pelo MultiPathEngine)
      [Peer(id: 'peer-A'), Peer(id: 'peer-D'), Peer(id: destinationId)], // Nó 'peer-D' tem score baixo
      // Rota 4: Curta e confiável alternativa
      [Peer(id: 'peer-E'), Peer(id: 'peer-A'), Peer(id: destinationId)], // Score alto
    ];
  }

  Future<void> sendData({
    required String peerId,
    required String data,
    Map<String, dynamic>? metadata,
  }) async {
    final rand = Random();
    // Simulação de falha: 'peer-C' é menos confiável
    if (peerId == 'peer-C' && rand.nextDouble() > 0.5) {
      throw Exception('Falha de envio simulada no peer-C');
    }
    // Falha de rede aleatória simulada (10%)
    if (rand.nextDouble() > 0.9) {
       throw Exception('Falha de rede aleatória simulada.');
    }
    logger.debug('P2PService: Dados enviados com sucesso para o próximo hop: $peerId', tag: 'P2P');
  }
}

// ==================== MultiPathEngine ====================

/// Motor de Roteamento Multi-Path.
/// Responsável por enviar dados por múltiplos caminhos simultaneamente para resiliência e latência.
class MultiPathEngine {
  static const int _defaultMaxPaths = 3;
  static int _currentMaxPaths = _defaultMaxPaths;
  final ReputationCore _reputationCore = ReputationCore();
  final P2PService _p2pService;

  MultiPathEngine(this._p2pService);

  /// Envia a mensagem por até [maxPaths] rotas diferentes.
  Future<List<String>> sendMultiPath({
    required String destinationId,
    required String message,
    int maxPaths = _currentMaxPaths,
  }) async {
    // 1. Obter todas as rotas possíveis para o destino
    final allRoutes = _p2pService.findAllRoutes(destinationId);

    if (allRoutes.isEmpty) {
      logger.error('Nenhuma rota encontrada para $destinationId', tag: 'MultiPath');
      return [];
    }

    // 2. Filtrar rotas com nós de baixa reputação (Blacklist)
    const double blacklistThreshold = 0.10;
    
    final filteredRoutes = allRoutes.where((route) {
      // Verifica se algum nó na rota está abaixo do limite (RS < 10%)
      return !route.any((peer) {
        // Assume score neutro (0.5) se não houver registro
        final rs = _reputationCore.getReputationScore(peer.id)?.score ?? 0.5;
        return rs < blacklistThreshold;
      });
    }).toList();

    if (filteredRoutes.isEmpty) {
      logger.warn('Nenhuma rota encontrada após filtragem por reputação (RS > 10%).', tag: 'MultiPath');
      return [];
    }

    // 3. Ordenar e Selecionar as melhores rotas
    // Critério: (Média do RS da rota) * 0.7 + (Inverso do Comprimento da Rota) * 0.3
    filteredRoutes.sort((routeA, routeB) {
      final scoreA = _calculateRouteScore(routeA);
      final scoreB = _calculateRouteScore(routeB);
      return scoreB.compareTo(scoreA); // Ordem decrescente (melhor score primeiro)
    });

    final selectedRoutes = filteredRoutes.take(maxPaths).toList();

    logger.info('Enviando mensagem por ${selectedRoutes.length} rotas selecionadas (Max: $maxPaths).', tag: 'MultiPath');
    

    // 4. Enviar em paralelo (concorrência)
    final results = await Future.wait(selectedRoutes.map((route) {
      final nextHop = route.first;
      return _p2pService.sendData(
        peerId: nextHop.id,
        data: message,
        // Metadados para o serviço de recombinação do receptor
        metadata: {'multi_path_id': _generateMultiPathId(), 'total_paths': selectedRoutes.length},
      ).then((_) => 'Sucesso via ${route.map((p) => p.id).join('->')}')
       .catchError((e) => 'Falha via ${route.map((p) => p.id).join('->')}: $e');
    }));

    // 5. Relatório
    final successfulSends = results.where((r) => r.startsWith('Sucesso')).toList();
    
    if (successfulSends.isNotEmpty) {
      logger.info('Envio Multi-Path concluído. ${successfulSends.length} de ${selectedRoutes.length} caminhos foram bem-sucedidos.', tag: 'MultiPath');
    } else {
      logger.error('Falha crítica Multi-Path: Nenhum caminho conseguiu entregar a mensagem.', tag: 'MultiPath');
    }

    return results;
  }

  /// Calcula um score ponderado para a rota.
  double _calculateRouteScore(List<Peer> route) {
    if (route.isEmpty) return 0.0;

    // 1. Média do Reputation Score (RS)
    final totalRS = route.fold<double>(0.0, (sum, peer) {
      return sum + (_reputationCore.getReputationScore(peer.id)?.score ?? 0.5);
    });
    final avgRS = totalRS / route.length;

    // 2. Inverso do Comprimento da Rota (quanto mais curta, melhor)
    final lengthInverse = 1.0 / route.length; // 1.0/2 = 0.5; 1.0/4 = 0.25

    // Ponderação: 70% Reputação, 30% Comprimento
    const double rsWeight = 0.7;
    const double lengthWeight = 0.3;

    return (avgRS * rsWeight) + (lengthInverse * lengthWeight);
  }

  String _generateMultiPathId() {
    return Random().nextInt(999999).toString();
  }

  /// Define o número máximo de caminhos (usado pelo LowPowerMeshOptimizer, por exemplo).
  static void setMaxPaths(int max) {
    if (max < 1) {
      _currentMaxPaths = 1;
    } else {
      _currentMaxPaths = max;
    }
    logger.info('Número máximo de caminhos Multi-Path definido para: $_currentMaxPaths', tag: 'MultiPathEngine');
  }

  /// Reseta o número máximo de caminhos para o padrão.
  static void resetMaxPaths() {
    _currentMaxPaths = _defaultMaxPaths;
    logger.info('Número máximo de caminhos Multi-Path resetado para: $_currentMaxPaths', tag: 'MultiPathEngine');
  }
}
