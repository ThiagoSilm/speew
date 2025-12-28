import 'dart:async';
import '../../core/db/database_service.dart';
import '../../core/db/models/mempool_entry.dart';
import '../../core/models/distributed_ledger_entry.dart';
import '../../core/errors/exceptions.dart';

/// Serviço de Mempool (Memory Pool)
/// Gerencia transações que aguardam inclusão no Ledger.
/// Implementa Fee Ranking e detecção de conflito de UTXO.
class MempoolService {
  static const _purgeInterval = Duration(minutes: 5); // Intervalo de verificação
  static const _maxAge = Duration(minutes: 30); // Idade máxima antes do expurgo
  
  Timer? _purgeTimer;
  static final MempoolService _instance = MempoolService._internal();
  factory MempoolService() => _instance;
  MempoolService._internal() {
    _startPurgeTimer();
  }

  final _db = DatabaseService();
  
  // ==================== ENTRADA E VALIDAÇÃO TEMPORÁRIA ====================

  /// Adiciona uma transação à Mempool após validação inicial (PoW, Assinatura, Sequence)
  /// 
  /// Validação Temporária: A transação entra em "Hold".
  Future<void> addEntry(DistributedLedgerEntry entry) async {
    // 1. Validação de Conflito de UTXO na Mempool
    if (entry.inputUTXOHash != null) {
      final conflictingEntries = await _db.getMempoolEntriesByInputUTXO(entry.inputUTXOHash!);
      
      if (conflictingEntries.isNotEmpty) {
        // Conflito detectado: Duas transações na Mempool tentam gastar o mesmo UTXO.
        
        // Lógica de Fee Ranking: Se houver conflito, a transação com a maior fee ganha a vaga.
        final existingEntry = conflictingEntries.first; // A primeira é a de maior fee (devido ao orderBy do getMempoolEntries)
        
        if (entry.transactionFee > existingEntry.fee) {
          // A nova transação tem fee maior: Ela ganha.
          print('MempoolService: Conflito de UTXO. Nova transação (Fee: ${entry.transactionFee}) substitui a existente (Fee: ${existingEntry.fee}).');
          await _db.removeMempoolEntry(existingEntry.entryHash);
        } else {
          // A nova transação tem fee menor ou igual: Ela é descartada.
          throw WalletException.mempoolConflict('Transação descartada: Fee (${entry.transactionFee}) menor ou igual à transação conflitante na Mempool (${existingEntry.fee}).');
        }
      }
    }
    
    // 2. Criação da MempoolEntry
    final mempoolEntry = MempoolEntry(
      entryHash: entry.entryHash,
      entry: entry,
      receivedAt: DateTime.now(),
      fee: entry.transactionFee,
    );
    
    // 3. Persistência Atômica (Sqflite)
    await _db.saveMempoolEntry(mempoolEntry);
    print('MempoolService: Transação ${entry.entryHash} adicionada à Mempool. Fee: ${entry.transactionFee}');
  }

  /// Remove uma transação da Mempool (após ser incluída no Ledger)
  Future<void> removeEntry(String entryHash) async {
    await _db.removeMempoolEntry(entryHash);
    print('MempoolService: Transação ${entryHash} removida da Mempool.');
  }

  // ==================== SELEÇÃO POR PRIORIDADE (Fee Ranking) ====================

  /// Obtém a transação de maior prioridade (maior Fee) para inclusão no Ledger
  /// 
  /// Esta função é usada pelo DistributedLedgerService para selecionar a próxima transação
  /// a ser processada e incluída no Ledger.
  Future<MempoolEntry?> getHighestPriorityEntry() async {
    final entries = await _db.getMempoolEntries();
    return entries.isNotEmpty ? entries.first : null;
  }

  // ==================== EXPURGO DE SPAM (Session Timeout) ====================

  /// Inicia o timer de expurgo de spam
  void _startPurgeTimer() {
    _purgeTimer?.cancel();
    _purgeTimer = Timer.periodic(_purgeInterval, (timer) {
      purgeOldEntries(maxAge: _maxAge);
    });
    print('MempoolService: Timer de expurgo iniciado. Intervalo: ${_purgeInterval.inMinutes} min, Idade Máxima: ${_maxAge.inMinutes} min.');
  }
  
  /// Para o timer de expurgo e libera recursos
  void dispose() {
    _purgeTimer?.cancel();
    _purgeTimer = null;
    print('MempoolService: Recursos liberados e timer parado.');
  }

  /// Implementa a lógica de expurgo de transações antigas (Spam)
  /// 
  /// Ponto 4: Expurgo de Spam: Transações que ficam na Mempool por mais de X minutos
  /// sem entrar no Ledger devem ser descartadas para não estourar a RAM/DB.
  Future<int> purgeOldEntries({Duration maxAge = _maxAge}) async {
    final cutoffTime = DateTime.now().subtract(maxAge);
    final entries = await _db.getMempoolEntries();
    
    int purgedCount = 0;
    for (final entry in entries) {
      if (entry.receivedAt.isBefore(cutoffTime)) {
        await _db.removeMempoolEntry(entry.entryHash);
        purgedCount++;
      }
    }
    
    if (purgedCount > 0) {
      print('MempoolService: Expurgo de Spam concluído. ${purgedCount} transações antigas removidas.');
    }
    return purgedCount;
  }
  
  // ==================== OUTROS MÉTODOS ====================
  
  Future<int> getMempoolSize() async {
    final entries = await _db.getMempoolEntries();
    return entries.length;
  }
}
