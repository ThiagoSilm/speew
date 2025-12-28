// rede_p2p_refactored/rede_p2p_refactored/lib/core/reputation/reputation_models.dart

/// Define as métricas de comportamento que são monitoradas para calcular o Reputation Score (RS).
enum BehaviorMetric {
  relaySuccessRate,
  latencyJitter,
  availabilityUptime,
  packetForgeryAttempts,
  sybilDetectionScore,
}

/// Define os tipos de ofensa para o Slashing Engine.
enum OffenseType {
  minorOffense, // RS < 30% (ex: Latência alta)
  majorOffense, // RS < 10% (ex: Baixo Relay Success Rate)
  criticalOffense, // Tentativa de Packet Forgery ou Sybil Attack confirmado
}

/// Define os tipos de punição que podem ser aplicadas.
enum PunishmentType {
  rewardReduction, // Redução de 50% nos Relay Rewards
  stakeFreeze, // Congelamento temporário (24h) de 5% do stake total
  stakeSlashAndDiscard, // Perda de 10% do stake e descarte do nó
}

/// Representa um evento de comportamento de um nó.
class ReputationEvent {
  final String peerId;
  final BehaviorMetric metric;
  final double value;
  final DateTime timestamp;

  ReputationEvent({
    required this.peerId,
    required this.metric,
    required this.value,
    required this.timestamp,
  });

  @override
  String toString() {
    return 'ReputationEvent(peerId: $peerId, metric: $metric, value: $value, timestamp: $timestamp)';
  }
}

/// Representa o Reputation Score (RS) de um nó.
class ReputationScore {
  final String peerId;
  double score; // Valor entre 0.0 e 1.0 (ou 0 a 100, dependendo da escala interna)
  DateTime lastUpdated;

  ReputationScore({
    required this.peerId,
    this.score = 0.5, // Padrão inicial
    required this.lastUpdated,
  });

  @override
  String toString() {
    return 'ReputationScore(peerId: $peerId, score: ${score.toStringAsFixed(2)}, lastUpdated: $lastUpdated)';
  }
}
