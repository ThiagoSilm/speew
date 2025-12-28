/// Modelo de persistência para Unspent Transaction Output (UTXO)
/// Usado para rastrear se um output de transação já foi gasto (prevenção de gasto duplo)
class UTXOEntry {
  /// Hash do output (chave primária)
  final String utxoHash;
  
  /// Valor da transação (em ponto fixo int64)
  final int amount;
  
  /// ID do usuário que pode gastar este UTXO
  final String ownerId;
  
  /// Timestamp de criação
  final DateTime timestamp;

  UTXOEntry({
    required this.utxoHash,
    required this.amount,
    required this.ownerId,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'utxoHash': utxoHash,
      'amount': amount,
      'ownerId': ownerId,
      'timestamp': timestamp.millisecondsSinceEpoch,
    };
  }

  static UTXOEntry fromMap(Map<String, dynamic> map) {
    return UTXOEntry(
      utxoHash: map['utxoHash'] as String,
      amount: map['amount'] as int,
      ownerId: map['ownerId'] as String,
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
    );
  }
}
