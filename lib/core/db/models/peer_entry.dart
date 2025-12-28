/// Modelo de persistência para a tabela de vizinhos (Peer Discovery - Kademlia-lite)
class PeerEntry {
  /// ID do peer (chave primária)
  final String peerId;
  
  /// Endereço IP ou hostname
  final String address;
  
  /// Porta de escuta
  final int port;
  
  /// Último contato bem-sucedido (para K-Bucket)
  final DateTime lastSeen;
  
  /// Contagem de falhas de conexão
  final int failureCount;

  PeerEntry({
    required this.peerId,
    required this.address,
    required this.port,
    required this.lastSeen,
    this.failureCount = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'peerId': peerId,
      'address': address,
      'port': port,
      'lastSeen': lastSeen.millisecondsSinceEpoch,
      'failureCount': failureCount,
    };
  }

  static PeerEntry fromMap(Map<String, dynamic> map) {
    return PeerEntry(
      peerId: map['peerId'] as String,
      address: map['address'] as String,
      port: map['port'] as int,
      lastSeen: DateTime.fromMillisecondsSinceEpoch(map['lastSeen'] as int),
      failureCount: map['failureCount'] as int? ?? 0,
    );
  }
}
