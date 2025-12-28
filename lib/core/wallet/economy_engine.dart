import 'dart:math';
import 'package:flutter/material.dart';
import '../reputation/reputation_models.dart';
import '../utils/logger_service.dart';
import '../models/mesh_status.dart';
import '../models/reputation.dart';
import 'tokens/token_registry.dart';
import 'tokens/token_model.dart';

/// Motor de economia autônoma e auto-balanceamento.
class EconomyEngine {
  static Map<BehaviorMetric, double> _reputationWeights = {
    BehaviorMetric.relaySuccessRate: 0.20,
    BehaviorMetric.latencyJitter: 0.10,
    BehaviorMetric.availabilityUptime: 0.10,
    BehaviorMetric.packetForgeryAttempts: 0.30,
    BehaviorMetric.sybilDetectionScore: 0.30,
  };
  static const double _meshSupplyAdjustmentFactor = 0.0001;
  static const double _hopRewardBase = 0.05;

  /// Sincroniza o estado da economia com a rede mesh e ajusta o supply.
  /// Roda em cada node para manter a descentralização.
  static Future<void> syncWithMesh({
    required MeshStatus meshStatus,
    required List<Reputation> peerReputations,
  }) async {
    logger.info('Sincronizando Economy Engine com a rede mesh...', tag: 'Economy');

    // 1. Ajustar supply do MESH baseado na atividade da rede
    await _adjustMeshSupply(meshStatus);

    // 2. Ajustar recompensas do HOP baseado na retransmissão
    await _adjustHopReward(meshStatus);

    // 3. Estimular reputação boa (simulação de emissão de REP)
    await _stimulateGoodReputation(peerReputations);

    logger.info('Sincronização do Economy Engine concluída.', tag: 'Economy');
  }

  /// Ajusta o supply do MESH.
  static Future<void> _adjustMeshSupply(MeshStatus meshStatus) async {
    final meshToken = TokenRegistry.getTokenBySymbol('MESH');
    if (meshToken == null) return;

    // Simulação: Aumenta o supply se a rede estiver muito ativa (muitos peers)
    // e diminui se estiver inativa.
    final activityFactor = meshStatus.connectedPeers.length / 100.0; // Exemplo de fator
    final adjustment = meshToken.supply * activityFactor * _meshSupplyAdjustmentFactor;

    final newSupply = meshToken.supply + adjustment;
    
    TokenRegistry.updateToken(meshToken.copyWith(supply: newSupply));
    logger.debug('Supply MESH ajustado: ${meshToken.supply.toStringAsFixed(2)} -> ${newSupply.toStringAsFixed(2)}', tag: 'Economy');
  }

  /// Ajusta a recompensa do HOP.
  static Future<void> _adjustHopReward(MeshStatus meshStatus) async {
    final hopToken = TokenRegistry.getTokenBySymbol('HOP');
    if (hopToken == null) return;

    // Simulação: Recompensa HOP é inversamente proporcional à congestão.
    // Se a rede estiver congestionada, a recompensa por retransmitir é maior.
    final congestionFactor = meshStatus.isCongested ? 1.5 : 1.0;
    final newReward = _hopRewardBase * congestionFactor;

    TokenRegistry.updateToken(hopToken.copyWith(
      dynamicProperties: {
        'reward_rate': newReward,
        'description': hopToken.dynamicProperties['description'],
      },
    ));
    logger.debug('Recompensa HOP ajustada para: ${newReward.toStringAsFixed(4)}', tag: 'Economy');
  }

  /// Estimula reputação boa (simulação de emissão de REP).
  static Future<void> _stimulateGoodReputation(List<Reputation> peerReputations) async {
    final repToken = TokenRegistry.getTokenBySymbol('REP');
    if (repToken == null) return;

    // Simulação: Aumenta o supply do REP para peers com reputação alta.
    final highReputationPeers = peerReputations.where((rep) => rep.score >= 90).length;
    final repAdjustment = highReputationPeers * 0.01;

    final newSupply = repToken.supply + repAdjustment;
    TokenRegistry.updateToken(repToken.copyWith(supply: newSupply));
    logger.debug('Supply REP ajustado para: ${newSupply.toStringAsFixed(2)}', tag: 'Economy');
  }

  /// Retorna os pesos (W_j) atuais para cada métrica de comportamento.
  /// A soma dos pesos deve ser 1.0.
  static Map<BehaviorMetric, double> getCurrentReputationWeights() {
    return _reputationWeights;
  }

  /// Ajusta os pesos dinamicamente, conforme a necessidade da rede.
  static void adjustReputationWeights(Map<BehaviorMetric, double> newWeights) {
    // TODO: Adicionar lógica de validação para garantir que a soma seja 1.0 (Roadmap V1.1)
    _reputationWeights = newWeights;
    logger.info('Pesos de reputação ajustados dinamicamente.', tag: 'Economy');
  }

  /// Calcula a recompensa HOP por retransmissão.
  static double calculateHopReward(int hops) {
    final hopToken = TokenRegistry.getTokenBySymbol('HOP');
    final rewardRate = hopToken?.dynamicProperties['reward_rate'] as double? ?? _hopRewardBase;
    
    // Recompensa é proporcional ao número de hops (trabalho realizado)
    return rewardRate * hops;
  }
}
