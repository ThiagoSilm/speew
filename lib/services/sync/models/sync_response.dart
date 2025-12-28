import 'dart:convert';
import '../../../core/models/distributed_ledger_entry.dart';

/// Modelo de resposta de sincronização de estado (Delta Sync)
/// Contém as transações (Ledger Entries) que o peer solicitante perdeu.
class SyncResponse {
  /// ID do peer que está respondendo
  final String respondingPeerId;
  
  /// Lista de entradas do ledger que o solicitante perdeu
  final List<DistributedLedgerEntry> missingEntries;
  
  /// Timestamp da resposta
  final DateTime timestamp;

  SyncResponse({
    required this.respondingPeerId,
    required this.missingEntries,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'respondingPeerId': respondingPeerId,
      'missingEntries': missingEntries.map((e) => e.toMap()).toList(),
      'timestamp': timestamp.millisecondsSinceEpoch,
    };
  }

  String toJson() => json.encode(toMap());

  static SyncResponse fromMap(Map<String, dynamic> map) {
    return SyncResponse(
      respondingPeerId: map['respondingPeerId'] as String,
      missingEntries: (map['missingEntries'] as List<dynamic>)
          .map((e) => DistributedLedgerEntry.fromMap(e as Map<String, dynamic>))
          .toList(),
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
    );
  }

  static SyncResponse fromJson(String jsonString) => fromMap(json.decode(jsonString));
}
