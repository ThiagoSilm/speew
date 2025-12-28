import '../../core/utils/logger_service.dart';
import '../../models/trust_event.dart';
import '../../models/user.dart';
import '../reputation/reputation_service.dart';
import '../storage/database_service.dart';
import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';

/// ==================== EXPANSÃO: SISTEMA DE CONFIANÇA AVANÇADO ====================
/// Serviço expandido de confiança com:
/// - Trust score baseado em comportamento
/// - Penalização automática de nós inconsistentes
/// - Registro de eventos de confiança
/// - Integração com mesh routing
///
/// ADICIONADO: Fase 5 - Expansão do sistema de confiança
/// Este módulo EXPANDE o reputation_service.dart existente
class AdvancedTrustService extends ChangeNotifier {
  static final AdvancedTrustService _instance = AdvancedTrustService._internal();
  factory AdvancedTrustService() => _instance;
  AdvancedTrustService._internal();

  final DatabaseService _db = DatabaseService();
  final ReputationService _reputation = ReputationService();

  /// Cache de trust scores
  final Map<String, double> _trustScoreCache = {};

  /// Histórico de eventos por usuário
  final Map<String, List<TrustEvent>> _eventHistory = {};

  /// Threshold de trust score para diferentes ações
  static const double _minTrustForRouting = 0.5;
  static const double _minTrustForTransactions = 0.6;
  static const double _minTrustForFileSharing = 0.55;

  /// Pesos para cálculo de trust score
  static const Map<String, double> _eventWeights = {
    'message_delivered': 0.05,
    'message_failed': -0.10,
    'transaction_accepted': 0.15,
    'transaction_rejected': -0.05,
    'file_shared': 0.10,
    'file_received': 0.08,
    'route_success': 0.12,
    'route_failure': -0.15,
    'suspicious_behavior': -0.30,
    'malicious_activity': -0.50,
  };

  /// Decay factor para eventos antigos (por dia)
  static const double _dailyDecayFactor = 0.98;

  // ==================== CÁLCULO DE TRUST SCORE ====================

  /// Calcula o trust score de um usuário baseado em comportamento
  Future<double> calculateTrustScore(String userId) async {
    try {
      // Verifica cache
      if (_trustScoreCache.containsKey(userId)) {
        return _trustScoreCache[userId]!;
      }

      // Obtém eventos do usuário
      final events = await _db.getTrustEvents(userId);
      
      if (events.isEmpty) {
        // Usuário novo: trust score neutro
        return 0.5;
      }

      double trustScore = 0.5; // Score base
      final now = DateTime.now();

      // Processa cada evento com decay temporal
      for (final event in events) {
        final daysSinceEvent = now.difference(event.timestamp).inDays;
        final decayFactor = pow(_dailyDecayFactor, daysSinceEvent);
        
        // Aplica impacto com decay
        final adjustedImpact = event.impact * decayFactor;
        trustScore += adjustedImpact;
      }

      // Normaliza score entre 0.0 e 1.0
      trustScore = trustScore.clamp(0.0, 1.0);

      // Integra com reputação existente (peso 30%)
      final reputation = await _reputation.getReputation(userId);
      trustScore = (trustScore * 0.7) + (reputation * 0.3);

      // Atualiza cache
      _trustScoreCache[userId] = trustScore;

      // Atualiza no banco
      await _db.updateUserTrustScore(userId, trustScore);

      logger.info('Trust score calculado para $userId: $trustScore', tag: 'AdvancedTrust');
      return trustScore;
    } catch (e) {
      logger.info('Erro ao calcular trust score: $e', tag: 'AdvancedTrust');
      return 0.5;
    }
  }

  /// Obtém o trust score de um usuário (com cache)
  Future<double> getTrustScore(String userId) async {
    if (_trustScoreCache.containsKey(userId)) {
      return _trustScoreCache[userId]!;
    }
    return await calculateTrustScore(userId);
  }

  // ==================== REGISTRO DE EVENTOS ====================

  /// Registra um evento de confiança
  Future<void> recordTrustEvent({
    required String userId,
    required String eventType,
    String? metadata,
    String? severity,
  }) async {
    try {
      // Calcula impacto baseado no tipo de evento
      final impact = _eventWeights[eventType] ?? 0.0;
      
      // Ajusta impacto baseado na severidade
      double adjustedImpact = impact;
      if (severity != null) {
        switch (severity) {
          case 'low':
            adjustedImpact *= 0.5;
            break;
          case 'high':
            adjustedImpact *= 1.5;
            break;
          case 'critical':
            adjustedImpact *= 2.0;
            break;
        }
      }

      // Cria evento
      final event = TrustEvent(
        eventId: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: userId,
        eventType: eventType,
        impact: adjustedImpact,
        timestamp: DateTime.now(),
        metadata: metadata,
        severity: severity ?? 'medium',
      );

      // Salva no banco
      await _db.insertTrustEvent(event);

      // Atualiza histórico
      if (!_eventHistory.containsKey(userId)) {
        _eventHistory[userId] = [];
      }
      _eventHistory[userId]!.add(event);

      // Limita histórico a 100 eventos mais recentes
      if (_eventHistory[userId]!.length > 100) {
        _eventHistory[userId]!.removeAt(0);
      }

      // Invalida cache
      _trustScoreCache.remove(userId);

      // Recalcula trust score
      await calculateTrustScore(userId);

      logger.info('Evento registrado: $eventType para $userId', tag: 'AdvancedTrust');
      notifyListeners();
    } catch (e) {
      logger.info('Erro ao registrar evento: $e', tag: 'AdvancedTrust');
    }
  }

  /// Obtém eventos de confiança de um usuário
  Future<List<TrustEvent>> getUserTrustEvents(String userId, {int? limit}) async {
    try {
      return await _db.getTrustEvents(userId, limit: limit);
    } catch (e) {
      logger.info('Erro ao obter eventos: $e', tag: 'AdvancedTrust');
      return [];
    }
  }

  // ==================== PENALIZAÇÃO AUTOMÁTICA ====================

  /// Detecta e penaliza comportamento inconsistente
  Future<void> detectAndPenalizeInconsistencies(String userId) async {
    try {
      final events = await getUserTrustEvents(userId, limit: 50);
      
      if (events.length < 10) {
        return; // Dados insuficientes
      }

      // Analisa padrões de falhas
      final recentEvents = events.take(20).toList();
      final failureCount = recentEvents.where((e) => e.isNegative).length;
      final failureRate = failureCount / recentEvents.length;

      // Penaliza se taxa de falhas for muito alta
      if (failureRate > 0.6) {
        await recordTrustEvent(
          userId: userId,
          eventType: 'suspicious_behavior',
          severity: 'high',
          metadata: 'Alta taxa de falhas detectada: ${(failureRate * 100).toStringAsFixed(1)}%',
        );
        
        logger.info('Comportamento suspeito detectado para $userId', tag: 'AdvancedTrust');
      }

      // Detecta padrão de falhas consecutivas
      int consecutiveFailures = 0;
      for (final event in recentEvents) {
        if (event.isNegative) {
          consecutiveFailures++;
          if (consecutiveFailures >= 5) {
            await recordTrustEvent(
              userId: userId,
              eventType: 'malicious_activity',
              severity: 'critical',
              metadata: 'Padrão de falhas consecutivas detectado',
            );
            break;
          }
        } else {
          consecutiveFailures = 0;
        }
      }
    } catch (e) {
      logger.info('Erro ao detectar inconsistências: $e', tag: 'AdvancedTrust');
    }
  }

  /// Penaliza um usuário por comportamento específico
  Future<void> penalizeUser(String userId, String reason, {String severity = 'medium'}) async {
    await recordTrustEvent(
      userId: userId,
      eventType: 'suspicious_behavior',
      severity: severity,
      metadata: reason,
    );
  }

  // ==================== VERIFICAÇÕES DE CONFIANÇA ====================

  /// Verifica se um usuário é confiável para roteamento
  Future<bool> isTrustedForRouting(String userId) async {
    final trustScore = await getTrustScore(userId);
    return trustScore >= _minTrustForRouting;
  }

  /// Verifica se um usuário é confiável para transações
  Future<bool> isTrustedForTransactions(String userId) async {
    final trustScore = await getTrustScore(userId);
    return trustScore >= _minTrustForTransactions;
  }

  /// Verifica se um usuário é confiável para compartilhamento de arquivos
  Future<bool> isTrustedForFileSharing(String userId) async {
    final trustScore = await getTrustScore(userId);
    return trustScore >= _minTrustForFileSharing;
  }

  /// Obtém nível de confiança textual
  String getTrustLevel(double trustScore) {
    if (trustScore >= 0.9) return 'Muito Alto';
    if (trustScore >= 0.75) return 'Alto';
    if (trustScore >= 0.6) return 'Médio-Alto';
    if (trustScore >= 0.4) return 'Médio';
    if (trustScore >= 0.25) return 'Baixo';
    return 'Muito Baixo';
  }

  // ==================== INTEGRAÇÃO COM MESH ROUTING ====================

  /// Calcula prioridade de roteamento baseada em confiança
  Future<int> getRoutingPriority(String userId) async {
    try {
      final trustScore = await getTrustScore(userId);
      final reputation = await _reputation.getReputation(userId);
      
      // Combina trust score e reputação
      final combinedScore = (trustScore * 0.6) + (reputation * 0.4);
      
      // Converte para prioridade (0-10)
      return (combinedScore * 10).round().clamp(0, 10);
    } catch (e) {
      logger.info('Erro ao calcular prioridade de roteamento: $e', tag: 'AdvancedTrust');
      return 5;
    }
  }

  /// Obtém lista de usuários confiáveis para roteamento
  Future<List<String>> getTrustedPeersForRouting(List<String> availablePeers) async {
    final trustedPeers = <String>[];
    
    for (final peerId in availablePeers) {
      if (await isTrustedForRouting(peerId)) {
        trustedPeers.add(peerId);
      }
    }
    
    // Ordena por trust score
    trustedPeers.sort((a, b) async {
      final scoreA = await getTrustScore(a);
      final scoreB = await getTrustScore(b);
      return scoreB.compareTo(scoreA);
    });
    
    return trustedPeers;
  }

  // ==================== ESTATÍSTICAS E ANÁLISE ====================

  /// Obtém estatísticas detalhadas de confiança
  Future<Map<String, dynamic>> getTrustStats(String userId) async {
    try {
      final events = await getUserTrustEvents(userId);
      final trustScore = await getTrustScore(userId);
      
      final positiveEvents = events.where((e) => e.isPositive).length;
      final negativeEvents = events.where((e) => e.isNegative).length;
      final criticalEvents = events.where((e) => e.isCritical).length;
      
      // Calcula tendência (últimos 7 dias vs 7 dias anteriores)
      final now = DateTime.now();
      final last7Days = events.where((e) => 
        now.difference(e.timestamp).inDays <= 7
      ).toList();
      final previous7Days = events.where((e) {
        final days = now.difference(e.timestamp).inDays;
        return days > 7 && days <= 14;
      }).toList();
      
      final recentAvg = last7Days.isEmpty ? 0.0 : 
        last7Days.map((e) => e.impact).reduce((a, b) => a + b) / last7Days.length;
      final previousAvg = previous7Days.isEmpty ? 0.0 :
        previous7Days.map((e) => e.impact).reduce((a, b) => a + b) / previous7Days.length;
      
      final trend = recentAvg - previousAvg;
      
      return {
        'trustScore': trustScore,
        'trustLevel': getTrustLevel(trustScore),
        'totalEvents': events.length,
        'positiveEvents': positiveEvents,
        'negativeEvents': negativeEvents,
        'criticalEvents': criticalEvents,
        'trend': trend > 0 ? 'improving' : (trend < 0 ? 'declining' : 'stable'),
        'trendValue': trend,
        'trustedForRouting': await isTrustedForRouting(userId),
        'trustedForTransactions': await isTrustedForTransactions(userId),
        'trustedForFileSharing': await isTrustedForFileSharing(userId),
      };
    } catch (e) {
      logger.info('Erro ao obter estatísticas: $e', tag: 'AdvancedTrust');
      return {};
    }
  }

  /// Obtém usuários mais confiáveis
  Future<List<User>> getMostTrustedUsers({int limit = 10}) async {
    try {
      final users = await _db.getAllUsers();
      
      // Calcula trust score para todos
      for (final user in users) {
        await calculateTrustScore(user.userId);
      }
      
      // Ordena por trust score
      users.sort((a, b) {
        final scoreA = _trustScoreCache[a.userId] ?? 0.5;
        final scoreB = _trustScoreCache[b.userId] ?? 0.5;
        return scoreB.compareTo(scoreA);
      });
      
      return users.take(limit).toList();
    } catch (e) {
      logger.info('Erro ao obter usuários mais confiáveis: $e', tag: 'AdvancedTrust');
      return [];
    }
  }

  // ==================== LIMPEZA E MANUTENÇÃO ====================

  /// Limpa eventos antigos (mais de 90 dias)
  Future<void> cleanOldEvents() async {
    try {
      final cutoffDate = DateTime.now().subtract(const Duration(days: 90));
      await _db.deleteTrustEventsBefore(cutoffDate);
      
      logger.info('Eventos antigos removidos', tag: 'AdvancedTrust');
    } catch (e) {
      logger.info('Erro ao limpar eventos antigos: $e', tag: 'AdvancedTrust');
    }
  }

  /// Recalcula todos os trust scores
  Future<void> recalculateAllTrustScores() async {
    try {
      _trustScoreCache.clear();
      final users = await _db.getAllUsers();
      
      for (final user in users) {
        await calculateTrustScore(user.userId);
      }
      
      notifyListeners();
      logger.info('Todos os trust scores recalculados', tag: 'AdvancedTrust');
    } catch (e) {
      logger.info('Erro ao recalcular trust scores: $e', tag: 'AdvancedTrust');
    }
  }

  /// Limpa cache
  void clearCache() {
    _trustScoreCache.clear();
    _eventHistory.clear();
    notifyListeners();
  }
}
