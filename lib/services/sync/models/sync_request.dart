import 'dart:convert';

/// Modelo de requisição de sincronização de estado (Delta Sync)
/// Enviado para um peer para solicitar transações perdidas.
class SyncRequest {
  /// ID do peer que está solicitando a sincronização
  final String requestingPeerId;
  
  /// Mapa de {PeerId: LastSequenceNumber}
  /// Indica a última transação que o peer solicitante possui de cada peer conhecido.
  final Map<String, int> lastKnownSequences;
  
  /// Timestamp da requisição
  final DateTime timestamp;

  SyncRequest({
    required this.requestingPeerId,
    required this.lastKnownSequences,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'requestingPeerId': requestingPeerId,
      'lastKnownSequences': lastKnownSequences,
      'timestamp': timestamp.millisecondsSinceEpoch,
    };
  }

  String toJson() => json.encode(toMap());

  static SyncRequest fromMap(Map<String, dynamic> map) {
    return SyncRequest(
      requestingPeerId: map['requestingPeerId'] as String,
      lastKnownSequences: (map['lastKnownSequences'] as Map<String, dynamic>).map(
        (k, v) => MapEntry(k, v as int),
      ),
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
    );
  }

  static SyncRequest fromJson(String jsonString) => fromMap(json.decode(jsonString));
}
