import '../../core/models/coin_transaction.dart';
import '../../core/models/distributed_ledger_entry.dart';
import '../../protocols/lamport_clock.dart';
import '../crypto/crypto_service.dart';
import '../../core/config/app_config.dart';
import '../../core/errors/exceptions.dart';
import '../../core/utils/decimal_utils.dart';
import '../../core/utils/bloom_filter_utils.dart';
import '../../core/db/database_service.dart';
import '../../core/db/models/utxo_entry.dart';
import '../../core/db/models/sequence_entry.dart';
import '../sync/sync_service.dart'; // Import do SyncService
import 'mempool_service.dart'; // Import do MempoolService
import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';

/// Serviço de Ledger Simbólico Distribuído (não-blockchain)
/// Gerencia transações com garantias criptográficas sem custo computacional de blockchain
/// 
/// EVOLUÇÃO INDUSTRIAL:
/// - Operações atômicas com rollback automático (via DB Transaction)
/// - UTXO (Unspent Transaction Output) para prevenir gasto duplo (via DB)
/// - Ordem de validação otimizada (Seq-Nonce antes de PoW)
/// - Bloom Filters para economia de dados
class DistributedLedgerService {
  static final DistributedLedgerService _instance = DistributedLedgerService._internal();
  factory DistributedLedgerService() => _instance;
  DistributedLedgerService._internal();

  final _crypto = CryptoService();
  final _uuid = const Uuid();
  final _db = DatabaseService();
  final _syncService = SyncService(); // Instância do SyncService
  final _mempoolService = MempoolService(); // Instância do MempoolService
  
  // Os caches em memória são mantidos para otimização, mas a verdade está no DB
  final Map<String, int> _lastSeenSeqNonce = {};
  
  // ==================== CRIAÇÃO DE ENTRADAS ====================

  /// Cria uma nova entrada no ledger a partir de uma transação
  Future<DistributedLedgerEntry> createLedgerEntry({
    required CoinTransaction transaction,
    required LamportTimestamp lamportTimestamp,
    required String senderPrivateKey,
    required int powDifficulty,
    String? inputUTXOHash, // UTXO de entrada (previne gasto duplo)
    String? receiverPrivateKey,
  }) async {
    // I.1: Validação Defensiva
    if (transaction.amount <= 0) {
      throw WalletException.invalidTransaction('Montante da transação deve ser positivo.');
    }
    if (transaction.fee < 0) {
      throw WalletException.invalidTransaction('Taxa de transação não pode ser negativa.');
    }
    
    final minFee = DecimalUtils.fromString(AppConfig.minTransactionFee.toString());
    if (transaction.fee < minFee) {
      throw WalletException.invalidTransaction(
        'Taxa de transação (${transaction.feeDecimal}) é menor que a mínima (${AppConfig.minTransactionFee}).'
      );
    }
    
    // UTXO: Verifica se o input já foi gasto (gasto duplo)
    if (inputUTXOHash != null && !await _db.isUTXOAvailable(inputUTXOHash)) {
      throw WalletException.invalidTransaction('UTXO já foi gasto (gasto duplo detectado): $inputUTXOHash');
    }
    
    // Início da Transação Atômica do DB
    return await _db.transaction((txn) async {
      // 1. Obter Sequence Number (com lock implícito do DB)
      final senderId = transaction.senderPublicKey;
      final currentSequence = await _db.getSequenceEntry(senderId);
      final sequenceNumber = (currentSequence?.lastSequenceNumber ?? 0) + 1;
      final previousHash = currentSequence?.lastEntryHash;
      
      final seqNonce = sequenceNumber;
      final entryId = _uuid.v4();
      
      // 2. Gerar Prova de Trabalho (PoW) Leve (Hashcash)
      final powData = '$entryId:$senderId:${lamportTimestamp.counter}';
      final proofOfWorkNonce = await _crypto.generatePoW(powData, powDifficulty);
      
      // 3. UTXO: Marcar como gasto (spendUTXO)
      if (inputUTXOHash != null) {
        await _db.spendUTXO(inputUTXOHash);
      }
      
      // 4. Assinar com chave do remetente
      final senderData = _getSignatureData(
        entryId: entryId,
        sequenceNumber: sequenceNumber,
        transactionId: transaction.transactionId,
        senderId: senderId,
        receiverId: transaction.receiverPublicKey,
        amount: transaction.amount,
        transactionFee: transaction.fee,
        coinTypeId: 'default',
        inputUTXOHash: inputUTXOHash,
        proofOfWorkNonce: proofOfWorkNonce,
        lamportTimestamp: lamportTimestamp,
        seqNonce: seqNonce,
      );
      
      final senderSignature = await _crypto.signData(senderData, senderPrivateKey);
      
      // 5. Assinar com chave do receptor (se fornecida)
      String? receiverSignature;
      if (receiverPrivateKey != null) {
        receiverSignature = await _crypto.signData(senderData, receiverPrivateKey);
      }
      
      // 6. Criar Bloom Filter vazio para propagation witnesses
      final emptyFilter = Uint8List(0);
      
      // 7. Criar entrada completa
      final entry = DistributedLedgerEntry(
        entryId: entryId,
        sequenceNumber: sequenceNumber,
        transactionId: transaction.transactionId,
        senderId: senderId,
        receiverId: transaction.receiverPublicKey,
        amount: transaction.amount,
        transactionFee: transaction.fee,
        coinTypeId: 'default',
        inputUTXOHash: inputUTXOHash,
        proofOfWorkNonce: proofOfWorkNonce,
        lamportTimestamp: lamportTimestamp,
        wallClockTime: DateTime.now(),
        senderSignature: senderSignature,
        receiverSignature: receiverSignature,
        previousEntryHash: previousHash,
        entryHash: '', // Será calculado
        propagationWitnessesFilter: emptyFilter,
        propagationWitnessesFilterHashCount: 0,
        seqNonce: seqNonce,
        status: receiverSignature != null ? 'accepted' : 'pending',
      );
      
      // 8. Calcular hash da entrada
      final entryHash = _calculateEntryHash(entry);
      final finalEntry = entry.copyWith(entryHash: entryHash);
      
      // 9. Persistir o novo SequenceEntry
      final newSequence = SequenceEntry(
        peerId: senderId,
        lastSequenceNumber: sequenceNumber,
        lastEntryHash: entryHash,
      );
      await _db.saveSequenceEntry(newSequence);
      
      // 10. Criar novo UTXO (o output desta transação)
      final newUTXO = UTXOEntry(
        utxoHash: entryHash, // O hash da entrada é o hash do output
        amount: entry.amount,
        ownerId: entry.receiverId,
        timestamp: entry.wallClockTime,
      );
      await _db.saveUTXO(newUTXO);
      
      // 11. Atualizar cache (para otimização)
      _lastSeenSeqNonce[senderId] = seqNonce;
      
      // 12. Adicionar à Mempool (antes de iniciar o Gossip)
      await _mempoolService.addEntry(finalEntry);
      
      // 13. Iniciar Gossip (retransmissão)
      // O PeerDiscoveryService deve ser chamado após a transação ser persistida
      // _peerDiscovery.gossipTransaction(finalEntry.toJson()); // Simulação
      
      return finalEntry;
    });
  }

  /// Aceita uma entrada pendente (adiciona assinatura do receptor)
  Future<DistributedLedgerEntry> acceptLedgerEntry({
    required DistributedLedgerEntry entry,
    required String receiverPrivateKey,
  }) async {
    if (entry.isAccepted) {
      throw Exception('DistributedLedgerService.acceptLedgerEntry: Entrada já foi aceita');
    }
    
    // Assinar com chave do receptor
    final senderData = _getSignatureData(
      entryId: entry.entryId,
      sequenceNumber: entry.sequenceNumber,
      transactionId: entry.transactionId,
      senderId: entry.senderId,
      receiverId: entry.receiverId,
      amount: entry.amount,
      transactionFee: entry.transactionFee,
      coinTypeId: entry.coinTypeId,
      inputUTXOHash: entry.inputUTXOHash,
      proofOfWorkNonce: entry.proofOfWorkNonce,
      lamportTimestamp: entry.lamportTimestamp,
      seqNonce: entry.seqNonce,
    );
    
    final receiverSignature = await _crypto.signData(senderData, receiverPrivateKey);
    
    // Atualizar entrada
    final acceptedEntry = entry.copyWith(
      receiverSignature: receiverSignature,
      status: 'accepted',
    );
    
    // Recalcular hash
    final newHash = _calculateEntryHash(acceptedEntry);
    return acceptedEntry.copyWith(entryHash: newHash);
  }

  // ==================== VERIFICAÇÃO E PROCESSAMENTO ====================

  /// Verifica a integridade de uma entrada do ledger
  Future<bool> verifyLedgerEntry({
    required DistributedLedgerEntry entry,
    required String senderPublicKey,
    required int powDifficulty,
    String? receiverPublicKey,
  }) async {
    // ... (Lógica de verificação mantida) ...
    // 1. Validação Defensiva de Entrada
    if (entry.amount <= 0) return false;
    if (entry.seqNonce <= 0) return false;
    if (entry.senderId.isEmpty || entry.receiverId.isEmpty) return false;
    
    // 2. Verificar assinatura do remetente (PRIMEIRO - autenticidade)
    final senderData = _getSignatureData(
      entryId: entry.entryId,
      sequenceNumber: entry.sequenceNumber,
      transactionId: entry.transactionId,
      senderId: entry.senderId,
      receiverId: entry.receiverId,
      amount: entry.amount,
      transactionFee: entry.transactionFee,
      coinTypeId: entry.coinTypeId,
      inputUTXOHash: entry.inputUTXOHash,
      proofOfWorkNonce: entry.proofOfWorkNonce,
      lamportTimestamp: entry.lamportTimestamp,
      seqNonce: entry.seqNonce,
    );
    
    if (!await _crypto.verifySignature(senderData, entry.senderSignature, senderPublicKey)) {
      return false; // Assinatura inválida - descarta imediatamente
    }
    
    // 3. Verificar Seq-Nonce (SEGUNDO - replay attack)
    final lastSeenNonce = _lastSeenSeqNonce[entry.senderId] ?? 0;
    if (entry.seqNonce <= lastSeenNonce) {
      final dbSequence = await _db.getSequenceEntry(entry.senderId);
      if (entry.seqNonce <= (dbSequence?.lastSequenceNumber ?? 0)) {
        return false; // Descarta tráfego repetido SEM calcular PoW
      }
    }
    
    // 4. Verificar Prova de Trabalho (TERCEIRO - custo computacional)
    final powData = '${entry.entryId}:${entry.senderId}:${entry.lamportTimestamp.counter}';
    if (!await _crypto.verifyPoW(powData, entry.proofOfWorkNonce, powDifficulty)) {
      return false;
    }
    
    // 5. Verificar UTXO (QUARTO - gasto duplo)
    if (entry.inputUTXOHash != null && !await _db.isUTXOAvailable(entry.inputUTXOHash!)) {
      return false; // UTXO já foi gasto
    }
    
    // 6. Verificar hash da entrada
    final calculatedHash = _calculateEntryHash(entry);
    if (calculatedHash != entry.entryHash) {
      return false;
    }
    
    // 7. Verificar Taxa Mínima
    final minFee = DecimalUtils.fromString(AppConfig.minTransactionFee.toString());
    if (entry.transactionFee < minFee) {
      return false;
    }
    
    // 8. Verificar assinatura do receptor (se presente)
    if (entry.receiverSignature != null && receiverPublicKey != null) {
      if (!await _crypto.verifySignature(senderData, entry.receiverSignature!, receiverPublicKey)) {
        return false;
      }
    }
    
    // 9. Verificar sequência (se temos histórico)
    final dbSequence = await _db.getSequenceEntry(entry.senderId);
    final expectedSequence = (dbSequence?.lastSequenceNumber ?? 0) + 1;
    if (entry.sequenceNumber != expectedSequence) {
      return false;
    }
    
    _lastSeenSeqNonce[entry.senderId] = entry.seqNonce;
    
    return true;
  }

 /// Processa uma entrada recebida de outro peer (incluindo Sync)
  /// 
  /// Roteamento: Se a transação for válida, ela vai para a Mempool.
  Future<bool> processEntry({
    required DistributedLedgerEntry entry,
    required String senderPublicKey,
    required int powDifficulty,
    String? receiverPublicKey,
  }) async {
    // Valida a entrada
    final isValid = await verifyLedgerEntry(
      entry: entry,
      senderPublicKey: senderPublicKey,
      powDifficulty: powDifficulty,
      receiverPublicKey: receiverPublicKey,
    );
    
    if (!isValid) {
      return false;
    }
    
    // Roteamento: Se a transação for válida, ela vai para a Mempool
    await _mempoolService.addEntry(entry);
    
    // TODO: Iniciar Gossip para retransmissão
    
    return true;
  }

  /// Inclui a transação de maior prioridade da Mempool no Ledger principal
  Future<bool> includeHighestPriorityEntryInLedger() async {
    final mempoolEntry = await _mempoolService.getHighestPriorityEntry();
    
    if (mempoolEntry == null) {
      return false; // Mempool vazia
    }
    
    final entry = mempoolEntry.entry;
    
    // 1. Revalidação Final (para garantir que o UTXO ainda está disponível)
    if (entry.inputUTXOHash != null && !await _db.isUTXOAvailable(entry.inputUTXOHash!)) {
      // Conflito de UTXO: O UTXO foi gasto por outra transação que entrou no Ledger
      // A transação da Mempool deve ser descartada.
      await _mempoolService.removeEntry(entry.entryHash);
      return false;
    }
    
    // Início da Transação Atômica do DB (Inclusão no Ledger)
    return await _db.transaction((txn) async {
      // 1. Marca UTXO como gasto (se aplicável)
      if (entry.inputUTXOHash != null) {
        await _db.spendUTXO(entry.inputUTXOHash!);
      }
      
      // 2. Atualiza SequenceEntry
      final newSequence = SequenceEntry(
        peerId: entry.senderId,
        lastSequenceNumber: entry.sequenceNumber,
        lastEntryHash: entry.entryHash,
      );
      await _db.saveSequenceEntry(newSequence);
      
      // 3. Cria novo UTXO (o output desta transação)
      final newUTXO = UTXOEntry(
        utxoHash: entry.entryHash, // O hash da entrada é o hash do output
        amount: entry.amount,
        ownerId: entry.receiverId,
        timestamp: entry.wallClockTime,
      );
      await _db.saveUTXO(newUTXO);
      
      // 4. Remove da Mempool
      await _mempoolService.removeEntry(entry.entryHash);
      
      // 5. Atualiza cache (para otimização)
      _lastSeenSeqNonce[entry.senderId] = entry.seqNonce;
      
      return true;
    });
  }

  /// Verifica a integridade de uma entrada do ledger
      // 2. Atualiza SequenceEntry
      final newSequence = SequenceEntry(
        peerId: entry.senderId,
        lastSequenceNumber: entry.sequenceNumber,
        lastEntryHash: entry.entryHash,
      );
      await _db.saveSequenceEntry(newSequence);
      
      // 3. Cria novo UTXO (o output desta transação)
      final newUTXO = UTXOEntry(
        utxoHash: entry.entryHash, // O hash da entrada é o hash do output
        amount: entry.amount,
        ownerId: entry.receiverId,
        timestamp: entry.wallClockTime,
      );
      await _db.saveUTXO(newUTXO);
      
      // 4. Atualiza cache (para otimização)
      _lastSeenSeqNonce[entry.senderId] = entry.seqNonce;
      
      return true;
    });
  }

  // ==================== UTXO (Unspent Transaction Output) ====================

  /// Verifica se um UTXO está disponível (não gasto)
  Future<bool> isUTXOAvailable(String utxoHash) async {
    return await _db.isUTXOAvailable(utxoHash);
  }

  // ==================== HELPERS ====================

  /// Calcula o hash de uma entrada
  String _calculateEntryHash(DistributedLedgerEntry entry) {
    final canonical = entry.toCanonicalString();
    final bytes = utf8.encode(canonical);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Obtém os dados para assinatura
  String _getSignatureData({
    required String entryId,
    required int sequenceNumber,
    required String transactionId,
    required String senderId,
    required String receiverId,
    required int amount,
    required int transactionFee,
    required String coinTypeId,
    String? inputUTXOHash,
    required String proofOfWorkNonce,
    required LamportTimestamp lamportTimestamp,
    required int seqNonce,
  }) {
    return [
      entryId,
      sequenceNumber.toString(),
      transactionId,
      senderId,
      receiverId,
      amount.toString(),
      transactionFee.toString(),
      coinTypeId,
      inputUTXOHash ?? '',
      proofOfWorkNonce,
      lamportTimestamp.counter.toString(),
      lamportTimestamp.nodeId,
      seqNonce.toString(),
    ].join('|');
  }
}
