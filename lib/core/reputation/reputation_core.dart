// rede_p2p_refactored/rede_p2p_refactored/lib/core/reputation/reputation_core.dart

import 'dart:async';
import 'package:rede_p2p_refactored/core/utils/logger_service.dart';
import 'package:rede_p2p_refactored/core/reputation/reputation_models.dart';
import 'package:rede_p2p_refactored/core/reputation/slashing_engine.dart';
import '../storage/database_service.dart'; // Para persistência
// import 'package:rede_p2p_refactored/core/wallet/economy_engine.dart'; // Removido (código morto)

/// O motor central que monitora, pontua e gerencia a reputação dos nós.
class ReputationCore {
  final LoggerService _logger = LoggerService('ReputationCore');
  final SlashingEngine _slashingEngine = SlashingEngine();
  final DatabaseService _db = DatabaseService(); // Serviço de persistência
  final Map<String, ReputationScore> _reputationScores = {};
  final StreamController<ReputationScore> _scoreUpdateController = StreamController.broadcast();

  Stream<ReputationScore> get scoreUpdates => _scoreUpdateController.stream;

  ReputationCore();

  /// Inicializa o monitoramento e carrega scores persistidos.
  Future<void> initialize() async {
    _logger.info('Iniciando Reputation Core...');
    // Implementação V1.2: Carregar scores persistidos do DatabaseService
    final persistedScores = await _db.getAllReputationScores(); // Assumindo método no DatabaseService
    for (final score in persistedScores) {
      _reputationScores[score.peerId] = score;
    }
    _logger.info('Reputation Core iniciado. ${_reputationScores.length} scores carregados.');
  }

  /// Monitora o comportamento dos peers vizinhos e registra eventos.
  void monitorBehavior(ReputationEvent event) {
    _logger.debug('Evento de reputação recebido: ${event.metric} para ${event.peerId}');
    
    // 1. Registrar o evento (para cálculo futuro)
    // Implementação V1.2: Persistir o evento (simulação)
    // await _db.insertReputationEvent(event); // Lógica real de persistência
    
    // 2. Recalcular o Reputation Score (RS)
    final newScore = _calculateReputationScore(event.peerId);
    
    // 3. Verificar e aplicar punição
    _slashingEngine.checkAndApplyPunishment(newScore);

    // 4. Notificar listeners
    _scoreUpdateController.add(newScore);
  }

  // ==================== INTEGRAÇÃO QoS (V1.7) ====================

  /// Recompensa um nó por priorizar tráfego de alta prioridade (CRITICAL/REAL_TIME)
  Future<void> rewardForQoS(String peerId, {double amount = 0.01}) async {
    final currentScore = getReputationScore(peerId);
    if (currentScore == null) return;

    // Aumenta o score em um pequeno valor
    currentScore.score = (currentScore.score + amount).clamp(0.0, 1.0);
    currentScore.lastUpdated = DateTime.now();
    _reputationScores[peerId] = currentScore;
    
    // Persistir e notificar
    // await _db.updateReputationScore(currentScore);
    _scoreUpdateController.add(currentScore);
    _logger.info('Recompensa QoS aplicada a $peerId. Novo RS: ${currentScore.score.toStringAsFixed(4)}', tag: 'QoS');
  }

  /// Penaliza um nó por falhar em processar tráfego de alta prioridade (CRITICAL/REAL_TIME)
  Future<void> penalizeForQoSViolation(String peerId, {double penalty = 0.05}) async {
    final currentScore = getReputationScore(peerId);
    if (currentScore == null) return;

    // Diminui o score em um valor maior
    currentScore.score = (currentScore.score - penalty).clamp(0.0, 1.0);
    currentScore.lastUpdated = DateTime.now();
    _reputationScores[peerId] = currentScore;
    
    // Persistir e notificar
    // await _db.updateReputationScore(currentScore);
    _scoreUpdateController.add(currentScore);
    _logger.warn('Penalidade QoS aplicada a $peerId. Novo RS: ${currentScore.score.toStringAsFixed(4)}', tag: 'QoS');
  }

  /// Calcula o Reputation Score (RS) para um nó conhecido.
  /// Implementa o Algoritmo de Pontuação por Comportamento (Score).
  
  /// Pesos padrão para o cálculo de reputação (Substitui EconomyEngine)
  Map<BehaviorMetric, double> _getDefaultReputationWeights() {
    return {
      BehaviorMetric.relaySuccessRate: 0.20,
      BehaviorMetric.latencyJitter: 0.10,
      BehaviorMetric.availabilityUptime: 0.10,
      BehaviorMetric.packetForgeryAttempts: 0.30,
      BehaviorMetric.sybilDetectionScore: 0.30,
    };
  }
  ReputationScore _calculateReputationScore(String peerId) {
    // Obtém o score atual ou cria um novo
    final currentScore = _reputationScores.putIfAbsent(
      peerId,
      () => ReputationScore(peerId: peerId, lastUpdated: DateTime.now()),
    );

    // 1. Obter os pesos dinâmicos do Economy Engine
    final weights = _getDefaultReputationWeights();

    // 2. Obter as pontuações normalizadas (N_i,j) para cada métrica
    // NOTE: Esta é uma simulação. Na implementação real, os dados viriam de um
    // serviço de monitoramento (ex: MeshService, P2PService).
    final Map<BehaviorMetric, double> normalizedScores = _getNormalizedScores(peerId);

    // 3. Calcular o novo Reputation Score (RS) usando a fórmula ponderada:
    // RS = Σ (N_i,j * W_j)
    double newScore = 0.0;
    weights.forEach((metric, weight) {
      final normalizedScore = normalizedScores[metric] ?? 0.5; // Default para 0.5 se não houver dados
      newScore += normalizedScore * weight;
    });

    // 4. Aplicar um fator de "decay" para que o score não seja estático
    // O novo score é uma média ponderada entre o score antigo e o novo cálculo.
    const double decayFactor = 0.1; // 10% do novo cálculo, 90% do score antigo
    currentScore.score = (currentScore.score * (1.0 - decayFactor) + newScore * decayFactor).clamp(0.0, 1.0);

    currentScore.lastUpdated = DateTime.now();
    _reputationScores[peerId] = currentScore;
    
    // Implementação V1.2: Persistir o score atualizado
    // await _db.updateReputationScore(currentScore); // Lógica real de persistência
    
    _logger.debug('Novo RS para $peerId: ${currentScore.score.toStringAsFixed(4)} (Baseado em $newScore)');
    return currentScore;
  }

  /// Simula a obtenção de pontuações normalizadas (0.0 a 1.0) para cada métrica.
  /// ESTE MÉTODO DEVE SER SUBSTITUÍDO POR CHAMADAS REAIS A SERVIÇOS DE MONITORAMENTO.
  Map<BehaviorMetric, double> _getNormalizedScores(String peerId) {
    // Implementação V1.2: A lógica real de coleta de dados e normalização será em V1.3.
    // Mantém valores simulados para testes.
    return {
      BehaviorMetric.relaySuccessRate: 0.95, // Alto
      BehaviorMetric.latencyJitter: 0.80, // Bom
      BehaviorMetric.availabilityUptime: 0.99, // Excelente
      BehaviorMetric.packetForgeryAttempts: 0.0, // Nenhum
      BehaviorMetric.sybilDetectionScore: 1.0, // Não é Sybil
    };
  }

  /// Retorna o Reputation Score (RS) de um nó.
  ReputationScore? getReputationScore(String peerId) {
    return _reputationScores[peerId];
  }

  /// Compartilha e verifica pontuações com peers de alta reputação.
  Future<void> shareAndVerifyScores(String peerId, ReputationScore score) async {
    // TODO: Implementar lógica de consenso de reputação descentralizada. (Roadmap V1.2)
    _logger.debug('Compartilhando e verificando RS para $peerId...');
  }

  /// Retorna uma lista dos 5 peers com melhor e pior RS.
  Map<String, List<ReputationScore>> getTopAndWorstPeers() {
    final sortedScores = _reputationScores.values.toList()
      ..sort((a, b) => b.score.compareTo(a.score));

    return {
      'best': sortedScores.take(5).toList(),
      'worst': sortedScores.reversed.take(5).toList(),
    };
  }

  // TODO: Implementar o Engine de Moderação de Nós (Node Moderation Engine) (Roadmap V1.2)
}
