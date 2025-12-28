import 'dart:convert';

import 'package:speew/core/crypto/crypto_manager.dart';

class MeshBlock {
  final int index;
  final String timestamp;
  final Map<String, String> peerData; // { "peerId": "publicKey" }
  final String previousHash;
  final String signature; // Assinado pela chave privada do emissor
  final String emitterId; // quem emitiu/assinou o bloco
  String hash;

  MeshBlock({
    required this.index,
    required this.timestamp,
    required this.peerData,
    required this.previousHash,
    required this.signature,
    required this.emitterId,
  }) : hash = '' {
    hash = computeHash();
  }

  String computeHash() {
    final cm = CryptoManager();
    // Normalize peerData so order is deterministic
    final sortedPeers = Map.fromEntries(
      peerData.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
    );

    final payload = jsonEncode({
      'index': index,
      'timestamp': timestamp,
      'peerData': sortedPeers,
      'previousHash': previousHash,
      'signature': signature,
      'emitterId': emitterId,
    });

    return cm.hash(payload);
  }

  Map<String, dynamic> toJson() => {
        'index': index,
        'timestamp': timestamp,
        'peerData': peerData,
        'previousHash': previousHash,
        'signature': signature,
        'emitterId': emitterId,
        'hash': hash,
      };

  factory MeshBlock.fromJson(Map<String, dynamic> json) {
    final block = MeshBlock(
      index: json['index'] as int,
      timestamp: json['timestamp'] as String,
      peerData: Map<String, String>.from(json['peerData'] ?? {}),
      previousHash: json['previousHash'] as String,
      signature: json['signature'] as String,
      emitterId: json['emitterId'] as String,
    );

    if (json.containsKey('hash')) {
      block.hash = json['hash'] as String;
    }

    return block;
  }
  
  /// Map para armazenamento em banco (colunas snake_case)
  Map<String, dynamic> toMap() => {
        'block_index': index,
        'timestamp': timestamp,
        'peer_data': jsonEncode(peerData),
        'prev_hash': previousHash,
        'signature': signature,
        'emitter_id': emitterId,
        'hash': hash,
      };

  /// Construir a partir de um map do banco de dados
  factory MeshBlock.fromMap(Map<String, dynamic> map) {
    final peerDataRaw = map['peer_data'];
    final peerDataMap = peerDataRaw is String && peerDataRaw.isNotEmpty
        ? Map<String, String>.from(jsonDecode(peerDataRaw))
        : <String, String>{};

    final block = MeshBlock(
      index: map['block_index'] as int,
      timestamp: map['timestamp'] as String,
      peerData: peerDataMap,
      previousHash: map['prev_hash'] as String,
      signature: map['signature'] as String,
      emitterId: map['emitter_id'] as String,
    );

    if (map.containsKey('hash')) {
      block.hash = map['hash'] as String;
    }

    return block;
  }
}
