import 'package:flutter_test/flutter_test.dart';
import 'package:speew/core/mesh/mesh_block.dart';
import 'package:speew/core/mesh/mesh_ledger_service.dart';
import 'package:speew/core/crypto/crypto_manager.dart';

void main() {
  group('MeshLedgerService', () {
    test('accepts valid block signed with fallback hash', () async {
      final cm = CryptoManager();
      final ledger = MeshLedgerService(crypto: cm);

      final last = ledger.latest;
      final index = last.index + 1;
      final timestamp = DateTime.now().toIso8601String();
      final emitterId = 'peer1';
      final peerData = {emitterId: 'pubkey_peer1'};

      // prepare data and signature using fallback hash scheme
      final data = MeshLedgerService.dataToSign(MeshBlock(
        index: index,
        timestamp: timestamp,
        peerData: peerData,
        previousHash: last.hash,
        signature: '',
        emitterId: emitterId,
      ));

      final signature = cm.hash(data + peerData[emitterId]!);

      final block = MeshBlock(
        index: index,
        timestamp: timestamp,
        peerData: peerData,
        previousHash: last.hash,
        signature: signature,
        emitterId: emitterId,
      );

      final added = await ledger.addBlock(block);
      expect(added, isTrue);
      expect(ledger.chain.last.hash, equals(block.hash));
    });

    test('rejects block with invalid signature', () async {
      final cm = CryptoManager();
      final ledger = MeshLedgerService(crypto: cm);

      final last = ledger.latest;
      final index = last.index + 1;
      final timestamp = DateTime.now().toIso8601String();
      final emitterId = 'peer2';
      final peerData = {emitterId: 'pubkey_peer2'};

      final block = MeshBlock(
        index: index,
        timestamp: timestamp,
        peerData: peerData,
        previousHash: last.hash,
        signature: 'bad_signature',
        emitterId: emitterId,
      );

      final added = await ledger.addBlock(block);
      expect(added, isFalse);
    });
  });
}
