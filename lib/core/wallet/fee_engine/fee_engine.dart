import 'dart:math';
import '../../models/transaction.dart';
import '../../models/mesh_status.dart';
import '../../models/reputation.dart';
import '../../config/app_config.dart';

/// Motor de cálculo de taxas dinâmicas para transações.
class FeeEngine {
  static const double _baseFee = 0.01; // Taxa mínima absoluta
  static const double _maxFee = 1.00; // Taxa máxima absoluta
  static const double _congestedFeeMultiplier = 0.05;
  static const double _lowReputationFeeMultiplier = 0.02;
  static const double _highReputationDiscount = 0.10; // 10% de desconto

  /// Calcula a taxa (fee) para uma transação com base em múltiplos fatores.
  static double calculate({
    required Transaction transaction,
    required MeshStatus meshStatus,
    required Reputation reputation,
  }) {
    double fee = _baseFee;

    // 1. Fee baseada na distância em hops
    // Cada hop adiciona uma pequena taxa
    fee += meshStatus.hopsToDestination * 0.005;

    // 2. Fee baseada na reputação do usuário (desconto/aumento)
    if (reputation.score < 30) {
      // Reputação baixa: aumento de taxa
      fee += transaction.amount * _lowReputationFeeMultiplier;
    } else if (reputation.score > 80) {
      // Reputação alta: desconto
      fee -= transaction.amount * _highReputationDiscount;
    }

    // 3. Fee baseada na congestão da rede mesh
    if (meshStatus.isCongested) {
      // Congestão: aumento de taxa
      fee += transaction.amount * _congestedFeeMultiplier;
    }

    // 4. Fee baseada no horário de uso (simulação de picos)
    final hour = DateTime.now().hour;
    if (hour >= 18 || hour <= 8) {
      // Horário de pico (simulado): aumento de 5%
      fee += transaction.amount * 0.05;
    }

    // 5. Fee zero para usuários com reputação perfeita por muito tempo
    if (reputation.score >= 99.0 && reputation.ageInDays > 365) {
      return 0.0;
    }

    // Aplica limites
    fee = max(_baseFee, fee);
    fee = min(_maxFee, fee);

    // Garante que a fee não seja negativa (embora o desconto seja limitado)
    return max(0.0, fee);
  }

  /// Retorna a taxa mínima absoluta.
  static double get baseFee => _baseFee;

  /// Retorna a taxa máxima absoluta.
  static double get maxFee => _maxFee;
}
