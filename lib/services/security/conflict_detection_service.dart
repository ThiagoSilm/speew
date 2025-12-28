import '../../models/coin_transaction.dart';
import '../../models/distributed_ledger_entry.dart';
import '../../models/social_state.dart';
import '../crypto/crypto_service.dart';
import '../ledger/distributed_ledger_service.dart';

/// Tipo de conflito detectado
enum ConflictType {
  duplicateTransaction,
  invalidSignature,
  reputationManipulation,
  stateInconsistency,
  sequenceAnomaly,
  hashMismatch,
  replayAttack,
  invalidTimestamp,
}

/// Resultado de detecção de conflito
class ConflictResult {
  final bool hasConflict;
  final ConflictType? conflictType;
  final String? description;
  final String? suspiciousPeerId;
  final double severityScore; // 0.0 a 1.0

  ConflictResult({
    required this.hasConflict,
    this.conflictType,
    this.description,
    this.suspiciousPeerId,
    this.severityScore = 0.0,
  });

  bool get isCritical => severityScore >= 0.8;
  bool get isModerate => severityScore >= 0.5 && severityScore < 0.8;
  bool get isMinor => severityScore < 0.5;
}

/// Serviço de Detecção Automática de Conflitos
/// Detecta inconsistências, fraudes e tentativas de manipulação na rede
class ConflictDetectionService {
  static final ConflictDetectionService _instance = ConflictDetectionService._internal();
  factory ConflictDetectionService() => _instance;
  ConflictDetectionService._internal();

  final _crypto = CryptoService();
  final _ledger = DistributedLedgerService();
  
  /// Histórico de conflitos detectados
  final List<ConflictResult> _conflictHistory = [];
  
  /// Contadores de conflitos por peer
  final Map<String, int> _peerConflictCounts = {};

  // ==================== DETECÇÃO DE CONFLITOS ====================

  /// Verifica um estado social completo em busca de conflitos
  Future<ConflictResult> detectStateConflicts({
    required SocialState state,
    required String publicKey,
    SocialState? previousState,
  }) async {
    // 1. Verificar assinatura do documento
    final signatureValid = await _crypto.verifySignature(
      state.toCanonicalString(),
      state.documentSignature,
      publicKey,
    );
    
    if (!signatureValid) {
      return _createConflict(
        type: ConflictType.invalidSignature,
        description: 'Assinatura do estado social é inválida',
        peerId: state.userId,
        severity: 1.0,
      );
    }
    
    // 2. Verificar hash do estado
    final calculatedHash = _crypto.sha256Hash(state.toCanonicalString());
    if (calculatedHash != state.stateHash) {
      return _createConflict(
        type: ConflictType.hashMismatch,
        description: 'Hash do estado não corresponde ao conteúdo',
        peerId: state.userId,
        severity: 0.9,
      );
    }
    
    // 3. Verificar cadeia de estados (se temos estado anterior)
    if (previousState != null) {
      if (state.previousStateHash != previousState.stateHash) {
        return _createConflict(
          type: ConflictType.stateInconsistency,
          description: 'Cadeia de estados quebrada',
          peerId: state.userId,
          severity: 0.8,
        );
      }
      
      // Verificar versão sequencial
      if (state.version != previousState.version + 1) {
        return _createConflict(
          type: ConflictType.sequenceAnomaly,
          description: 'Versão do estado não é sequencial',
          peerId: state.userId,
          severity: 0.7,
        );
      }
      
      // Verificar manipulação de reputação
      final reputationDelta = (state.reputationScore - previousState.reputationScore).abs();
      if (reputationDelta > 0.3) {
        return _createConflict(
          type: ConflictType.reputationManipulation,
          description: 'Mudança suspeita de reputação (delta: ${reputationDelta.toStringAsFixed(2)})',
          peerId: state.userId,
          severity: 0.9,
        );
      }
    }
    
    // 4. Verificar timestamp Lamport (não pode ser zero ou negativo)
    if (state.lamportTimestamp.counter <= 0) {
      return _createConflict(
        type: ConflictType.invalidTimestamp,
        description: 'Timestamp Lamport inválido',
        peerId: state.userId,
        severity: 0.6,
      );
    }
    
    return ConflictResult(hasConflict: false);
  }

  /// Verifica uma entrada do ledger em busca de conflitos
  Future<ConflictResult> detectLedgerConflicts({
    required DistributedLedgerEntry entry,
    required String senderPublicKey,
    String? receiverPublicKey,
    List<DistributedLedgerEntry>? existingEntries,
  }) async {
    // 1. Verificar integridade da entrada
    final isValid = await _ledger.verifyLedgerEntry(
      entry: entry,
      senderPublicKey: senderPublicKey,
      receiverPublicKey: receiverPublicKey,
    );
    
    if (!isValid) {
      return _createConflict(
        type: ConflictType.invalidSignature,
        description: 'Entrada do ledger falhou na verificação',
        peerId: entry.senderId,
        severity: 1.0,
      );
    }
    
    // 2. Verificar duplicação de transação
    if (existingEntries != null) {
      final isDuplicate = _ledger.isDuplicateTransaction(
        entry.transactionId,
        existingEntries,
      );
      
      if (isDuplicate) {
        return _createConflict(
          type: ConflictType.duplicateTransaction,
          description: 'Transação duplicada detectada',
          peerId: entry.senderId,
          severity: 0.9,
        );
      }
    }
    
    // 3. Verificar valores suspeitos (quantidade muito alta)
    if (entry.amount > 1000000) {
      return _createConflict(
        type: ConflictType.stateInconsistency,
        description: 'Quantidade de moeda suspeita: ${entry.amount}',
        peerId: entry.senderId,
        severity: 0.7,
      );
    }
    
    return ConflictResult(hasConflict: false);
  }

  /// Verifica uma transação em busca de conflitos
  Future<ConflictResult> detectTransactionConflicts({
    required CoinTransaction transaction,
    required String senderPublicKey,
    List<CoinTransaction>? userTransactionHistory,
  }) async {
    // 1. Verificar assinatura do remetente
    final transactionData = _getTransactionData(transaction);
    final signatureValid = await _crypto.verifySignature(
      transactionData,
      transaction.signatureSender,
      senderPublicKey,
    );
    
    if (!signatureValid) {
      return _createConflict(
        type: ConflictType.invalidSignature,
        description: 'Assinatura da transação é inválida',
        peerId: transaction.senderId,
        severity: 1.0,
      );
    }
    
    // 2. Verificar duplicação
    if (userTransactionHistory != null) {
      final isDuplicate = userTransactionHistory.any(
        (t) => t.transactionId == transaction.transactionId,
      );
      
      if (isDuplicate) {
        return _createConflict(
          type: ConflictType.duplicateTransaction,
          description: 'ID de transação já existe',
          peerId: transaction.senderId,
          severity: 0.9,
        );
      }
    }
    
    // 3. Verificar valores negativos ou zero
    if (transaction.amount <= 0) {
      return _createConflict(
        type: ConflictType.stateInconsistency,
        description: 'Quantidade de transação inválida: ${transaction.amount}',
        peerId: transaction.senderId,
        severity: 0.8,
      );
    }
    
    return ConflictResult(hasConflict: false);
  }

  /// Verifica comparação entre dois estados do mesmo usuário
  Future<ConflictResult> compareStates({
    required SocialState state1,
    required SocialState state2,
  }) async {
    if (state1.userId != state2.userId) {
      return _createConflict(
        type: ConflictType.stateInconsistency,
        description: 'Estados pertencem a usuários diferentes',
        peerId: state1.userId,
        severity: 0.5,
      );
    }
    
    // Verificar se timestamps são consistentes
    final comparison = state1.lamportTimestamp.compareTo(state2.lamportTimestamp);
    
    // Se state1 é mais recente mas tem versão menor, há inconsistência
    if (comparison > 0 && state1.version < state2.version) {
      return _createConflict(
        type: ConflictType.sequenceAnomaly,
        description: 'Timestamp e versão inconsistentes',
        peerId: state1.userId,
        severity: 0.8,
      );
    }
    
    return ConflictResult(hasConflict: false);
  }

  // ==================== AÇÕES CORRETIVAS ====================

  /// Marca um peer como suspeito
  void markPeerAsSuspicious(String peerId) {
    _peerConflictCounts[peerId] = (_peerConflictCounts[peerId] ?? 0) + 1;
  }

  /// Obtém o número de conflitos de um peer
  int getPeerConflictCount(String peerId) {
    return _peerConflictCounts[peerId] ?? 0;
  }

  /// Verifica se um peer deve ser bloqueado (mais de 5 conflitos)
  bool shouldBlockPeer(String peerId) {
    return getPeerConflictCount(peerId) >= 5;
  }

  /// Calcula penalidade de reputação baseada em conflitos
  double calculateReputationPenalty(String peerId) {
    final conflictCount = getPeerConflictCount(peerId);
    if (conflictCount == 0) return 0.0;
    
    // Penalidade cresce exponencialmente
    // 1 conflito = -0.1, 2 = -0.2, 3 = -0.4, 4 = -0.8
    final penalty = 0.1 * (1 << (conflictCount - 1));
    return penalty > 1.0 ? 1.0 : penalty;
  }

  // ==================== HISTÓRICO E ESTATÍSTICAS ====================

  /// Obtém histórico de conflitos
  List<ConflictResult> get conflictHistory => List.unmodifiable(_conflictHistory);

  /// Obtém conflitos de um peer específico
  List<ConflictResult> getPeerConflicts(String peerId) {
    return _conflictHistory
        .where((c) => c.suspiciousPeerId == peerId)
        .toList();
  }

  /// Obtém estatísticas de conflitos
  Map<ConflictType, int> getConflictStatistics() {
    final stats = <ConflictType, int>{};
    for (final conflict in _conflictHistory) {
      if (conflict.conflictType != null) {
        stats[conflict.conflictType!] = (stats[conflict.conflictType!] ?? 0) + 1;
      }
    }
    return stats;
  }

  // ==================== FUNÇÕES AUXILIARES ====================

  /// Cria um resultado de conflito e registra no histórico
  ConflictResult _createConflict({
    required ConflictType type,
    required String description,
    required String peerId,
    required double severity,
  }) {
    final result = ConflictResult(
      hasConflict: true,
      conflictType: type,
      description: description,
      suspiciousPeerId: peerId,
      severityScore: severity,
    );
    
    _conflictHistory.add(result);
    markPeerAsSuspicious(peerId);
    
    return result;
  }

  /// Gera string canônica de uma transação para verificação
  String _getTransactionData(CoinTransaction transaction) {
    return [
      transaction.transactionId,
      transaction.senderId,
      transaction.receiverId,
      transaction.amount.toString(),
      transaction.coinTypeId,
      transaction.timestamp.toIso8601String(),
    ].join('|');
  }

  /// Reseta o serviço (para testes)
  void reset() {
    _conflictHistory.clear();
    _peerConflictCounts.clear();
  }
}
