import 'dart:typed_data';

/// Representa uma rotação de identidade para privacidade aprimorada
/// Permite que usuários troquem periodicamente suas chaves públicas e IDs efêmeros
/// mantendo a reputação através de mapeamento privado
/// 
/// EVOLUÇÃO INDUSTRIAL:
/// - Todos os campos são final (imutabilidade total)
/// - toCanonicalString() com ordem determinística
/// - Bloom Filter para notifiedPeers (economia de dados)
class IdentityRotation {
  // Versão do Schema da Rotação (II.1)
  static const int rotationSchemaVersion = 2; // Versão 2 para incluir Bloom Filter e LRS
  
  /// ID da rotação
  final String rotationId;
  
  /// ID do usuário original (permanente, privado)
  final String originalUserId;
  
  /// ID efêmero anterior
  final String? previousEphemeralId;
  
  /// ID efêmero atual
  final String currentEphemeralId;
  
  /// Chave pública anterior
  final String? previousPublicKey;
  
  /// Chave pública atual (Ed25519)
  final String currentPublicKey;
  
  /// Timestamp da rotação
  final DateTime rotationTimestamp;
  
  /// Assinatura da rotação com a chave privada anterior (prova de continuidade)
  final String? previousKeySignature;
  
  /// Assinatura da rotação com a chave privada atual
  final String currentKeySignature;
  
  /// Número sequencial da rotação (1, 2, 3...)
  final int rotationSequence;
  
  /// Período de validade da identidade efêmera (em dias)
  final int validityPeriodDays;
  
  /// Data de expiração da identidade efêmera
  final DateTime expirationDate;
  
  /// Mapeamento de reputação (criptografado localmente)
  /// Permite manter a reputação entre rotações
  final double? reputationCarryOver;
  
  /// Status: active, expired, revoked
  final String status;
  
  /// Bloom Filter dos IDs de peers que foram notificados desta rotação
  /// Economia: 1000 IDs (36KB) -> Bloom Filter (~1.2KB) = 97% de redução
  final Uint8List notifiedPeersFilter;
  
  /// Número de funções hash usadas no Bloom Filter
  final int notifiedPeersFilterHashCount;
  
  /// Tag de vinculação (Linkage Tag) para LRS (prova de continuidade)
  final String? linkageTag;

  /// Assinatura de Anel Vinculável (LRS) da rotação
  final String? linkableRingSignature;

  const IdentityRotation({
    required this.rotationId,
    required this.originalUserId,
    this.previousEphemeralId,
    required this.currentEphemeralId,
    this.previousPublicKey,
    required this.currentPublicKey,
    required this.rotationTimestamp,
    this.previousKeySignature,
    required this.currentKeySignature,
    required this.rotationSequence,
    this.validityPeriodDays = 30,
    required this.expirationDate,
    this.reputationCarryOver,
    required this.status,
    required this.notifiedPeersFilter,
    required this.notifiedPeersFilterHashCount,
    this.linkageTag,
    this.linkableRingSignature,
  });

  /// Verifica se a identidade está ativa
  bool get isActive => status == 'active' && !isExpired;

  /// Verifica se a identidade expirou
  bool get isExpired => DateTime.now().isAfter(expirationDate);

  /// Verifica se esta é a primeira rotação
  bool get isFirstRotation => rotationSequence == 1 && previousEphemeralId == null;

  /// Calcula dias restantes até expiração
  int get daysUntilExpiration {
    final now = DateTime.now();
    if (now.isAfter(expirationDate)) return 0;
    return expirationDate.difference(now).inDays;
  }

  /// Verifica se precisa rotacionar em breve (menos de 7 dias)
  bool get needsRotationSoon => daysUntilExpiration <= 7;

  /// Converte para Map (Serialização Compacta)
  Map<String, dynamic> toMap() {
    return {
      'rsv': rotationSchemaVersion,
      'rid': rotationId,
      'ouid': originalUserId,
      'peid': previousEphemeralId,
      'ceid': currentEphemeralId,
      'ppk': previousPublicKey,
      'cpk': currentPublicKey,
      'rts': rotationTimestamp.millisecondsSinceEpoch,
      'pks': previousKeySignature,
      'cks': currentKeySignature,
      'rsq': rotationSequence,
      'vpd': validityPeriodDays,
      'ed': expirationDate.millisecondsSinceEpoch,
      'rco': reputationCarryOver,
      'st': status,
      'npf': notifiedPeersFilter,
      'npfhc': notifiedPeersFilterHashCount,
      'lt': linkageTag,
      'lrs': linkableRingSignature,
    };
  }

  /// Cria a partir de Map (Deserialização Compacta)
  factory IdentityRotation.fromMap(Map<String, dynamic> map) {
    final rsv = map['rsv'] as int? ?? 1; // Compatibilidade com v1
    
    // Se for v1, notifiedPeers é List<String> e precisa ser convertido para Bloom Filter vazio
    final notifiedPeersFilter = (rsv == 1) 
      ? Uint8List(0) // Se for v1, ignoramos a lista e criamos um filtro vazio
      : map['npf'] as Uint8List;
      
    final notifiedPeersFilterHashCount = (rsv == 1) 
      ? 0 
      : map['npfhc'] as int;

    return IdentityRotation(
      rotationId: map['rid'] as String,
      originalUserId: map['ouid'] as String,
      previousEphemeralId: map['peid'] as String?,
      currentEphemeralId: map['ceid'] as String,
      previousPublicKey: map['ppk'] as String?,
      currentPublicKey: map['cpk'] as String,
      rotationTimestamp: DateTime.fromMillisecondsSinceEpoch(map['rts'] as int),
      previousKeySignature: map['pks'] as String?,
      currentKeySignature: map['cks'] as String,
      rotationSequence: map['rsq'] as int,
      validityPeriodDays: map['vpd'] as int? ?? 30,
      expirationDate: DateTime.fromMillisecondsSinceEpoch(map['ed'] as int),
      reputationCarryOver: map['rco'] as double?,
      status: map['st'] as String,
      notifiedPeersFilter: notifiedPeersFilter,
      notifiedPeersFilterHashCount: notifiedPeersFilterHashCount,
      linkageTag: map['lt'] as String?,
      linkableRingSignature: map['lrs'] as String?,
    );
  }

  /// Cria uma cópia com campos atualizados
  IdentityRotation copyWith({
    String? rotationId,
    String? originalUserId,
    String? previousEphemeralId,
    String? currentEphemeralId,
    String? previousPublicKey,
    String? currentPublicKey,
    DateTime? rotationTimestamp,
    String? previousKeySignature,
    String? currentKeySignature,
    int? rotationSequence,
    int? validityPeriodDays,
    DateTime? expirationDate,
    double? reputationCarryOver,
    String? status,
    Uint8List? notifiedPeersFilter,
    int? notifiedPeersFilterHashCount,
    String? linkageTag,
    String? linkableRingSignature,
  }) {
    return IdentityRotation(
      rotationId: rotationId ?? this.rotationId,
      originalUserId: originalUserId ?? this.originalUserId,
      previousEphemeralId: previousEphemeralId ?? this.previousEphemeralId,
      currentEphemeralId: currentEphemeralId ?? this.currentEphemeralId,
      previousPublicKey: previousPublicKey ?? this.previousPublicKey,
      currentPublicKey: currentPublicKey ?? this.currentPublicKey,
      rotationTimestamp: rotationTimestamp ?? this.rotationTimestamp,
      previousKeySignature: previousKeySignature ?? this.previousKeySignature,
      currentKeySignature: currentKeySignature ?? this.currentKeySignature,
      rotationSequence: rotationSequence ?? this.rotationSequence,
      validityPeriodDays: validityPeriodDays ?? this.validityPeriodDays,
      expirationDate: expirationDate ?? this.expirationDate,
      reputationCarryOver: reputationCarryOver ?? this.reputationCarryOver,
      status: status ?? this.status,
      notifiedPeersFilter: notifiedPeersFilter ?? this.notifiedPeersFilter,
      notifiedPeersFilterHashCount: notifiedPeersFilterHashCount ?? this.notifiedPeersFilterHashCount,
      linkageTag: linkageTag ?? this.linkageTag,
      linkableRingSignature: linkableRingSignature ?? this.linkableRingSignature,
    );
  }
  
  /// Gera string canônica para hashing e assinatura
  /// 
  /// GARANTIAS:
  /// - Ordem determinística (sempre a mesma ordem de campos)
  /// - Inclui apenas dados de consenso
  /// - Exclui metadados variáveis (assinaturas, status, notifiedPeers)
  /// - Usa separador | para evitar colisões
  String toCanonicalString() {
    return [
      rotationSchemaVersion.toString(),
      rotationId,
      originalUserId,
      previousEphemeralId ?? '',
      currentEphemeralId,
      previousPublicKey ?? '',
      currentPublicKey,
      rotationTimestamp.millisecondsSinceEpoch.toString(),
      rotationSequence.toString(),
      validityPeriodDays.toString(),
      expirationDate.millisecondsSinceEpoch.toString(),
      linkageTag ?? '',
      
      // NÃO incluir:
      // - previousKeySignature, currentKeySignature, linkableRingSignature (assinaturas)
      // - status (metadado local)
      // - notifiedPeersFilter (não é parte do consenso)
      // - reputationCarryOver (metadado local)
    ].join('|');
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is IdentityRotation && other.rotationId == rotationId;
  }
  
  @override
  int get hashCode => rotationId.hashCode;
  
  @override
  String toString() {
    return 'IdentityRotation(seq: $rotationSequence, ephemeral: $currentEphemeralId, status: $status, expires: ${expirationDate.toIso8601String()})';
  }
}
