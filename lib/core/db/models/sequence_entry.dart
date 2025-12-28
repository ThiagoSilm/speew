/// Modelo de persistência para rastrear o último número sequencial visto por peer
/// Usado para prevenir Replay Attacks após o reboot do app (Sequence Check)
class SequenceEntry {
  /// ID do peer (chave primária)
  final String peerId;
  
  /// Último número sequencial visto
  final int lastSequenceNumber;
  
  /// Último hash de entrada visto
  final String? lastEntryHash;

  SequenceEntry({
    required this.peerId,
    required this.lastSequenceNumber,
    this.lastEntryHash,
  });

  Map<String, dynamic> toMap() {
    return {
      'peerId': peerId,
      'lastSequenceNumber': lastSequenceNumber,
      'lastEntryHash': lastEntryHash,
    };
  }

  static SequenceEntry fromMap(Map<String, dynamic> map) {
    return SequenceEntry(
      peerId: map['peerId'] as String,
      lastSequenceNumber: map['lastSequenceNumber'] as int,
      lastEntryHash: map['lastEntryHash'] as String?,
    );
  }
}
