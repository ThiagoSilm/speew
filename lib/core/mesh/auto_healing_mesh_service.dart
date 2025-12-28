// ==================== STUBS E MOCKS PARA COMPILAÇÃO ====================

// Baseado em importações anteriores
import 'dart:async';
import 'package:flutter/foundation.dart';

// logger_service.dart (Mock)
class LoggerService {
  void info(String message, {String? tag, dynamic error}) => print('[INFO][${tag ?? 'App'}] $message ${error ?? ''}');
  void warn(String message, {String? tag, dynamic error}) => print('[WARN][${tag ?? 'App'}] $message ${error ?? ''}');
  void error(String message, {String? tag, dynamic error}) => print('[ERROR][${tag ?? 'App'}] $message ${error ?? ''}');
  void debug(String message, {String? tag, dynamic error}) {
    if (kDebugMode) print('[DEBUG][${tag ?? 'App'}] $message ${error ?? ''}');
  }
}
final logger = LoggerService();

// peer.dart (Modelo)
class Peer {
  final String id;
  final String displayName;
  final int latency;

  Peer({required this.id, required this.displayName, this.latency = 0});
  String get peerId => id; 
}

// reputation_core.dart (Stub)
class ReputationScore {
  final double score;
  final int latency; // em ms
  ReputationScore({required this.score, required this.latency});
}

class ReputationCore {
  final Map<String, ReputationScore> _scores = {};

  ReputationCore() {
    // Inicializa com dados mock para teste
    _scores['mock-peer-slow'] = ReputationScore(score: 0.85, latency: 600);
    _scores['mock-peer-good'] = ReputationScore(score: 0.95, latency: 120);
  }

  ReputationScore? getReputationScore(String peerId) {
    return _scores[peerId];
  }

  void penalizePeer(String peerId, {String? penaltyType, double amount = 0.10}) {
    final current = _scores[peerId];
    if (current != null) {
      final newScore = (current.score - amount).clamp(0.0, 1.0);
      _scores[peerId] = ReputationScore(score: newScore, latency: current.latency);
      logger.warn('Penalidade aplicada a $peerId. Score: ${newScore.toStringAsFixed(2)}', tag: 'ReputationCore');
    }
  }
}

// p2p_service.dart (Stub)
class P2PService {
  List<Peer> getConnectedPeers() {
    return [
      Peer(id: 'mock-peer-slow', displayName: 'Slow Peer', latency: 600),
      Peer(id: 'mock-peer-good', displayName: 'Good Peer', latency: 120),
      Peer(id: 'mock-peer-3', displayName: 'Peer 3', latency: 80),
      Peer(id: 'mock-peer-4', displayName: 'Peer 4', latency: 150),
      Peer(id: 'mock-peer-5', displayName: 'Peer 5', latency: 90),
      Peer(id: 'mock-peer-6', displayName: 'Peer 6', latency: 110),
      Peer(id: 'mock-peer-7', displayName: 'Peer 7', latency: 130),
      Peer(id: 'mock-peer-8', displayName: 'Peer 8', latency: 70),
    ];
  }

  List<Peer> getRecentlyDroppedPeers() {
    // 20% de churn = 2 nós caídos (8 conectados + 2 caídos = 10 total)
    return [
      Peer(id: 'dropped-1', displayName: 'Dropped 1'),
      Peer(id: 'dropped-2', displayName: 'Dropped 2'),
    ];
  }

  Future<bool> tryReconnect(String peerId) async {
    logger.info('P2PService: Tentando reconectar com $peerId (Soft Heal)', tag: 'P2P');
    return true;
  }

  void forceRouteRecalculation() {
    logger.warn('P2PService: Re-propagação de rotas forçada (Aggressive Heal)', tag: 'P2P');
  }

  void discoverNewPeers({required int count}) {
    logger.info('P2PService: Iniciando descoberta de $count novos peers', tag: 'P2P');
  }

  void markRouteAsSlow(String peerId) {
    logger.warn('P2PService: Marcando rota para $peerId como lenta (evitar)', tag: 'P2P');
  }
}

// ==================== AutoHealingMeshService ====================

class AutoHealingMeshService {
  final P2PService _p2pService;
  final ReputationCore _reputationCore;
  final Duration _healthCheckInterval = const Duration(seconds: 10);
  Timer? _healthCheckTimer;

  AutoHealingMeshService(this._p2pService, this._reputationCore);

  /// Inicia o monitoramento da malha.
  void startMonitoring() {
    if (_healthCheckTimer != null) return;

    logger.info('Iniciando monitoramento de Auto-Healing da malha.', tag: 'AutoHealing');
    _healthCheckTimer = Timer.periodic(_healthCheckInterval, (timer) {
      _performHealthCheck();
    });
  }

  /// Para o monitoramento da malha.
  void stopMonitoring() {
    _healthCheckTimer?.cancel();
    _healthCheckTimer = null;
    logger.info('Monitoramento de Auto-Healing da malha parado.', tag: 'AutoHealing');
  }

  /// Executa a verificação de saúde e inicia a cura se necessário.
  void _performHealthCheck() {
    final connectedPeers = _p2pService.getConnectedPeers();
    final recentlyDroppedPeers = _p2pService.getRecentlyDroppedPeers();
    final totalPeers = connectedPeers.length + recentlyDroppedPeers.length;

    if (totalPeers == 0) return;

    // Churn Rate: Nós que caíram / Total de Nós (Conectados + Caídos)
    final churnRate = recentlyDroppedPeers.length / totalPeers;

    logger.debug('Peers conectados: ${connectedPeers.length}. Churn Rate: ${(churnRate * 100).toStringAsFixed(2)}%', tag: 'AutoHealing');

    // Critério de Sucesso Inegociável: Provar que a rede suporta churn de 20%
    // A rede deve ser capaz de se curar de forma agressiva se o churn for alto.
    if (churnRate >= 0.20) {
      logger.warn('ALERTA DE CHURN: Taxa de churn (${(churnRate * 100).toStringAsFixed(0)}%) atingiu ou excedeu 20%. Iniciando Auto-Healing Agressivo.', tag: 'AutoHealing');
      
      _aggressivelyHealMesh(recentlyDroppedPeers);
    } else if (recentlyDroppedPeers.isNotEmpty) {
      logger.info('Churn detectado, mas abaixo do limite. Iniciando Auto-Healing Suave.', tag: 'AutoHealing');
      _softHealMesh(recentlyDroppedPeers);
    }

    // Verificação de lentidão (parte do critério de otimização de gargalos)
    _checkSlowPeers(connectedPeers);
  }

  /// Tenta reconectar ou encontrar novas rotas para os nós perdidos.
  void _softHealMesh(List<Peer> droppedPeers) {
    for (final peer in droppedPeers) {
      logger.debug('Tentando reconectar com o peer perdido: ${peer.id}', tag: 'AutoHealing');
      _p2pService.tryReconnect(peer.id);
    }
  }

  /// Inicia uma re-propagação de rotas e reavaliação de vizinhos.
  void _aggressivelyHealMesh(List<Peer> droppedPeers) {
    logger.warn('Executando re-propagação de rotas e reavaliação de vizinhos.', tag: 'AutoHealing');
    _p2pService.forceRouteRecalculation();
    // Tenta substituir os peers perdidos e encontrar novos
    _p2pService.discoverNewPeers(count: droppedPeers.length * 2);
  }

  /// Verifica peers com latência alta e ajusta o Reputation Score.
  void _checkSlowPeers(List<Peer> connectedPeers) {
    for (final peer in connectedPeers) {
      final rs = _reputationCore.getReputationScore(peer.id);
      // Critério: latência consistentemente acima de 500ms E reputação ainda acima de 0.10
      if (rs != null && rs.latency > 500 && rs.score > 0.10) {
        logger.warn('Peer ${peer.id} detectado como lento (Latência: ${rs.latency}ms). Reduzindo score de reputação.', tag: 'AutoHealing');
        // Penalidade suave por lentidão
        _reputationCore.penalizePeer(peer.id, penaltyType: 'latency_degradation', amount: 0.05);
        _p2pService.markRouteAsSlow(peer.id); // Informa o P2PService para evitar rotas
      }
    }
  }

  void dispose() {
    _healthCheckTimer?.cancel();
  }
}
