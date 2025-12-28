import '../utils/decimal_utils.dart';

/// Modelo de dados para transações da moeda simbólica
/// 
/// EVOLUÇÃO INDUSTRIAL:
/// - Usa DecimalUtils (ponto fixo 8 casas) para precisão financeira
/// - Todos os campos são final (imutabilidade total)
/// - payloadToSign() com ordem determinística para hashing
class CoinTransaction {
  // Versão do Protocolo de Rede (II.1)
  static const int protocolVersion = 1;
  // Versão do Schema da Transação (II.1)
  static const int transactionSchemaVersion = 1;
  
  /// Identificador único da transação
  final String transactionId;
  
  /// Chave pública do usuário que envia a moeda
  final String senderPublicKey;
  
  /// Chave pública do usuário que recebe a moeda
  final String receiverPublicKey;
  
  /// Quantidade de moeda transferida (ponto fixo: int64, 8 casas decimais)
  final int amount;
  
  /// Taxa de transação (ponto fixo: int64, 8 casas decimais)
  final int fee;
  
  /// Timestamp da criação da transação
  final DateTime timestamp;
  
  /// Assinatura Ed25519 do remetente
  final String signature;
  
  /// Memo opcional
  final String? memo;

  const CoinTransaction({
    required this.transactionId,
    required this.senderPublicKey,
    required this.receiverPublicKey,
    required this.amount,
    required this.fee,
    required this.timestamp,
    required this.signature,
    this.memo,
  }) : assert(amount > 0, 'Amount must be positive'),
       assert(fee >= 0, 'Fee must be non-negative');

  /// Factory constructor para criar transação a partir de string decimal
  factory CoinTransaction.fromDecimalAmount({
    required String transactionId,
    required String senderPublicKey,
    required String receiverPublicKey,
    required String amountDecimal,
    required String feeDecimal,
    required DateTime timestamp,
    required String signature,
    String? memo,
  }) {
    return CoinTransaction(
      transactionId: transactionId,
      senderPublicKey: senderPublicKey,
      receiverPublicKey: receiverPublicKey,
      amount: DecimalUtils.fromString(amountDecimal),
      fee: DecimalUtils.fromString(feeDecimal),
      timestamp: timestamp,
      signature: signature,
      memo: memo,
    );
  }

  /// Converte o objeto CoinTransaction para Map (Serialização Compacta)
  Map<String, dynamic> toMap() {
    return {
      // Versões (II.1)
      'pv': protocolVersion,
      'tsv': transactionSchemaVersion,
      
      // Dados (I.1: Compactação)
      'tid': transactionId,
      'spk': senderPublicKey,
      'rpk': receiverPublicKey,
      'amt': amount, // Já é int (ponto fixo)
      'fee': fee, // Já é int (ponto fixo)
      'ts': timestamp.millisecondsSinceEpoch, // Unix timestamp
      'sig': signature,
      'memo': memo,
    };
  }

  /// Cria um objeto CoinTransaction a partir de um Map (Deserialização Compacta)
  factory CoinTransaction.fromMap(Map<String, dynamic> map) {
    // II.1: Verificação de Versão
    final pv = map['pv'] as int? ?? protocolVersion;
    final tsv = map['tsv'] as int? ?? transactionSchemaVersion;
    
    if (pv != protocolVersion) {
      throw ArgumentError('CoinTransaction.fromMap: Protocol version mismatch (expected $protocolVersion, got $pv)');
    }
    if (tsv != transactionSchemaVersion) {
      throw ArgumentError('CoinTransaction.fromMap: Schema version mismatch (expected $transactionSchemaVersion, got $tsv)');
    }
    
    return CoinTransaction(
      transactionId: map['tid'] as String,
      senderPublicKey: map['spk'] as String,
      receiverPublicKey: map['rpk'] as String,
      amount: map['amt'] as int,
      fee: map['fee'] as int,
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['ts'] as int),
      signature: map['sig'] as String,
      memo: map['memo'] as String?,
    );
  }

  /// Gera string canônica para hashing e assinatura
  /// 
  /// GARANTIAS:
  /// - Ordem determinística (sempre a mesma ordem de campos)
  /// - Inclui apenas dados de consenso
  /// - Exclui metadados variáveis (signature, memo)
  String get payloadToSign {
    return [
      // Versões
      protocolVersion.toString(),
      transactionSchemaVersion.toString(),
      
      // Dados de consenso (ordem fixa)
      transactionId,
      senderPublicKey,
      receiverPublicKey,
      amount.toString(), // Representação int (ponto fixo)
      fee.toString(), // Representação int (ponto fixo)
      timestamp.millisecondsSinceEpoch.toString(),
      
      // NÃO incluir: signature, memo
    ].join('|');
  }
  
  /// Retorna o amount como string decimal (8 casas decimais)
  String get amountDecimal => DecimalUtils.toStringFixed(amount, 8);
  
  /// Retorna o fee como string decimal (8 casas decimais)
  String get feeDecimal => DecimalUtils.toStringFixed(fee, 8);
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CoinTransaction && other.transactionId == transactionId;
  }
  
  @override
  int get hashCode => transactionId.hashCode;
  
  @override
  String toString() {
    return 'CoinTransaction(id: $transactionId, from: $senderPublicKey, to: $receiverPublicKey, amount: $amountDecimal, fee: $feeDecimal)';
  }
}
