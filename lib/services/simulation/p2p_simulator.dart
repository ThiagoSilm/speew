import '../../core/utils/logger_service.dart'; // Importa modelos Peer e P2PMessage
import '../../models/coin_transaction.dart';
import '../../models/distributed_ledger_entry.dart';
import '../../models/lamport_clock.dart';
import '../../models/message.dart';
import '../../models/trust_event.dart';
import '../../models/user.dart';
import '../crypto/crypto_service.dart';
import '../ledger/distributed_ledger_service.dart';
import '../network/file_transfer_service.dart';
import '../network/p2p_service.dart';
import '../reputation/reputation_service.dart';
import '../sync/social_sync_service.dart';
import './mock_services.dart';
import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

// =============================================================================
// 1. SimulatedNode: Representa um dispositivo virtual na simulação
// =============================================================================

class SimulatedNode {
  final String nodeId;
  final String displayName;
  final CryptoService cryptoService;
  final DistributedLedgerService ledgerService;
  final ReputationService reputationService;
  final FileTransferService fileTransferService;
  final SocialSyncService socialSyncService;
  final LamportClock clock = LamportClock();

  // Estado do nó
  final List<P2PMessage> messageQueue = [];
  final List<Peer> connectedPeers = [];
  bool isOnline = true;

  SimulatedNode({
    required this.nodeId,
    required this.displayName,
    required this.cryptoService,
    required this.ledgerService,
    required this.reputationService,
    required this.fileTransferService,
    required this.socialSyncService,
  });

  // Simula o recebimento de uma mensagem
  void receiveMessage(P2PMessage message) {
    if (isOnline) {
      messageQueue.add(message);
      clock.tick(); // Incrementa o relógio lógico
      // Lógica de processamento de mensagem real (será implementada nos testes)
      logger.info('Nó $displayName recebeu ${message.type} de ${message.senderId}', tag: 'SIM');
    }
  }

  // Simula a criação de uma transação simbólica
  CoinTransaction createTransaction({
    required String receiverId,
    required double amount,
    required String memo,
  }) {
    final transaction = CoinTransaction(
      transactionId: const Uuid().v4(),
      senderId: nodeId,
      receiverId: receiverId,
      amount: amount,
      timestamp: DateTime.now(),
      memo: memo,
      signature: 'mock_signature_${const Uuid().v4()}', // Mock de assinatura
    );
    return transaction;
  }

  // Simula a criação de uma entrada no ledger
  DistributedLedgerEntry createLedgerEntry(CoinTransaction transaction) {
    final entry = DistributedLedgerEntry(
      entryId: const Uuid().v4(),
      transaction: transaction,
      lamportTime: clock.value,
      timestamp: DateTime.now(),
      signedBy: nodeId,
    );
    return entry;
  }

  // Simula a atualização de reputação
  void updateReputation(String peerId, TrustEvent event) {
    reputationService.recordEvent(peerId, event);
  }

  // Simula a rotação de chaves (apenas mock)
  void rotateKeys() {
    logger.info('Nó $displayName rotacionou chaves.', tag: 'SIM');
    // Em um cenário real, isso envolveria a geração de um novo par de chaves
    // e a notificação aos peers.
  }
}

// =============================================================================
// 2. P2PSimulator: Gerencia a rede virtual e a transmissão de mensagens
// =============================================================================

class P2PSimulator extends ChangeNotifier {
  final Map<String, SimulatedNode> _nodes = {};
  final Map<String, Map<String, ConnectionConfig>> _connectionMatrix = {};
  final Random _random = Random();
  final Uuid _uuid = const Uuid();

  Map<String, SimulatedNode> get nodes => Map.unmodifiable(_nodes);

  // Configuração padrão de conexão
  static const int defaultLatencyMs = 100;
  static const double defaultPacketLoss = 0.05; // 5%

  // Adiciona um novo nó à simulação
  SimulatedNode addNode(String displayName) {
    final nodeId = _uuid.v4();
    // Mock de serviços necessários para o nó
    // Mock de serviços necessários para o nó
    final cryptoService = CryptoService();
    final ledgerService = MockDistributedLedgerService(nodeId);
    final reputationService = MockReputationService();
    final fileTransferService = MockFileTransferService(nodeId);
    final socialSyncService = MockSocialSyncService(nodeId);

    final node = SimulatedNode(
      nodeId: nodeId,
      displayName: displayName,
      cryptoService: cryptoService,
      ledgerService: ledgerService,
      reputationService: reputationService,
    );

    _nodes[nodeId] = node;
    _connectionMatrix[nodeId] = {};
    
    // Conecta o novo nó a todos os nós existentes (simulação de descoberta)
    for (final existingNodeId in _nodes.keys) {
      if (existingNodeId != nodeId) {
        // Conexão bidirecional
        _connectNodes(nodeId, existingNodeId);
        _connectNodes(existingNodeId, nodeId);
      }
    }

    logger.info('Nó $displayName ($nodeId) adicionado.', tag: 'SIM');
    notifyListeners();
    return node;
  }

  // Configura a conexão entre dois nós
  void _connectNodes(String idA, String idB, {
    int latencyMs = defaultLatencyMs,
    double packetLoss = defaultPacketLoss,
    bool isConnected = true,
  }) {
    _connectionMatrix[idA]![idB] = ConnectionConfig(
      latencyMs: latencyMs,
      packetLoss: packetLoss,
      isConnected: isConnected,
    );
    // Simula a lista de peers conectados no nó
    final nodeA = _nodes[idA]!;
    final nodeB = _nodes[idB]!;
    if (isConnected && !nodeA.connectedPeers.any((p) => p.peerId == idB)) {
      nodeA.connectedPeers.add(Peer(
        peerId: idB,
        displayName: nodeB.displayName,
        publicKey: 'mock_key_$idB',
        connectionType: 'simulated',
        signalStrength: -50,
      ));
    } else if (!isConnected) {
      nodeA.connectedPeers.removeWhere((p) => p.peerId == idB);
    }
  }

  // Simula o envio de uma mensagem de um nó para outro
  Future<bool> sendMessage(String senderId, String receiverId, P2PMessage message) async {
    final sender = _nodes[senderId];
    final receiver = _nodes[receiverId];

    if (sender == null || receiver == null || !sender.isOnline || !receiver.isOnline) {
      return false;
    }

    final config = _connectionMatrix[senderId]?[receiverId];
    if (config == null || !config.isConnected) {
      logger.info('Falha: $senderId -> $receiverId (Desconectado)', tag: 'SIM');
      return false;
    }

    // Simulação de perda de pacote
    if (_random.nextDouble() < config.packetLoss) {
      logger.info('Perda de Pacote: $senderId -> $receiverId', tag: 'SIM');
      return false;
    }

    // Simulação de latência
    await Future.delayed(Duration(milliseconds: config.latencyMs));

    // Entrega da mensagem
    receiver.receiveMessage(message);
    logger.info('Sucesso: $senderId -> $receiverId (Latência: ${config.latencyMs}ms)', tag: 'SIM');
    return true;
  }

  // Simula a propagação de uma mensagem (store-and-forward)
  Future<void> propagateMessage(String senderId, P2PMessage message) async {
    final sender = _nodes[senderId];
    if (sender == null || !sender.isOnline) return;

    final propagationTasks = <Future>[];
    final nextHopMessage = message.incrementHop();

    for (final peer in sender.connectedPeers) {
      // Não envia de volta para o nó que enviou a mensagem original (se houver)
      // A lógica de loop prevention deve estar no IntelligentMeshService, mas aqui
      // garantimos que o simulador tente enviar para todos os vizinhos.
      propagationTasks.add(sendMessage(senderId, peer.peerId, nextHopMessage));
    }

    await Future.wait(propagationTasks);
  }

  // Simula a desconexão/reconexão de um nó
  void setNodeOnlineStatus(String nodeId, bool isOnline) {
    final node = _nodes[nodeId];
    if (node != null) {
      node.isOnline = isOnline;
      // Atualiza a matriz de conexão para refletir a desconexão/reconexão
      for (final peerId in _nodes.keys) {
        if (peerId != nodeId) {
          _connectionMatrix[nodeId]![peerId]!.isConnected = isOnline;
          _connectionMatrix[peerId]![nodeId]!.isConnected = isOnline;
          
          // Atualiza a lista de peers conectados em cada nó
          final peerNode = _nodes[peerId]!;
          if (isOnline) {
            if (!peerNode.connectedPeers.any((p) => p.peerId == nodeId)) {
              peerNode.connectedPeers.add(Peer(
                peerId: nodeId,
                displayName: node.displayName,
                publicKey: 'mock_key_$nodeId',
                connectionType: 'simulated',
                signalStrength: -50,
              ));
            }
          } else {
            peerNode.connectedPeers.removeWhere((p) => p.peerId == nodeId);
          }
        }
      }
      debugPrint('[SIM] Nó ${node.displayName} está ${isOnline ? 'ONLINE' : 'OFFLINE'}.');
      notifyListeners();
    }
  }

  // Limpa a simulação
  void reset() {
    _nodes.clear();
    _connectionMatrix.clear();
    logger.info('Simulador resetado.', tag: 'SIM');
    notifyListeners();
  }
}

// =============================================================================
// 3. ConnectionConfig: Configuração de latência e perda de pacote
// =============================================================================

class ConnectionConfig {
  int latencyMs;
  double packetLoss;
  bool isConnected;

  ConnectionConfig({
    required this.latencyMs,
    required this.packetLoss,
    required this.isConnected,
  });
}

// =============================================================================
// 4. MockP2PService: Interface para o restante do app
// =============================================================================

class MockP2PService extends P2PService {
  final P2PSimulator simulator;
  final String localNodeId;

  MockP2PService(this.simulator, this.localNodeId);

  @override
  List<Peer> get connectedPeers {
    final node = simulator.nodes[localNodeId];
    return node?.connectedPeers ?? [];
  }

  @override
  Future<bool> sendMessage(String peerId, P2PMessage message) async {
    // O MockP2PService simula o envio de uma mensagem do nó local para um peer
    return simulator.sendMessage(localNodeId, peerId, message);
  }

  @override
  Future<void> propagateMessage(P2PMessage message, {String? excludePeerId}) async {
    // O MockP2PService simula a propagação da mensagem a partir do nó local
    await simulator.propagateMessage(localNodeId, message);
  }

  // Métodos de controle do simulador (para uso nos testes)
  void setOnline(bool isOnline) {
    simulator.setNodeOnlineStatus(localNodeId, isOnline);
  }
}
