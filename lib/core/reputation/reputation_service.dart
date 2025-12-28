import '../../core/utils/logger_service.dart';
import '../../models/user.dart';
import '../storage/database_service.dart';
import 'package:flutter/foundation.dart';

import 'reputation_core.dart';

/// Serviço de reputação para usuários da rede P2P
/// Calcula score baseado em: transações aceitas / total de interações
class ReputationService extends ChangeNotifier {
  static final ReputationService _instance = ReputationService._internal();
  factory ReputationService() => _instance;
  ReputationService._internal();

  final DatabaseService _db = DatabaseService();

  /// Cache de reputações
  final ReputationCore reputationCore = ReputationCore();
  
  /// Cache de reputações
  final Map<String, double> _reputationCache = {};

  // ==================== CÁLCULO DE REPUTAÇÃO ====================

  /// Calcula a reputação de um usuário
  /// Fórmula: score = transações aceitas / total de interações
  
  // TODO: Migrar toda a lógica de cálculo para ReputationCore (Roadmap V1.2)
  // Este método será um wrapper para o ReputationCore.
  @Deprecated('Use reputationCore.getReputationScore(userId).score em V1.2')
  Future<double> calculateReputation(String userId) async {
    try {
      // Verificar cache
      if (_reputationCache.containsKey(userId)) {
        return _reputationCache[userId]!;
      }

      // Obter todas as transações do usuário
      final transactions = await _db.getUserTransactions(userId);

      if (transactions.isEmpty) {
        // Usuário novo sem interações: reputação neutra
        return 0.5;
      }

      // Contar transações aceitas
      final acceptedTransactions = transactions.where((t) => t.status == 'accepted').length;
      
      // Contar total de interações (aceitas + rejeitadas)
      final totalInteractions = transactions.where((t) => 
        t.status == 'accepted' || t.status == 'rejected'
      ).length;

      if (totalInteractions == 0) {
        // Apenas transações pendentes: reputação neutra
        return 0.5;
      }

      // Calcular score
      final score = acceptedTransactions / totalInteractions;

      // Atualizar cache
      _reputationCache[userId] = score;

      // Atualizar no banco de dados
      final user = await _db.getUser(userId);
      if (user != null) {
        final updatedUser = user.copyWith(reputationScore: score);
        await _db.updateUser(updatedUser);
      }

      logger.info('Score calculado para $userId: $score', tag: 'Reputation');
      return score;
    } catch (e) {
      logger.info('Erro ao calcular reputação: $e', tag: 'Reputation');
      return 0.5; // Retorna reputação neutra em caso de erro
    }
  }

  /// Atualiza a reputação de um usuário após uma interação
  Future<void> updateReputationAfterInteraction(String userId) async {
    try {
      final newScore = await calculateReputation(userId);
      notifyListeners();
      logger.info('Reputação atualizada para $userId: $newScore', tag: 'Reputation');
    } catch (e) {
      logger.info('Erro ao atualizar reputação: $e', tag: 'Reputation');
    }
  }

  // ==================== CONSULTAS DE REPUTAÇÃO ====================

  /// Obtém a reputação de um usuário (com cache)
  Future<double> getReputation(String userId) async {
    if (_reputationCache.containsKey(userId)) {
      return _reputationCache[userId]!;
    }
    return await calculateReputation(userId);
  }

  /// Obtém a classificação textual da reputação
  String getReputationLabel(double score) {
    if (score >= 0.9) return 'Excelente';
    if (score >= 0.75) return 'Muito Boa';
    if (score >= 0.6) return 'Boa';
    if (score >= 0.4) return 'Regular';
    if (score >= 0.25) return 'Baixa';
    return 'Muito Baixa';
  }

  /// Obtém a cor associada à reputação
  String getReputationColor(double score) {
    if (score >= 0.75) return 'green';
    if (score >= 0.5) return 'yellow';
    return 'red';
  }

  /// Obtém estatísticas detalhadas de reputação
  Future<Map<String, dynamic>> getReputationStats(String userId) async {
    try {
      final transactions = await _db.getUserTransactions(userId);
      
      final accepted = transactions.where((t) => t.status == 'accepted').length;
      final rejected = transactions.where((t) => t.status == 'rejected').length;
      final pending = transactions.where((t) => t.status == 'pending').length;
      final total = transactions.length;
      
      final score = await getReputation(userId);
      
      return {
        'score': score,
        'label': getReputationLabel(score),
        'color': getReputationColor(score),
        'acceptedCount': accepted,
        'rejectedCount': rejected,
        'pendingCount': pending,
        'totalInteractions': total,
        'acceptanceRate': total > 0 ? (accepted / total * 100).toStringAsFixed(1) : '0.0',
      };
    } catch (e) {
      logger.info('Erro ao obter estatísticas: $e', tag: 'Reputation');
      return {
        'score': 0.5,
        'label': 'Desconhecida',
        'color': 'gray',
        'acceptedCount': 0,
        'rejectedCount': 0,
        'pendingCount': 0,
        'totalInteractions': 0,
        'acceptanceRate': '0.0',
      };
    }
  }

  // ==================== PRIORIZAÇÃO NA MESH ====================

  /// Calcula a prioridade de um usuário na rede mesh
  /// Usuários com maior reputação têm prioridade no roteamento
  Future<int> getMeshPriority(String userId) async {
    try {
      final reputation = await getReputation(userId);
      
      // Converter score (0.0-1.0) para prioridade (0-10)
      final priority = (reputation * 10).round();
      
      return priority;
    } catch (e) {
      logger.info('Erro ao calcular prioridade mesh: $e', tag: 'Reputation');
      return 5; // Prioridade média em caso de erro
    }
  }

  /// Verifica se um usuário deve ter prioridade no roteamento
  Future<bool> shouldPrioritize(String userId) async {
    final priority = await getMeshPriority(userId);
    return priority >= 7; // Priorizar usuários com score >= 0.7
  }

  // ==================== FILTRAGEM E RECOMENDAÇÕES ====================

  /// Verifica se um usuário é confiável para transações
  Future<bool> isTrusted(String userId, {double threshold = 0.6}) async {
    final reputation = await getReputation(userId);
    return reputation >= threshold;
  }

  /// Obtém usuários ordenados por reputação
  Future<List<User>> getUsersByReputation({bool descending = true}) async {
    try {
      final users = await _db.getAllUsers();
      
      // Calcular reputação para todos os usuários
      for (final user in users) {
        await calculateReputation(user.userId);
      }
      
      // Ordenar por reputação
      users.sort((a, b) {
        final scoreA = _reputationCache[a.userId] ?? 0.5;
        final scoreB = _reputationCache[b.userId] ?? 0.5;
        return descending 
          ? scoreB.compareTo(scoreA)
          : scoreA.compareTo(scoreB);
      });
      
      return users;
    } catch (e) {
      logger.info('Erro ao ordenar usuários por reputação: $e', tag: 'Reputation');
      return [];
    }
  }

  /// Sugere se uma transação deve ser aceita baseada na reputação
  Future<Map<String, dynamic>> suggestTransactionAction(String senderId) async {
    try {
      final reputation = await getReputation(senderId);
      final stats = await getReputationStats(senderId);
      
      String suggestion;
      String reason;
      
      if (reputation >= 0.8) {
        suggestion = 'accept';
        reason = 'Usuário com excelente reputação';
      } else if (reputation >= 0.6) {
        suggestion = 'accept';
        reason = 'Usuário com boa reputação';
      } else if (reputation >= 0.4) {
        suggestion = 'review';
        reason = 'Usuário com reputação regular - revisar cuidadosamente';
      } else {
        suggestion = 'reject';
        reason = 'Usuário com baixa reputação';
      }
      
      return {
        'suggestion': suggestion,
        'reason': reason,
        'reputation': reputation,
        'stats': stats,
      };
    } catch (e) {
      logger.info('Erro ao sugerir ação: $e', tag: 'Reputation');
      return {
        'suggestion': 'review',
        'reason': 'Não foi possível avaliar a reputação',
        'reputation': 0.5,
      };
    }
  }

  // ==================== LIMPEZA ====================

  /// Limpa o cache de reputações
  void clearCache() {
    _reputationCache.clear();
    notifyListeners();
    logger.info('Cache limpo', tag: 'Reputation');
  }

  /// Limpa a reputação de um usuário específico do cache
  void clearUserCache(String userId) {
    _reputationCache.remove(userId);
    notifyListeners();
  }

  /// Recalcula todas as reputações
  Future<void> recalculateAllReputations() async {
    try {
      clearCache();
      final users = await _db.getAllUsers();
      
      for (final user in users) {
        await calculateReputation(user.userId);
      }
      
      notifyListeners();
      logger.info('Todas as reputações recalculadas', tag: 'Reputation');
    } catch (e) {
      logger.info('Erro ao recalcular reputações: $e', tag: 'Reputation');
    }
  }
}
