import '../../models/distributed_ledger_entry.dart';
import '../../models/lamport_clock.dart';
import '../../models/social_state.dart';
import '../crypto/crypto_service.dart';
import '../ledger/distributed_ledger_service.dart';
import 'dart:convert';
import 'package:uuid/uuid.dart';

/// Serviço de Sincronização Social Distribuída
/// Gerencia o estado social assinado e sincronizado entre peers
class SocialSyncService {
  static final SocialSyncService _instance = SocialSyncService._internal();
  factory SocialSyncService() => _instance;
  SocialSyncService._internal();

  final _crypto = CryptoService();
  final _ledger = DistributedLedgerService();
  final _uuid = const Uuid();
  
  /// Relógio Lamport local
  LamportClock? _localClock;
  
  /// Estado social local atual
  SocialState? _localState;
  
  /// Cache de estados sociais de peers
  final Map<String, SocialState> _peerStates = {};

  // ==================== INICIALIZAÇÃO ====================

  /// Inicializa o serviço com o ID do nó local
  void initialize(String nodeId) {
    _localClock = LamportClock(nodeId: nodeId);
  }

  /// Obtém o relógio Lamport local
  LamportClock get localClock {
    if (_localClock == null) {
      throw Exception('SocialSyncService não foi inicializado. Chame initialize() primeiro.');
    }
    return _localClock!;
  }

  // ==================== CRIAÇÃO E ATUALIZAÇÃO DE ESTADO ====================

  /// Cria o estado social inicial para um usuário
  Future<SocialState> createInitialState({
    required String userId,
    required String publicKey,
    required String privateKey,
    String? ephemeralId,
  }) async {
    final timestamp = localClock.createTimestamp();
    localClock.tick();
    
    final state = SocialState(
      userId: userId,
      ephemeralId: ephemeralId,
      publicKey: publicKey,
      rotatedPublicKeys: [],
      reputationScore: 0.5,
      trustScore: 0.5,
      lamportTimestamp: timestamp,
      wallClockTime: DateTime.now(),
      partialLedger: [],
      pendingTransactionIds: [],
      acceptedTransactionIds: [],
      trustedPeers: [],
      suspiciousPeers: [],
      walletBalances: {'default': 0.0},
      documentSignature: '',
      previousStateHash: null,
      stateHash: '',
      version: 1,
      nonce: _uuid.v4(),
    );
    
    // Calcular hash
    final stateHash = _calculateStateHash(state);
    
    // Assinar documento
    final signature = await _crypto.signData(state.toCanonicalString(), privateKey);
    
    final finalState = state.copyWith(
      stateHash: stateHash,
      documentSignature: signature,
    );
    
    _localState = finalState;
    return finalState;
  }

  /// Atualiza o estado social local
  Future<SocialState> updateLocalState({
    required SocialState currentState,
    required String privateKey,
    double? reputationScore,
    double? trustScore,
    List<DistributedLedgerEntry>? partialLedger,
    List<String>? pendingTransactionIds,
    List<String>? acceptedTransactionIds,
    List<String>? trustedPeers,
    List<String>? suspiciousPeers,
    Map<String, double>? walletBalances,
    String? ephemeralId,
    String? publicKey,
    List<String>? rotatedPublicKeys,
  }) async {
    final timestamp = localClock.createTimestamp();
    localClock.tick();
    
    final updatedState = SocialState(
      userId: currentState.userId,
      ephemeralId: ephemeralId ?? currentState.ephemeralId,
      publicKey: publicKey ?? currentState.publicKey,
      rotatedPublicKeys: rotatedPublicKeys ?? currentState.rotatedPublicKeys,
      reputationScore: reputationScore ?? currentState.reputationScore,
      trustScore: trustScore ?? currentState.trustScore,
      lamportTimestamp: timestamp,
      wallClockTime: DateTime.now(),
      partialLedger: partialLedger ?? currentState.partialLedger,
      pendingTransactionIds: pendingTransactionIds ?? currentState.pendingTransactionIds,
      acceptedTransactionIds: acceptedTransactionIds ?? currentState.acceptedTransactionIds,
      trustedPeers: trustedPeers ?? currentState.trustedPeers,
      suspiciousPeers: suspiciousPeers ?? currentState.suspiciousPeers,
      walletBalances: walletBalances ?? currentState.walletBalances,
      documentSignature: '',
      previousStateHash: currentState.stateHash,
      stateHash: '',
      version: currentState.version + 1,
      nonce: _uuid.v4(),
    );
    
    // Calcular hash
    final stateHash = _calculateStateHash(updatedState);
    
    // Assinar documento
    final signature = await _crypto.signData(updatedState.toCanonicalString(), privateKey);
    
    final finalState = updatedState.copyWith(
      stateHash: stateHash,
      documentSignature: signature,
    );
    
    _localState = finalState;
    return finalState;
  }

  // ==================== SINCRONIZAÇÃO ====================

  /// Troca estados sociais com um peer
  Future<SocialState> exchangeStates({
    required SocialState localState,
    required SocialState peerState,
    required String peerPublicKey,
  }) async {
    // 1. Verificar assinatura do peer
    final isValid = await verifyStateSignature(peerState, peerPublicKey);
    if (!isValid) {
      throw Exception('Assinatura do estado do peer é inválida');
    }
    
    // 2. Atualizar relógio Lamport
    localClock.update(peerState.lamportTimestamp.counter);
    
    // 3. Armazenar estado do peer
    _peerStates[peerState.userId] = peerState;
    
    // 4. Retornar estado local atualizado
    return localState;
  }

  /// Mescla (merge) dois estados sociais
  Future<SocialState> mergeStates({
    required SocialState localState,
    required SocialState peerState,
    required String localPrivateKey,
  }) async {
    // Determinar qual estado é mais recente
    final comparison = localState.lamportTimestamp.compareTo(peerState.lamportTimestamp);
    
    SocialState newerState;
    SocialState olderState;
    
    if (comparison > 0) {
      // Local é mais recente
      newerState = localState;
      olderState = peerState;
    } else {
      // Peer é mais recente ou concorrente
      newerState = peerState;
      olderState = localState;
    }
    
    // Mesclar ledgers (união sem duplicatas)
    final mergedLedger = _mergeLedgers(
      localState.partialLedger,
      peerState.partialLedger,
    );
    
    // Mesclar transações pendentes
    final mergedPending = _mergeStringLists(
      localState.pendingTransactionIds,
      peerState.pendingTransactionIds,
    );
    
    // Mesclar transações aceitas
    final mergedAccepted = _mergeStringLists(
      localState.acceptedTransactionIds,
      peerState.acceptedTransactionIds,
    );
    
    // Mesclar peers confiáveis
    final mergedTrusted = _mergeStringLists(
      localState.trustedPeers,
      peerState.trustedPeers,
    );
    
    // Mesclar peers suspeitos
    final mergedSuspicious = _mergeStringLists(
      localState.suspiciousPeers,
      peerState.suspiciousPeers,
    );
    
    // Mesclar saldos (usar o maior)
    final mergedBalances = _mergeBalances(
      localState.walletBalances,
      peerState.walletBalances,
    );
    
    // Usar reputação e trust score do estado mais recente
    final mergedReputation = newerState.reputationScore;
    final mergedTrust = newerState.trustScore;
    
    // Criar novo estado mesclado
    return await updateLocalState(
      currentState: localState,
      privateKey: localPrivateKey,
      reputationScore: mergedReputation,
      trustScore: mergedTrust,
      partialLedger: mergedLedger,
      pendingTransactionIds: mergedPending,
      acceptedTransactionIds: mergedAccepted,
      trustedPeers: mergedTrusted,
      suspiciousPeers: mergedSuspicious,
      walletBalances: mergedBalances,
    );
  }

  // ==================== VERIFICAÇÃO ====================

  /// Verifica a assinatura de um estado social
  Future<bool> verifyStateSignature(SocialState state, String publicKey) async {
    return await _crypto.verifySignature(
      state.toCanonicalString(),
      state.documentSignature,
      publicKey,
    );
  }

  /// Verifica a integridade da cadeia de estados
  bool verifyStateChain(List<SocialState> states) {
    if (states.isEmpty) return true;
    
    // Ordenar por versão
    final sortedStates = List<SocialState>.from(states)
      ..sort((a, b) => a.version.compareTo(b.version));
    
    // Verificar sequência contínua
    for (int i = 0; i < sortedStates.length; i++) {
      if (sortedStates[i].version != i + 1) {
        return false;
      }
      
      // Verificar hash anterior
      if (i > 0) {
        if (sortedStates[i].previousStateHash != sortedStates[i - 1].stateHash) {
          return false;
        }
      }
    }
    
    return true;
  }

  // ==================== FUNÇÕES AUXILIARES ====================

  /// Calcula hash SHA-256 de um estado
  String _calculateStateHash(SocialState state) {
    return _crypto.sha256Hash(state.toCanonicalString());
  }

  /// Mescla dois ledgers removendo duplicatas
  List<DistributedLedgerEntry> _mergeLedgers(
    List<DistributedLedgerEntry> ledger1,
    List<DistributedLedgerEntry> ledger2,
  ) {
    final merged = <String, DistributedLedgerEntry>{};
    
    for (final entry in ledger1) {
      merged[entry.entryId] = entry;
    }
    
    for (final entry in ledger2) {
      if (!merged.containsKey(entry.entryId)) {
        merged[entry.entryId] = entry;
      } else {
        // Se já existe, manter a versão com mais testemunhas de propagação
        final existing = merged[entry.entryId]!;
        if (entry.propagationWitnesses.length > existing.propagationWitnesses.length) {
          merged[entry.entryId] = entry;
        }
      }
    }
    
    // Ordenar por timestamp Lamport
    final result = merged.values.toList()
      ..sort((a, b) => a.lamportTimestamp.compareTo(b.lamportTimestamp));
    
    // Manter apenas as últimas N entradas (ex: 100)
    const maxEntries = 100;
    if (result.length > maxEntries) {
      return result.sublist(result.length - maxEntries);
    }
    
    return result;
  }

  /// Mescla duas listas de strings removendo duplicatas
  List<String> _mergeStringLists(List<String> list1, List<String> list2) {
    final merged = <String>{};
    merged.addAll(list1);
    merged.addAll(list2);
    return merged.toList();
  }

  /// Mescla saldos de carteiras (usa o maior valor para cada tipo de moeda)
  Map<String, double> _mergeBalances(
    Map<String, double> balances1,
    Map<String, double> balances2,
  ) {
    final merged = <String, double>{};
    
    // Adicionar todos os tipos de moeda
    final allTypes = <String>{};
    allTypes.addAll(balances1.keys);
    allTypes.addAll(balances2.keys);
    
    // Para cada tipo, usar o maior saldo
    for (final type in allTypes) {
      final balance1 = balances1[type] ?? 0.0;
      final balance2 = balances2[type] ?? 0.0;
      merged[type] = balance1 > balance2 ? balance1 : balance2;
    }
    
    return merged;
  }

  /// Obtém o estado local atual
  SocialState? get localState => _localState;

  /// Obtém o estado de um peer
  SocialState? getPeerState(String userId) => _peerStates[userId];

  /// Obtém todos os estados de peers
  Map<String, SocialState> get allPeerStates => Map.unmodifiable(_peerStates);

  /// Reseta o serviço (para testes)
  void reset() {
    _localClock = null;
    _localState = null;
    _peerStates.clear();
  }
}
