import '../../protocols/lamport_clock.dart';
import '../utils/decimal_utils.dart';
import '../utils/bloom_filter_utils.dart';
import 'dart:typed_data';

/// Entrada no ledger distribuído (não-blockchain)
/// Cada entrada representa uma transação simbólica com garantias criptográficas
/// 
/// EVOLUÇÃO INDUSTRIAL:
/// - Usa DecimalUtils (ponto fixo 8 casas) para precisão financeira
/// - Implementa UTXO (Unspent Transaction Output) para prevenir gasto duplo
/// - Todos os campos são final (imutabilidade total)
/// - toCanonicalString() com ordem determinística
/// - Bloom Filter para propagationWitnesses (economia de dados)
class DistributedLedgerEntry {
  // Versão do Protocolo de Rede (II.1)
  static const int protocolVersion = 1;
  // Versão do Schema da Entrada (II.1)
  static const int entrySchemaVersion = 2; // Versão 2 para incluir fee, UTXO, PoW, SeqNonce
  
  /// ID único da entrada no ledger
  final String entryId;
  
  /// Número sequencial da entrada (por usuário)
  final int sequenceNumber;
  
  /// ID da transação associada
  final String transactionId;
  
  /// ID do remetente
  final String senderId;
  
  /// ID do receptor
  final String receiverId;
  
  /// Quantidade transferida (ponto fixo: int64, 8 casas decimais)
  final int amount;

  /// Taxa de transação (ponto fixo: int64, 8 casas decimais)
  final int transactionFee;
  
  /// Tipo de moeda
  final String coinTypeId;
  
  /// Hash do UTXO de entrada (Unspent Transaction Output)
  /// Previne gasto duplo: cada UTXO só pode ser gasto uma vez
  /// Formato: SHA-256 da entrada anterior que gerou este output
  final String? inputUTXOHash;

  /// Prova de Trabalho (PoW) Leve (Hashcash)
  final String proofOfWorkNonce;
  
  /// Timestamp Lamport
  final LamportTimestamp lamportTimestamp;
  
  /// Timestamp de relógio de parede
  final DateTime wallClockTime;
  
  /// Assinatura do remetente
  final String senderSignature;
  
  /// Assinatura do receptor (quando aceita)
  final String? receiverSignature;
  
  /// Hash da entrada anterior (para formar cadeia)
  final String? previousEntryHash;
  
  /// Hash desta entrada (SHA-256 de todos os campos)
  final String entryHash;
  
  /// Bloom Filter dos IDs de peers que propagaram esta entrada
  /// Economia: 1000 IDs (36KB) -> Bloom Filter (~1.2KB) = 97% de redução
  /// Formato: Uint8List serializado
  final Uint8List propagationWitnessesFilter;
  
  /// Número de funções hash usadas no Bloom Filter
  final int propagationWitnessesFilterHashCount;
  
  /// Nonce Sequencial (Seq-Nonce) para prevenir replay attacks
  /// O valor é o número sequencial da última transação vista deste peer.
  final int seqNonce;
  
  /// Status: pending, accepted, rejected, conflicted
  final String status;

  const DistributedLedgerEntry({
    required this.entryId,
    required this.sequenceNumber,
    required this.transactionId,
    required this.senderId,
    required this.receiverId,
    required this.amount,
    required this.transactionFee,
    required this.coinTypeId,
    this.inputUTXOHash,
    required this.proofOfWorkNonce,
    required this.lamportTimestamp,
    required this.wallClockTime,
    required this.senderSignature,
    this.receiverSignature,
    this.previousEntryHash,
    required this.entryHash,
    required this.propagationWitnessesFilter,
    required this.propagationWitnessesFilterHashCount,
    required this.seqNonce,
    required this.status,
  }) : assert(amount > 0, 'Amount must be positive'),
       assert(transactionFee >= 0, 'Fee must be non-negative'),
       assert(seqNonce > 0, 'SeqNonce must be positive');

  /// Verifica se a entrada foi aceita
  bool get isAccepted => status == 'accepted' && receiverSignature != null;

  /// Verifica se há conflito
  bool get hasConflict => status == 'conflicted';

  /// Verifica se a entrada está completa (com ambas as assinaturas)
  bool get isComplete => senderSignature.isNotEmpty && receiverSignature != null;

  /// Converte para Map (Serialização Compacta)
  Map<String, dynamic> toMap() {
    return {
      // Versões (II.1)
      'pv': protocolVersion,
      'esv': entrySchemaVersion,
      
      // Dados (I.1: Compactação)
      'eid': entryId,
      'sn': sequenceNumber,
      'tid': transactionId,
      'sid': senderId,
      'rid': receiverId,
      'amt': amount, // Já é int (ponto fixo)
      'fee': transactionFee, // Já é int (ponto fixo)
      'ctid': coinTypeId,
      'iuh': inputUTXOHash, // Input UTXO Hash
      'pow': proofOfWorkNonce,
      'lt': lamportTimestamp.toMap(),
      'wct': wallClockTime.millisecondsSinceEpoch,
      
      // Criptografia (I.1: Base64/Hex compacto)
      'ss': senderSignature,
      'rs': receiverSignature,
      'peh': previousEntryHash,
      'eh': entryHash,
      
      // Bloom Filter (economia de dados)
      'pwf': propagationWitnessesFilter,
      'pwfhc': propagationWitnessesFilterHashCount,
      
      'sqn': seqNonce,
      'st': status,
    };
  }

  /// Cria a partir de Map (Deserialização Compacta)
  factory DistributedLedgerEntry.fromMap(Map<String, dynamic> map) {
    // II.1: Verificação de Versão
    final pv = map['pv'] as int? ?? protocolVersion;
    final esv = map['esv'] as int? ?? entrySchemaVersion;
    
    if (pv != protocolVersion) {
      throw ArgumentError('DistributedLedgerEntry.fromMap: Protocol version mismatch (expected $protocolVersion, got $pv)');
    }
    if (esv != entrySchemaVersion) {
      throw ArgumentError('DistributedLedgerEntry.fromMap: Schema version mismatch (expected $entrySchemaVersion, got $esv)');
    }
    
    return DistributedLedgerEntry(
      entryId: map['eid'] as String,
      sequenceNumber: map['sn'] as int,
      transactionId: map['tid'] as String,
      senderId: map['sid'] as String,
      receiverId: map['rid'] as String,
      amount: map['amt'] as int,
      transactionFee: map['fee'] as int,
      coinTypeId: map['ctid'] as String,
      inputUTXOHash: map['iuh'] as String?,
      proofOfWorkNonce: map['pow'] as String,
      lamportTimestamp: LamportTimestamp.fromMap(map['lt'] as Map<String, dynamic>),
      wallClockTime: DateTime.fromMillisecondsSinceEpoch(map['wct'] as int),
      senderSignature: map['ss'] as String,
      receiverSignature: map['rs'] as String?,
      previousEntryHash: map['peh'] as String?,
      entryHash: map['eh'] as String,
      propagationWitnessesFilter: map['pwf'] as Uint8List,
      propagationWitnessesFilterHashCount: map['pwfhc'] as int,
      seqNonce: map['sqn'] as int,
      status: map['st'] as String,
    );
  }

  /// Cria uma cópia com campos atualizados
  DistributedLedgerEntry copyWith({
    String? entryId,
    int? sequenceNumber,
    String? transactionId,
    String? senderId,
    String? receiverId,
    int? amount,
    int? transactionFee,
    String? coinTypeId,
    String? inputUTXOHash,
    String? proofOfWorkNonce,
    LamportTimestamp? lamportTimestamp,
    DateTime? wallClockTime,
    String? senderSignature,
    String? receiverSignature,
    String? previousEntryHash,
    String? entryHash,
    Uint8List? propagationWitnessesFilter,
    int? propagationWitnessesFilterHashCount,
    int? seqNonce,
    String? status,
  }) {
    return DistributedLedgerEntry(
      entryId: entryId ?? this.entryId,
      sequenceNumber: sequenceNumber ?? this.sequenceNumber,
      transactionId: transactionId ?? this.transactionId,
      senderId: senderId ?? this.senderId,
      receiverId: receiverId ?? this.receiverId,
      amount: amount ?? this.amount,
      transactionFee: transactionFee ?? this.transactionFee,
      coinTypeId: coinTypeId ?? this.coinTypeId,
      inputUTXOHash: inputUTXOHash ?? this.inputUTXOHash,
      proofOfWorkNonce: proofOfWorkNonce ?? this.proofOfWorkNonce,
      lamportTimestamp: lamportTimestamp ?? this.lamportTimestamp,
      wallClockTime: wallClockTime ?? this.wallClockTime,
      senderSignature: senderSignature ?? this.senderSignature,
      receiverSignature: receiverSignature ?? this.receiverSignature,
      previousEntryHash: previousEntryHash ?? this.previousEntryHash,
      entryHash: entryHash ?? this.entryHash,
      propagationWitnessesFilter: propagationWitnessesFilter ?? this.propagationWitnessesFilter,
      propagationWitnessesFilterHashCount: propagationWitnessesFilterHashCount ?? this.propagationWitnessesFilterHashCount,
      seqNonce: seqNonce ?? this.seqNonce,
      status: status ?? this.status,
    );
  }

  /// Gera string canônica para hashing (todos os campos em ordem determinística)
  /// 
  /// GARANTIAS:
  /// - Ordem determinística (sempre a mesma ordem de campos)
  /// - Inclui apenas dados de consenso
  /// - Exclui metadados variáveis (wallClockTime, assinaturas, witnesses)
  /// - Usa separador | para evitar colisões
  String toCanonicalString() {
    return [
      // II.1: Versionamento
      protocolVersion.toString(),
      entrySchemaVersion.toString(),
      
      // Dados de consenso (ordem fixa)
      entryId,
      sequenceNumber.toString(),
      transactionId,
      senderId,
      receiverId,
      amount.toString(), // Representação int (ponto fixo)
      transactionFee.toString(), // Representação int (ponto fixo)
      coinTypeId,
      inputUTXOHash ?? '', // UTXO Hash (crítico para gasto duplo)
      proofOfWorkNonce,
      lamportTimestamp.counter.toString(),
      lamportTimestamp.nodeId,
      seqNonce.toString(),
      previousEntryHash ?? '',
      
      // NÃO incluir:
      // - wallClockTime (não é parte do consenso)
      // - senderSignature, receiverSignature (não fazem parte do payload)
      // - propagationWitnessesFilter (não é parte do consenso)
      // - status (metadado local)
    ].join('|');
  }
  
  /// Retorna o amount como string decimal (8 casas decimais)
  String get amountDecimal => DecimalUtils.toStringFixed(amount, 8);
  
  /// Retorna o transactionFee como string decimal (8 casas decimais)
  String get transactionFeeDecimal => DecimalUtils.toStringFixed(transactionFee, 8);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DistributedLedgerEntry && other.entryId == entryId;
  }
  
  @override
  int get hashCode => entryId.hashCode;
  
  @override
  String toString() {
    return 'DistributedLedgerEntry(id: $entryId, seq: $sequenceNumber, tx: $transactionId, status: $status)';
  }
}
