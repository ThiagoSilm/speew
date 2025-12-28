import 'dart:math';
import 'package:flutter/services.dart';
import '../../core/db/database_service.dart';
import '../../core/db/models/peer_entry.dart';
import '../sync/sync_service.dart'; // Import do SyncService

/// Serviço de Descoberta de Peers e Lógica de Gossip
/// Implementa Kademlia-lite e o algoritmo de retransmissão limitada (Ponto 5)
class PeerDiscoveryService {
  static final PeerDiscoveryService _instance = PeerDiscoveryService._internal();
  factory PeerDiscoveryService() => _instance;
  PeerDiscoveryService._internal();

  final _db = DatabaseService();
  final _random = Random();
  final _syncService = SyncService(); // Instância do SyncService
  
  // Canal de comunicação com o código nativo (Kotlin/Swift)
  static const MethodChannel _channel = MethodChannel('speew/p2p_service_manager');

  /// Adiciona ou atualiza um peer na tabela (Kademlia-lite)
  Future<void> updatePeer(String peerId, String address, int port) async {
    final peer = PeerEntry(
      peerId: peerId,
      address: address,
      port: port,
      lastSeen: DateTime.now(),
      failureCount: 0,
    );
    await _db.savePeer(peer);
  }

  /// Obtém uma lista de peers ativos (para Gossip)
  Future<List<PeerEntry>> getActivePeers({int limit = 10}) async {
    // Ponto 4: Peer Discovery - Busca no DB
    return await _db.getPeers(limit: limit);
  }

  /// Lógica de Gossip: Repassa a transação para 3 a 5 peers aleatórios
  /// 
  /// Ponto 5: Gossip Logic - Algoritmo de retransmissão limitada
  Future<void> gossipTransaction(String transactionPayload) async {
    final activePeers = await getActivePeers(limit: 20);
    if (activePeers.isEmpty) {
      print('PeerDiscoveryService: Sem peers ativos para Gossip.');
      return;
    }

    // Seleciona de 3 a 5 peers aleatórios
    final peersToGossip = <PeerEntry>[];
    final numPeers = min(activePeers.length, _random.nextInt(3) + 3); // 3, 4 ou 5
    
    // Evita selecionar o mesmo peer duas vezes
    final shuffledPeers = activePeers.toList()..shuffle(_random);
    peersToGossip.addAll(shuffledPeers.take(numPeers));

    final peerAddresses = peersToGossip.map((p) => p.address).toList();
    
    // Envia o payload para o código nativo para transmissão via socket
    try {
      await _channel.invokeMethod('sendToPeers', {
        'payload': transactionPayload,
        'peers': peerAddresses,
      });
      print('PeerDiscoveryService: Gossip enviado para ${peersToGossip.length} peers.');
    } on PlatformException catch (e) {
      print("PeerDiscoveryService: Falha ao enviar Gossip: ${e.message}");
    }
  }
  
  /// Inicia o serviço P2P nativo (chamado no main.dart)
  Future<void> startP2PService() async {
    try {
      await _channel.invokeMethod('startP2PService');
      print('PeerDiscoveryService: Serviço P2P nativo iniciado.');
      
      // Inicia o Sync de Delta após o serviço de rede estar ativo
      _syncService.startDeltaSync();
      
    } on PlatformException catch (e) {
      print("PeerDiscoveryService: Falha ao iniciar serviço P2P nativo: ${e.message}");
    }
  }
  
  /// Para o serviço P2P nativo
  Future<void> stopP2PService() async {
    try {
      await _channel.invokeMethod('stopP2PService');
      print('PeerDiscoveryService: Serviço P2P nativo parado.');
    } on PlatformException catch (e) {
      print("PeerDiscoveryService: Falha ao parar serviço P2P nativo: ${e.message}");
    }
  }
}
