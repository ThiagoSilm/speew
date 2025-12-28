import 'distributed_ledger_entry.dart';
import 'lamport_clock.dart';

/// Documento de Estado Social Assinado e Sincronizado
/// Representa o estado completo de um usuário na rede distribuída
class SocialState {
  /// ID do usuário
  final String userId;
  
  /// ID efêmero atual (se rotação de identidade estiver ativa)
  final String? ephemeralId;
  
  /// Chave pública atual (Ed25519)
  final String publicKey;
  
  /// Chaves públicas rotacionadas (histórico)
  final List<String> rotatedPublicKeys;
  
  /// Reputação atual (0.0 a 1.0)
  final double reputationScore;
  
  /// Trust score avançado (0.0 a 1.0)
  final double trustScore;
  
  /// Timestamp Lamport do estado
  final LamportTimestamp lamportTimestamp;
  
  /// Timestamp de relógio de parede
  final DateTime wallClockTime;
  
  /// Ledger simbólico parcial (últimas N transações)
  final List<DistributedLedgerEntry> partialLedger;
  
  /// IDs de transações pendentes
  final List<String> pendingTransactionIds;
  
  /// IDs de transações aceitas (últimas N)
  final List<String> acceptedTransactionIds;
  
  /// Lista de peers confiáveis (IDs)
  final List<String> trustedPeers;
  
  /// Lista de peers suspeitos (IDs)
  final List<String> suspiciousPeers;
  
  /// Saldo de moedas por tipo
  final Map<String, double> walletBalances;
  
  /// Assinatura digital do documento completo (Ed25519)
  final String documentSignature;
  
  /// Hash do estado anterior (para formar cadeia)
  final String? previousStateHash;
  
  /// Hash deste estado (SHA-256 de todos os campos)
  final String stateHash;
  
  /// Versão do documento (incrementa a cada atualização)
  final int version;
  
  /// Nonce para prevenir replay
  final String nonce;

  SocialState({
    required this.userId,
    this.ephemeralId,
    required this.publicKey,
    required this.rotatedPublicKeys,
    required this.reputationScore,
    required this.trustScore,
    required this.lamportTimestamp,
    required this.wallClockTime,
    required this.partialLedger,
    required this.pendingTransactionIds,
    required this.acceptedTransactionIds,
    required this.trustedPeers,
    required this.suspiciousPeers,
    required this.walletBalances,
    required this.documentSignature,
    this.previousStateHash,
    required this.stateHash,
    required this.version,
    required this.nonce,
  });

  /// Retorna o ID efetivo (efêmero se disponível, senão userId)
  String get effectiveId => ephemeralId ?? userId;

  /// Verifica se o estado usa identidade rotacionada
  bool get hasRotatedIdentity => ephemeralId != null;

  /// Conta total de transações no ledger parcial
  int get ledgerSize => partialLedger.length;

  /// Conta transações pendentes
  int get pendingCount => pendingTransactionIds.length;

  /// Conta transações aceitas
  int get acceptedCount => acceptedTransactionIds.length;

  /// Verifica se o usuário tem boa reputação (> 0.7)
  bool get hasGoodReputation => reputationScore > 0.7;

  /// Verifica se o usuário é confiável (trust score > 0.8)
  bool get isTrustworthy => trustScore > 0.8;

  /// Converte para Map
  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'ephemeral_id': ephemeralId,
      'public_key': publicKey,
      'rotated_public_keys': rotatedPublicKeys.join(','),
      'reputation_score': reputationScore,
      'trust_score': trustScore,
      'lamport_timestamp': lamportTimestamp.toMap(),
      'wall_clock_time': wallClockTime.toIso8601String(),
      'partial_ledger': partialLedger.map((e) => e.toMap()).toList(),
      'pending_transaction_ids': pendingTransactionIds.join(','),
      'accepted_transaction_ids': acceptedTransactionIds.join(','),
      'trusted_peers': trustedPeers.join(','),
      'suspicious_peers': suspiciousPeers.join(','),
      'wallet_balances': walletBalances,
      'document_signature': documentSignature,
      'previous_state_hash': previousStateHash,
      'state_hash': stateHash,
      'version': version,
      'nonce': nonce,
    };
  }

  /// Cria a partir de Map
  factory SocialState.fromMap(Map<String, dynamic> map) {
    return SocialState(
      userId: map['user_id'] as String,
      ephemeralId: map['ephemeral_id'] as String?,
      publicKey: map['public_key'] as String,
      rotatedPublicKeys: (map['rotated_public_keys'] as String?)?.split(',').where((s) => s.isNotEmpty).toList() ?? [],
      reputationScore: map['reputation_score'] as double,
      trustScore: map['trust_score'] as double,
      lamportTimestamp: LamportTimestamp.fromMap(map['lamport_timestamp'] as Map<String, dynamic>),
      wallClockTime: DateTime.parse(map['wall_clock_time'] as String),
      partialLedger: (map['partial_ledger'] as List<dynamic>)
          .map((e) => DistributedLedgerEntry.fromMap(e as Map<String, dynamic>))
          .toList(),
      pendingTransactionIds: (map['pending_transaction_ids'] as String?)?.split(',').where((s) => s.isNotEmpty).toList() ?? [],
      acceptedTransactionIds: (map['accepted_transaction_ids'] as String?)?.split(',').where((s) => s.isNotEmpty).toList() ?? [],
      trustedPeers: (map['trusted_peers'] as String?)?.split(',').where((s) => s.isNotEmpty).toList() ?? [],
      suspiciousPeers: (map['suspicious_peers'] as String?)?.split(',').where((s) => s.isNotEmpty).toList() ?? [],
      walletBalances: Map<String, double>.from(map['wallet_balances'] as Map),
      documentSignature: map['document_signature'] as String,
      previousStateHash: map['previous_state_hash'] as String?,
      stateHash: map['state_hash'] as String,
      version: map['version'] as int,
      nonce: map['nonce'] as String,
    );
  }

  /// Cria uma cópia com campos atualizados
  SocialState copyWith({
    String? userId,
    String? ephemeralId,
    String? publicKey,
    List<String>? rotatedPublicKeys,
    double? reputationScore,
    double? trustScore,
    LamportTimestamp? lamportTimestamp,
    DateTime? wallClockTime,
    List<DistributedLedgerEntry>? partialLedger,
    List<String>? pendingTransactionIds,
    List<String>? acceptedTransactionIds,
    List<String>? trustedPeers,
    List<String>? suspiciousPeers,
    Map<String, double>? walletBalances,
    String? documentSignature,
    String? previousStateHash,
    String? stateHash,
    int? version,
    String? nonce,
  }) {
    return SocialState(
      userId: userId ?? this.userId,
      ephemeralId: ephemeralId ?? this.ephemeralId,
      publicKey: publicKey ?? this.publicKey,
      rotatedPublicKeys: rotatedPublicKeys ?? this.rotatedPublicKeys,
      reputationScore: reputationScore ?? this.reputationScore,
      trustScore: trustScore ?? this.trustScore,
      lamportTimestamp: lamportTimestamp ?? this.lamportTimestamp,
      wallClockTime: wallClockTime ?? this.wallClockTime,
      partialLedger: partialLedger ?? this.partialLedger,
      pendingTransactionIds: pendingTransactionIds ?? this.pendingTransactionIds,
      acceptedTransactionIds: acceptedTransactionIds ?? this.acceptedTransactionIds,
      trustedPeers: trustedPeers ?? this.trustedPeers,
      suspiciousPeers: suspiciousPeers ?? this.suspiciousPeers,
      walletBalances: walletBalances ?? this.walletBalances,
      documentSignature: documentSignature ?? this.documentSignature,
      previousStateHash: previousStateHash ?? this.previousStateHash,
      stateHash: stateHash ?? this.stateHash,
      version: version ?? this.version,
      nonce: nonce ?? this.nonce,
    );
  }

  /// Gera string canônica para hashing (todos os campos em ordem determinística)
  String toCanonicalString() {
    return [
      userId,
      ephemeralId ?? '',
      publicKey,
      rotatedPublicKeys.join(','),
      reputationScore.toString(),
      trustScore.toString(),
      lamportTimestamp.counter.toString(),
      lamportTimestamp.nodeId,
      wallClockTime.toIso8601String(),
      partialLedger.map((e) => e.entryHash).join(','),
      pendingTransactionIds.join(','),
      acceptedTransactionIds.join(','),
      trustedPeers.join(','),
      suspiciousPeers.join(','),
      walletBalances.entries.map((e) => '${e.key}:${e.value}').join(','),
      previousStateHash ?? '',
      version.toString(),
      nonce,
    ].join('|');
  }

  @override
  String toString() {
    return 'SocialState(userId: $userId, version: $version, reputation: $reputationScore, trust: $trustScore)';
  }
}
