import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart';
import '../../core/db/database_service.dart';
import '../../core/db/models/sequence_entry.dart';
import '../../core/models/distributed_ledger_entry.dart';
import '../p2p/peer_discovery_service.dart';
import 'models/sync_request.dart';
import 'models/sync_response.dart';

/// Serviço de Sincronização de Estado (Delta Sync)
/// Responsável por orquestrar a sincronização de transações perdidas após o offline.
class SyncService {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  final _db = DatabaseService();
  final _peerDiscovery = PeerDiscoveryService();
  
  // Simulação de um repositório de todas as entradas do ledger (na prática, seria uma tabela no DB)
  final List<DistributedLedgerEntry> _fullLedger = []; 

  // ==================== LÓGICA DE REQUISIÇÃO (CLIENTE) ====================

  /// Inicia o processo de sincronização com peers aleatórios
  Future<void> startDeltaSync() async {
    print('SyncService: Iniciando Delta Sync...');
    
    // 1. Obter o estado de sequência local (Sequence Check)
    final allPeers = await _db.getPeers(limit: 100); // Pega todos os peers conhecidos
    final lastKnownSequences = <String, int>{};
    
    for (final peer in allPeers) {
      final sequenceEntry = await _db.getSequenceEntry(peer.peerId);
      lastKnownSequences[peer.peerId] = sequenceEntry?.lastSequenceNumber ?? 0;
    }
    
    // 2. Criar a requisição de sincronização
    final myPeerId = 'MY_LOCAL_PEER_ID'; // ID do nó local (deve ser obtido do CryptoService)
    final request = SyncRequest(
      requestingPeerId: myPeerId,
      lastKnownSequences: lastKnownSequences,
      timestamp: DateTime.now(),
    );
    
    // 3. Enviar a requisição para um peer aleatório (simulação de envio P2P)
    final targetPeer = await _db.getRandomPeer();
    if (targetPeer == null) {
      print('SyncService: Nenhum peer para sincronizar.');
      return;
    }
    
    // Simulação de envio da requisição via rede
    final responseJson = await _simulateP2PSyncRequest(targetPeer.address, request.toJson());
    
    if (responseJson != null) {
      final response = SyncResponse.fromJson(responseJson);
      await _processSyncResponse(response);
    }
  }

  /// Processa a resposta de sincronização (as transações perdidas)
  Future<void> _processSyncResponse(SyncResponse response) async {
    print('SyncService: Recebidas ${response.missingEntries.length} entradas perdidas de ${response.respondingPeerId}.');
    
    // TODO: Injetar DistributedLedgerService aqui para validação e processamento
    // O DistributedLedgerService deve ter um método para processar uma lista de entradas
    
    for (final entry in response.missingEntries) {
      // 1. Validação completa da entrada (assinatura, PoW, UTXO, Sequence)
      // Simulação: Assumindo que o peer remoto enviou entradas válidas
      
      // 2. Processamento da entrada (atualiza DB, UTXO, Sequence)
      // await DistributedLedgerService().processEntry(entry: entry, ...);
      
      // Simulação de processamento:
      _fullLedger.add(entry);
      
      // 3. Atualiza o SequenceEntry para o peer que originou a transação
      final newSequence = SequenceEntry(
        peerId: entry.senderId,
        lastSequenceNumber: entry.sequenceNumber,
        lastEntryHash: entry.entryHash,
      );
      await _db.saveSequenceEntry(newSequence);
    }
    
    print('SyncService: Sincronização concluída. Ledger atualizado.');
  }

  // ==================== LÓGICA DE RESPOSTA (SERVIDOR) ====================

  /// Responde a uma requisição de sincronização de um peer remoto
  Future<String> handleSyncRequest(String requestJson) async {
    final request = SyncRequest.fromJson(requestJson);
    
    print('SyncService: Recebida requisição de Sync de ${request.requestingPeerId}.');
    
    final missingEntries = <DistributedLedgerEntry>[];
    
    // Itera sobre as sequências conhecidas do peer solicitante
    for (final peerId in request.lastKnownSequences.keys) {
      final lastKnownSeq = request.lastKnownSequences[peerId]!;
      
      // Simulação: Busca no Ledger local por entradas deste peer com sequência > lastKnownSeq
      final entriesToSend = _fullLedger
          .where((e) => e.senderId == peerId && e.sequenceNumber > lastKnownSeq)
          .toList()
            ..sort((a, b) => a.sequenceNumber.compareTo(b.sequenceNumber));
            
      missingEntries.addAll(entriesToSend);
    }
    
    // 2. Cria a resposta
    final myPeerId = 'MY_LOCAL_PEER_ID';
    final response = SyncResponse(
      respondingPeerId: myPeerId,
      missingEntries: missingEntries,
      timestamp: DateTime.now(),
    );
    
    print('SyncService: Respondendo com ${missingEntries.length} entradas perdidas.');
    return response.toJson();
  }

  // ==================== SIMULAÇÃO DE COMUNICAÇÃO P2P ====================

  /// Simula o envio da requisição de Sync via rede
  Future<String?> _simulateP2PSyncRequest(String address, String payload) async {
    // Na implementação real, isso seria um método no P2PManager nativo
    // que enviaria o payload e esperaria a resposta.
    
    // Simulação: O peer remoto (nós mesmos) responde à requisição
    await Future.delayed(Duration(milliseconds: 500));
    return handleSyncRequest(payload);
  }
}
