import 'package:flutter_test/flutter_test.dart';
import 'package:speew/services/ledger/distributed_ledger_service.dart';
import 'package:speew/core/crypto/crypto_service.dart';
import 'package:speew/core/models/coin_transaction.dart';
import 'package:speew/protocols/lamport_clock.dart';
import 'package:speew/core/config/app_config.dart';
import 'package:speew/core/models/distributed_ledger_entry.dart';

void main() {
  late DistributedLedgerService ledgerService;
  late CryptoService cryptoService;
  late Map<String, String> keyPairA;
  late Map<String, String> keyPairB;
  late CoinTransaction tx;
  late LamportTimestamp timestamp;

  setUp(() async {
    ledgerService = DistributedLedgerService();
    cryptoService = CryptoService();
    ledgerService.reset(); // Garantir estado limpo
    
    keyPairA = await cryptoService.generateKeyPair();
    keyPairB = await cryptoService.generateKeyPair();
    
    tx = CoinTransaction(
      transactionId: cryptoService.generateUniqueId(),
      senderId: 'userA',
      receiverId: 'userB',
      amount: 10.0,
      coinTypeId: AppConfig.defaultCurrency,
      wallClockTime: DateTime.now(),
    );
    
    timestamp = LamportTimestamp(
      counter: 1,
      nodeId: 'nodeX',
      wallClockTime: DateTime.now(),
    );
  });

  group('DistributedLedgerService - Consenso (Mitigações 3, 4, 5)', () {
    
    test('Deve calcular o Hash de Desempate Determinístico-Aleatório (Mitigação 4)', () {
      const entryHash = 'hash_entrada_123';
      const nodeId1 = 'node_a';
      const nodeId2 = 'node_b';
      
      final tiebreaker1 = ledgerService.calculateTiebreakerHash(entryHash, nodeId1);
      final tiebreaker2 = ledgerService.calculateTiebreakerHash(entryHash, nodeId1);
      final tiebreaker3 = ledgerService.calculateTiebreakerHash(entryHash, nodeId2);
      
      // Deve ser determinístico para a mesma entrada/nó
      expect(tiebreaker1, equals(tiebreaker2));
      // Deve ser diferente para nós diferentes
      expect(tiebreaker1, isNot(equals(tiebreaker3)));
      // Deve ter o tamanho de um hash SHA-256
      expect(tiebreaker1, hasLength(64));
    });

    test('Deve rejeitar entrada com Seq-Nonce menor ou igual ao último visto (Mitigação 3)', () async {
      // 1. Cria a primeira entrada (Seq-Nonce = 1)
      final entry1 = await ledgerService.createLedgerEntry(
        transaction: tx,
        lamportTimestamp: timestamp,
        senderPrivateKey: keyPairA['privateKey']!,
        transactionFee: AppConfig.minTransactionFee,
        powDifficulty: AppConfig.powDifficulty,
      );
      
      // Simula a validação da primeira entrada (atualiza _lastSeenSeqNonce para 1)
      final isValid1 = await ledgerService.verifyLedgerEntry(
        entry: entry1,
        senderPublicKey: keyPairA['publicKey']!,
        powDifficulty: AppConfig.powDifficulty,
      );
      expect(isValid1, isTrue, reason: 'A primeira entrada deve ser válida.');
      
      // 2. Cria uma segunda entrada (Seq-Nonce = 2)
      final tx2 = tx.copyWith(transactionId: cryptoService.generateUniqueId());
      final entry2 = await ledgerService.createLedgerEntry(
        transaction: tx2,
        lamportTimestamp: timestamp.copyWith(counter: 2),
        senderPrivateKey: keyPairA['privateKey']!,
        transactionFee: AppConfig.minTransactionFee,
        powDifficulty: AppConfig.powDifficulty,
      );
      
      // 3. Simula uma entrada de replay (Seq-Nonce = 1)
      final replayEntry = entry1.copyWith(
        entryId: cryptoService.generateUniqueId(),
        lamportTimestamp: timestamp.copyWith(counter: 3),
        entryHash: 'fake_hash', // O hash será verificado
      );
      
      // Recalcula o hash para o replayEntry (para passar na verificação de hash)
      final replayEntryData = ledgerService.getSignatureData(
        entryId: replayEntry.entryId,
        sequenceNumber: replayEntry.sequenceNumber,
        transactionId: replayEntry.transactionId,
        senderId: replayEntry.senderId,
        receiverId: replayEntry.receiverId,
        amount: replayEntry.amount,
        transactionFee: replayEntry.transactionFee,
        coinTypeId: replayEntry.coinTypeId,
        powNonce: replayEntry.powNonce,
        lamportTimestamp: replayEntry.lamportTimestamp,
        seqNonce: replayEntry.seqNonce,
      );
      final replaySignature = await cryptoService.signData(replayEntryData, keyPairA['privateKey']!);
      final replayEntryFinal = replayEntry.copyWith(
        senderSignature: replaySignature,
        entryHash: cryptoService.sha256Hash(replayEntry.toCanonicalString()),
      );
      
      // Tenta validar a entrada de replay (Seq-Nonce 1 <= 1)
      final isReplayValid = await ledgerService.verifyLedgerEntry(
        entry: replayEntryFinal,
        senderPublicKey: keyPairA['publicKey']!,
        powDifficulty: AppConfig.powDifficulty,
      );
      
      expect(isReplayValid, isFalse, reason: 'Entrada com Seq-Nonce <= último visto deve ser rejeitada.');
      
      // Tenta validar a entrada correta (Seq-Nonce 2 > 1)
      final isValid2 = await ledgerService.verifyLedgerEntry(
        entry: entry2,
        senderPublicKey: keyPairA['publicKey']!,
        powDifficulty: AppConfig.powDifficulty,
      );
      expect(isValid2, isTrue, reason: 'A segunda entrada deve ser válida.');
    });

    test('Deve rejeitar entrada com Taxa Mínima ou PoW inválidos (Mitigação 5)', () async {
      // 1. Entrada com Taxa Mínima inválida
      final entryLowFee = await ledgerService.createLedgerEntry(
        transaction: tx,
        lamportTimestamp: timestamp,
        senderPrivateKey: keyPairA['privateKey']!,
        transactionFee: AppConfig.minTransactionFee / 2, // Taxa muito baixa
        powDifficulty: AppConfig.powDifficulty,
      );
      
      // A criação falha na validação defensiva (I.1)
      expect(
        () => ledgerService.createLedgerEntry(
          transaction: tx,
          lamportTimestamp: timestamp,
          senderPrivateKey: keyPairA['privateKey']!,
          transactionFee: AppConfig.minTransactionFee / 2,
          powDifficulty: AppConfig.powDifficulty,
        ),
        throwsA(isA<WalletException>()),
        reason: 'A criação deve falhar se a taxa for muito baixa.'
      );
      
      // 2. Simula uma entrada com PoW inválido (nonce vazio)
      final entryInvalidPoW = entryLowFee.copyWith(
        powNonce: '0', // Nonce inválido
        transactionFee: AppConfig.minTransactionFee,
      );
      
      final isPoWValid = await ledgerService.verifyLedgerEntry(
        entry: entryInvalidPoW,
        senderPublicKey: keyPairA['publicKey']!,
        powDifficulty: AppConfig.powDifficulty,
      );
      
      expect(isPoWValid, isFalse, reason: 'Entrada com PoW inválido deve ser rejeitada.');
    });
  });
}
