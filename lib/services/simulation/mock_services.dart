import '../../core/utils/logger_service.dart';
import '../../models/coin_transaction.dart';
import '../../models/distributed_ledger_entry.dart';
import '../../models/file_block.dart';
import '../../models/file_model.dart';
import '../../models/message.dart';
import '../../models/social_state.dart';
import '../../models/trust_event.dart';
import '../ledger/distributed_ledger_service.dart';
import '../network/file_transfer_service.dart';
import '../reputation/reputation_service.dart';
import '../sync/social_sync_service.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

// =============================================================================
// MockDistributedLedgerService
// Simula a validação e armazenamento de transações no ledger.
// =============================================================================

class MockDistributedLedgerService extends DistributedLedgerService {
  final String nodeId;
  final Map<String, double> _balances = {};
  final List<DistributedLedgerEntry> _ledger = [];
  final Set<String> _processedTransactionIds = {};

  MockDistributedLedgerService(this.nodeId);

  @override
  Future<void> initialize() async {
    _balances[nodeId] = 1000.0; // Saldo inicial para o nó simulado
  }

  @override
  Future<bool> validateAndApplyEntry(DistributedLedgerEntry entry) async {
    if (_processedTransactionIds.contains(entry.transaction.transactionId)) {
      logger.info('Transação ${entry.transaction.transactionId} já processada (Replay detectado).', tag: 'LEDGER');
      return false;
    }

    if (entry.transaction.amount <= 0) {
      logger.info('Transação inválida: valor não positivo.', tag: 'LEDGER');
      return false;
    }

    // Simulação de verificação de gasto duplo (Double Spending)
    if (entry.transaction.senderId == nodeId) {
      final currentBalance = _balances[nodeId] ?? 0.0;
      if (currentBalance < entry.transaction.amount) {
        logger.info('Gasto Duplo detectado: Saldo insuficiente para ${entry.transaction.transactionId}.', tag: 'LEDGER');
        return false;
      }
    }

    // Simulação de aplicação
    _ledger.add(entry);
    _processedTransactionIds.add(entry.transaction.transactionId);

    // Atualiza saldos (simplificado: apenas para o nó local)
    if (entry.transaction.senderId == nodeId) {
      _balances[nodeId] = (_balances[nodeId] ?? 0.0) - entry.transaction.amount;
    }
    if (entry.transaction.receiverId == nodeId) {
      _balances[nodeId] = (_balances[nodeId] ?? 0.0) + entry.transaction.amount;
    }

    logger.info('Transação ${entry.transaction.transactionId} aplicada. Novo saldo: ${_balances[nodeId]}', tag: 'LEDGER');
    return true;
  }

  @override
  Future<double> getBalance(String userId) async {
    return _balances[userId] ?? 0.0;
  }

  // Método auxiliar para testes
  List<DistributedLedgerEntry> get ledger => _ledger;
}

// =============================================================================
// MockFileTransferService
// Simula a fragmentação, reconstrução e verificação de checksum.
// =============================================================================

class MockFileTransferService extends FileTransferService {
  final String nodeId;
  final Map<String, List<FileBlock>> _receivedBlocks = {};
  final Map<String, FileModel> _reconstructedFiles = {};

  MockFileTransferService(this.nodeId);

  @override
  Future<void> processIncomingBlock(FileBlock block) async {
    // 1. Simulação de verificação de checksum
    if (block.checksum == 'checksum_invalido') {
      logger.info('Bloco ${block.blockId} rejeitado: Checksum incorreto.', tag: 'FILE');
      return;
    }

    // 2. Armazenamento do bloco
    _receivedBlocks.putIfAbsent(block.fileId, () => []).add(block);
    logger.info('Bloco ${block.index}/${block.totalBlocks} de ${block.fileId} recebido.', tag: 'FILE');

    // 3. Simulação de reconstrução
    final blocks = _receivedBlocks[block.fileId]!;
    if (blocks.length == block.totalBlocks) {
      // Todos os blocos recebidos, simula a reconstrução
      blocks.sort((a, b) => a.index.compareTo(b.index));
      final reconstructedFile = FileModel(
        fileId: block.fileId,
        fileName: 'reconstruido_${block.fileId}',
        senderId: block.senderId,
        totalBlocks: block.totalBlocks,
        blocks: blocks,
      );
      _reconstructedFiles[block.fileId] = reconstructedFile;
      logger.info('Arquivo ${block.fileId} reconstruído com sucesso.', tag: 'FILE');
    }
  }

  // Método auxiliar para testes
  bool isFileReconstructed(String fileId) => _reconstructedFiles.containsKey(fileId);
}

// =============================================================================
// MockReputationService
// Simula a atualização de reputação e detecção de peers suspeitos.
// =============================================================================

class MockReputationService extends ReputationService {
  final Map<String, double> _reputations = {};

  @override
  Future<void> recordEvent(String peerId, TrustEvent event) async {
    _reputations.putIfAbsent(peerId, () => 0.5); // Reputação inicial
    
    switch (event.type) {
      case TrustEventType.transactionSuccess:
        _reputations[peerId] = (_reputations[peerId]! + 0.05).clamp(0.0, 1.0);
        break;
      case TrustEventType.transactionFailure:
      case TrustEventType.invalidSignature:
        _reputations[peerId] = (_reputations[peerId]! - 0.1).clamp(0.0, 1.0);
        break;
      default:
        break;
    }
    logger.info('Reputação de $peerId atualizada para ${_reputations[peerId]} após ${event.type}.', tag: 'REPUTATION');
  }

  @override
  Future<double> getReputation(String peerId) async {
    return _reputations[peerId] ?? 0.5;
  }

  // Método auxiliar para testes
  bool isPeerSuspicious(String peerId) => (_reputations[peerId] ?? 0.5) < 0.3;
}

// =============================================================================
// MockSocialSyncService
// Simula a sincronização de estado social e resolução de conflitos.
// =============================================================================

class MockSocialSyncService extends SocialSyncService {
  final String nodeId;
  SocialState _localState;

  MockSocialSyncService(this.nodeId) : _localState = SocialState(
    userId: nodeId,
    lastSyncTime: DateTime.now(),
    lamportTime: 0,
    posts: [],
  );

  @override
  Future<void> mergeRemoteState(SocialState remoteState) async {
    // Simulação de resolução de conflitos usando Lamport Timestamp
    if (remoteState.lamportTime > _localState.lamportTime) {
      _localState = remoteState;
      logger.info('Estado social mesclado. Novo Lamport Time: ${_localState.lamportTime}', tag: 'SYNC');
    } else if (remoteState.lamportTime == _localState.lamportTime) {
      // Conflito: desempate por timestamp real
      if (remoteState.lastSyncTime.isAfter(_localState.lastSyncTime)) {
        _localState = remoteState;
        logger.info('Conflito resolvido por Timestamp Real. Novo Lamport Time: ${_localState.lamportTime}', tag: 'SYNC');
      }
    }
    // Caso contrário, o estado local é mais recente ou igual, ignora o remoto.
  }

  @override
  Future<SocialState> getLocalState() async {
    return _localState;
  }

  // Método auxiliar para testes
  void updateLocalState(int newLamportTime) {
    _localState = SocialState(
      userId: nodeId,
      lastSyncTime: DateTime.now(),
      lamportTime: newLamportTime,
      posts: [..._localState.posts, 'Post ${const Uuid().v4()}'],
    );
  }
}
