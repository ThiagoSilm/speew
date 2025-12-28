import 'dart:convert';

import 'package:speew/core/crypto/crypto_manager.dart';
import 'package:speew/core/crypto/crypto_isolate_service.dart';
import 'package:speew/core/mesh/mesh_block.dart';

class MeshLedgerService {
  final List<MeshBlock> _chain = [];
  final CryptoManager _crypto;
  final CryptoIsolateService _cryptoIsolate = CryptoIsolateService();

  MeshLedgerService({CryptoManager? crypto}) : _crypto = crypto ?? CryptoManager() {
    if (_chain.isEmpty) {
      // Genesis block minimal
      final genesis = MeshBlock(
        index: 0,
        timestamp: DateTime.fromMillisecondsSinceEpoch(0).toIso8601String(),
        peerData: {},
        previousHash: '0',
        signature: '',
      );
      _chain.add(genesis);
    }
  }

  List<MeshBlock> get chain => List.unmodifiable(_chain);

  MeshBlock get latest => _chain.last;

  /// Data used for signing/verifying (deterministic)
  static String dataToSign(MeshBlock b) {
    final sortedPeers = Map.fromEntries(b.peerData.entries.toList()..sort((a, b) => a.key.compareTo(b.key)));
    return jsonEncode({
      'index': b.index,
      'timestamp': b.timestamp,
      'peerData': sortedPeers,
      'previousHash': b.previousHash,
      'emitterId': b.emitterId,
    });
  }

  /// Valida um bloco localmente (estrutura, previousHash e assinatura)
  Future<bool> validateBlock(MeshBlock block) async {
    // previousHash must match latest
    if (block.previousHash != latest.hash) return false;

    // hash must be consistent
    final expectedHash = block.computeHash();
    if (block.hash != expectedHash) return false;

    // signature must validate against the emitter's publicKey
    if (block.signature.isEmpty) return false;

    final data = dataToSign(block);

    final emitterPk = block.peerData[block.emitterId];
    if (emitterPk == null) return false;

    try {
      // Usando Isolate para não travar a UI durante a verificação de assinatura
      final ok = await _cryptoIsolate.verifyAsync(VerifyParams(
        data: data,
        signature: block.signature,
        publicKey: emitterPk,
      ));
      if (ok) return true;
    } catch (_) {
      // fallthrough to fallback
    }

    // Fallback deterministic check (useful for testing / legacy keys):
    // signature == hash(data + emitterPublicKey)
    try {
      final fallback = _crypto.hash(data + emitterPk);
      if (fallback == block.signature) return true;
    } catch (_) {}

    return false;
  }

  /// Tenta adicionar um bloco ao ledger local. Retorna true se aceito.
  Future<bool> addBlock(MeshBlock block) async {
    final isValid = await validateBlock(block);
    if (!isValid) return false;
    _chain.add(block);
    return true;
  }

  /// Tenta mesclar uma cadeia remota (lista de blocos em ordem ascendente).
  /// Retorna número de blocos adicionados.
  Future<int> mergeRemoteChain(List<MeshBlock> remote) async {
    var added = 0;

    // Find first block that links to our latest
    for (final block in remote) {
      if (block.index <= latest.index) continue; // déjà vu

      // quick check: previous hash should match current latest hash
      if (block.previousHash != latest.hash) break; // stop at divergence

      final ok = await validateBlock(block);
      if (!ok) break;
      _chain.add(block);
      added++;
    }

    return added;
  }

  Map<String, dynamic> toJson() => {
        'chain': _chain.map((b) => b.toJson()).toList(),
      };

  factory MeshLedgerService.fromJson(Map<String, dynamic> json, {CryptoManager? crypto}) {
    final svc = MeshLedgerService(crypto: crypto);
    svc._chain.clear();
    final list = (json['chain'] as List<dynamic>? ) ?? [];
    for (final item in list) {
      svc._chain.add(MeshBlock.fromJson(Map<String, dynamic>.from(item as Map)));
    }
    return svc;
  }
}
