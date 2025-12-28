import 'dart:convert';
import '../../models/distributed_ledger_entry.dart';

/// Modelo de persistência para a Mempool (Memory Pool)
/// Armazena entradas do Ledger que aguardam validação final e inclusão no Ledger principal.
class MempoolEntry {
  /// Hash da entrada do Ledger (usado como ID primário)
  final String entryHash;
  
  /// Entrada completa do Ledger
  final DistributedLedgerEntry entry;
  
  /// Timestamp de quando a transação entrou na Mempool
  final DateTime receivedAt;
  
  /// Prioridade (baseada na taxa de transação)
  final int fee;

  MempoolEntry({
    required this.entryHash,
    required this.entry,
    required this.receivedAt,
    required this.fee,
  });

  Map<String, dynamic> toMap() {
    return {
      'entryHash': entryHash,
      'entryJson': entry.toJson(), // Armazena o JSON da entrada completa
      'receivedAt': receivedAt.millisecondsSinceEpoch,
      'fee': fee,
    };
  }

  static MempoolEntry fromMap(Map<String, dynamic> map) {
    return MempoolEntry(
      entryHash: map['entryHash'] as String,
      entry: DistributedLedgerEntry.fromJson(map['entryJson'] as String),
      receivedAt: DateTime.fromMillisecondsSinceEpoch(map['receivedAt'] as int),
      fee: map['fee'] as int,
    );
  }
}
