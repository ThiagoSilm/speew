import '../errors/exceptions.dart';
import '../utils/logger_service.dart';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../notifications/notification_service.dart';
import '../models/device_key.dart';
import '../storage/database_service.dart';
import '../crypto/crypto_service.dart';
import '../mesh/mesh_traffic_manager.dart';
import '../mesh/packet_compressor.dart';
import '../mesh/stealth_mode_service.dart';
import '../reputation/reputation_core.dart';

class P2PService extends ChangeNotifier {
  static final P2PService _instance = P2PService._internal();
  factory P2PService() => _instance;
  P2PService._internal();

  final List<Peer> _connectedPeers = [];
  List<Peer> get connectedPeers => List.unmodifiable(_connectedPeers);

  final List<Peer> _discoveredPeers = [];
  List<Peer> get discoveredPeers => List.unmodifiable(_discoveredPeers);

  bool _isServerRunning = false;
  bool get isServerRunning => _isServerRunning;

  bool _isDiscovering = false;
  bool get isDiscovering => _isDiscovering;

  final StreamController<P2PMessage> _messageStreamController = StreamController<P2PMessage>.broadcast();
  Stream<P2PMessage> get messageStream => _messageStreamController.stream;

  final NotificationService _notificationService = NotificationService();
  final DatabaseService _db = DatabaseService();
  final CryptoService _crypto = CryptoService();
  final ReputationCore _reputationCore = ReputationCore();
  late final MeshTrafficManager _trafficManager;

  Future<void> initialize() async {
    try {
      _trafficManager = MeshTrafficManager();
      
      logger.info('Serviço inicializado com MeshTrafficManager', tag: 'P2P');
    } catch (e) {
      logger.error('Erro ao inicializar', tag: 'P2P', error: e);
      throw P2PException.connectionFailed('Inicialização falhou', error: e);
    }
  }

  Future<void> startServer(String userId, String displayName) async {
    if (_isServerRunning) {
      logger.warn('Servidor já está rodando', tag: 'P2P');
      return;
    }

    try {
      _isServerRunning = true;
      notifyListeners();
      
      await _registerCurrentDevice(userId);
      
      logger.info('Servidor iniciado: $displayName ($userId)', tag: 'P2P');
    } catch (e) {
      logger.error('Erro ao iniciar servidor', tag: 'P2P', error: e);
      throw P2PException.connectionFailed('Falha ao iniciar servidor', error: e);
    }
  }

  Future<void> _registerCurrentDevice(String userId) async {
    final deviceId = 'device_${_crypto.generateUniqueId().substring(0, 8)}';
    final publicKey = _crypto.generateKeyPair().publicKey;
    
    final deviceKey = DeviceKey(
      deviceId: deviceId,
      userId: userId,
      publicKey: publicKey,
      lastSeen: DateTime.now(),
      isCurrentDevice: true,
    );
    
    await _db.insertDeviceKey(deviceKey);
    logger.info('Dispositivo registrado: $deviceId', tag: 'P2P');
  }

  Future<void> stopServer() async {
    if (!_isServerRunning) return;

    try {
      _isServerRunning = false;
      _connectedPeers.clear();
      notifyListeners();
      
      logger.info('Servidor parado', tag: 'P2P');
    } catch (e) {
      logger.error('Erro ao parar servidor', tag: 'P2P', error: e);
    }
  }

  Future<void> startDiscovery() async {
    if (_isDiscovering) {
      logger.warn('Descoberta já está ativa', tag: 'P2P');
      return;
    }

    try {
      _isDiscovering = true;
      _discoveredPeers.clear();
      notifyListeners();
      
      _simulateDiscovery();
      
      logger.info('Descoberta iniciada', tag: 'P2P');
    } catch (e) {
      logger.info('Erro ao iniciar descoberta: $e', tag: 'P2P');
      throw Exception('Falha ao iniciar descoberta: $e');
    }
  }

  Future<void> stopDiscovery() async {
    if (!_isDiscovering) return;

    try {
      _isDiscovering = false;
      notifyListeners();
      
      logger.info('Descoberta parada', tag: 'P2P');
    } catch (e) {
      logger.info('Erro ao parar descoberta: $e', tag: 'P2P');
    }
  }

  void _simulateDiscovery() {
    Future.delayed(const Duration(seconds: 2), () {
      if (_isDiscovering) {
        final mockPeer = Peer(
          peerId: 'mock-peer-${DateTime.now().millisecondsSinceEpoch}',
          displayName: 'Dispositivo Simulado',
          publicKey: 'mock-public-key',
          connectionType: 'wifi-direct',
          signalStrength: -60,
        );
        _discoveredPeers.add(mockPeer);
        notifyListeners();
      }
    });
  }

  Future<bool> connectToPeer(Peer peer) async {
    try {
      final success = await Future.any([
        Future.delayed(const Duration(seconds: 10), () => false),
        _establishConnection(peer),
      ]);
      
      if (!success) {
        logger.error('Timeout de conexão com o peer: ${peer.displayName}', tag: 'P2P');
        throw P2PException.connectionFailed('Timeout ao tentar conectar com ${peer.displayName}');
      }
      
      logger.info('Conectado ao peer: ${peer.displayName}', tag: 'P2P');
      return true;
    } on P2PException catch (e) {
      logger.error('Erro P2P ao conectar ao peer: ${e.message}', tag: 'P2P');
      return false;
    } catch (e) {
      logger.error('Erro inesperado ao conectar ao peer: $e', tag: 'P2P');
      return false;
    }
  }

  Future<bool> _establishConnection(Peer peer) async {
    await Future.delayed(const Duration(seconds: 2));
    
    if (!_connectedPeers.any((p) => p.peerId == peer.peerId)) {
      _connectedPeers.add(peer);
      _discoveredPeers.removeWhere((p) => p.peerId == peer.peerId);
      notifyListeners();
    }
    return true;
  }

  Future<void> disconnectFromPeer(String peerId) async {
    try {
      _connectedPeers.removeWhere((p) => p.peerId == peerId);
      notifyListeners();
      
      logger.info('Desconectado do peer: $peerId', tag: 'P2P');
    } catch (e) {
      logger.info('Erro ao desconectar do peer: $e', tag: 'P2P');
    }
  }

  Future<bool> sendMessage(String peerId, P2PMessage message) async {
    try {
      final peer = _connectedPeers.firstWhere(
        (p) => p.peerId == peerId,
        orElse: () => throw Exception('Peer não conectado'),
      );
      
      PacketPriority priority;
      switch (message.type) {
        case 'file_chunk':
        case 'ledger_sync':
          priority = PacketPriority.bulk;
          break;
        case 'handshake_init':
        case 'handshake_response':
        case 'panic_alert':
          priority = PacketPriority.critical;
          break;
        default:
          priority = PacketPriority.normal;
      }
      
      _trafficManager.handlePacket(message, peerId, priority);
      
      logger.info('Mensagem entregue ao TrafficManager para ${peer.displayName}: ${message.type} (Prioridade: $priority)', tag: 'P2P');
      
      return true;
    } catch (e) {
      logger.error('Erro ao enviar mensagem', tag: 'P2P', error: e);
      return false;
    }
  }

  /// Envio real de dados brutos (chamado pelo TrafficManager)
  Future<bool> sendDataRaw(String peerId, P2PMessage message, {required PacketPriority priority}) async {
    try {
      final stealth = StealthModeService();
      
      // 1. Aplicar Jitter para quebrar padrões temporais
      await stealth.applyJitter();

      // 2. Comprimir se for bulk ou normal grande
      final payload = message.toMap();
      var dataToTransmit = PacketCompressor.compress(payload);
      
      // 3. Aplicar Padding se estiver em modo Stealth para ofuscar tamanho
      dataToTransmit = stealth.applyPadding(dataToTransmit);
      
      // 4. Simulação de envio pelo rádio (Bluetooth/Wi-Fi Direct)
      logger.debug('Transmitindo ${dataToTransmit.length} bytes para $peerId (Prioridade: $priority, Stealth: ${stealth.isEnabled})', tag: 'P2P');
      
      // Simula latência de rede mesh
      await Future.delayed(Duration(milliseconds: priority == PacketPriority.bulk ? 50 : 10));
      
      return true;
    } catch (e) {
      logger.error('Falha na transmissão bruta', tag: 'P2P', error: e);
      return false;
    }
  }

  Future<void> _sendFileInChunks(String peerId, String fileId, String filePath) async {
    const int chunkSize = 1024 * 50;
    const int fileSize = 1024 * 1024 * 2;
    final int totalChunks = (fileSize / chunkSize).ceil();
    
    logger.info('Iniciando transferência de arquivo $fileId para $peerId. Total de chunks: $totalChunks', tag: 'P2P');

    for (int i = 0; i < totalChunks; i++) {
      final chunkData = Uint8List(chunkSize);
      final checksum = 'mock_checksum_$i';
      
      final chunk = FileChunk(
        fileId: fileId,
        chunkIndex: i,
        totalChunks: totalChunks,
        data: chunkData,
        checksum: checksum,
      );
      
      final chunkMessage = P2PMessage(
        messageId: _crypto.generateUniqueId(),
        senderId: 'self',
        receiverId: peerId,
        type: 'file_chunk',
        payload: chunk.toMap(),
      );
      
      _dispatcher.enqueueMessage(
        message: chunkMessage,
        peerId: peerId,
        priorityType: MessagePriority.BULK,
        senderId: 'self',
      );
      
      logger.debug('Chunk $i/$totalChunks enviado para $peerId', tag: 'P2P');
      await Future.delayed(const Duration(milliseconds: 10));
    }
    
    logger.info('Transferência de arquivo $fileId concluída para $peerId', tag: 'P2P');
  }

  Future<void> broadcastMessage(P2PMessage message) async {
    for (final peer in _connectedPeers) {
      await sendMessage(peer.peerId, message);
    }
  }

  /// NOVO: Envio de Transação Criptoativa
  Future<bool> sendCoinTransaction({
    required String receiverPublicKey,
    required double amount,
    double fee = 0.001,
    String? memo,
  }) async {
    try {
      final senderPublicKey = 'self_public_key';
      
      final transaction = CoinTransaction(
        transactionId: _crypto.generateUniqueId(),
        senderPublicKey: senderPublicKey,
        receiverPublicKey: receiverPublicKey,
        amount: amount,
        fee: fee,
        timestamp: DateTime.now(),
        signature: _crypto.generateUniqueId(),
        memo: memo,
      );
      
      final transactionMessage = P2PMessage(
        messageId: _crypto.generateUniqueId(),
        senderId: 'self',
        receiverId: 'network_broadcast',
        type: 'coin_transaction',
        payload: transaction.toMap(),
      );
      
      // Usa broadcast para atingir o máximo de nós e iniciar o processo de consenso/ledger
      await broadcastMessage(transactionMessage);
      
      logger.info('Transação ${transaction.transactionId} de ${amount} enviada para o broadcast.', tag: 'P2P_TX');
      return true;
    } catch (e) {
      logger.error('Falha ao enviar transação: $e', tag: 'P2P_TX', error: e);
      return false;
    }
  }

  void _onMessageReceived(String peerId, Map<String, dynamic> data) {
    try {
      final message = P2PMessage.fromMap(data);
      
      // NOVO: Manipular Transações
      if (message.type == 'coin_transaction') {
        _handleCoinTransaction(message);
        return;
      }
      
      if (message.type == 'sync_request' || message.type == 'sync_response') {
        _handleSyncMessage(message);
        return;
      }
      
      if (message.type == 'file_chunk') {
        _handleFileChunk(message);
        return;
      }
      
      _handleIncomingMessage(message);
      
      logger.info('Mensagem recebida de $peerId: ${message.type}', tag: 'P2P');
    } catch (e) {
      logger.info('Erro ao processar mensagem recebida: $e', tag: 'P2P');
    }
  }

  /// NOVO: Manipulador de Transação Criptoativa
  void _handleCoinTransaction(P2PMessage message) {
    try {
      final tx = CoinTransaction.fromMap(message.payload);
      
      // Simulação: Verificação de Assinatura e Validade
      // if (!_crypto.verifySignature(tx.payloadToSign, tx.signature, tx.senderPublicKey)) {
      //   logger.error('Transação inválida: Assinatura falhou para ${tx.transactionId}', tag: 'P2P_TX');
      //   _reputationCore.penalizePeer(message.senderId);
      //   return;
      // }
      
      // Propagar para o restante da rede (Mesh)
      propagateMessage(message, excludePeerId: message.senderId);
      
      logger.info(
        'TX recebida: ${tx.transactionId.substring(0, 8)} (${tx.amount} moedas). Propagando...', 
        tag: 'P2P_TX'
      );

      // Notificação local para o destinatário
      if (tx.receiverPublicKey == 'self_public_key') {
         _notificationService.handleNewMessage(
           senderId: tx.senderPublicKey, 
           senderName: 'Sistema TX', 
           messageContent: 'Você recebeu ${tx.amount} moedas!',
         );
      }
    } catch (e) {
      logger.error('Erro ao manipular transação: $e', tag: 'P2P_TX');
    }
  }

  Future<void> synchronizeState(String peerId) async {
    logger.info('Iniciando sincronização de estado com $peerId', tag: 'P2P');
    
    final syncRequest = P2PMessage(
      messageId: _crypto.generateUniqueId(),
      senderId: 'self',
      receiverId: peerId,
      type: 'sync_request',
      payload: {
        'last_sync_timestamp': DateTime.now().subtract(const Duration(days: 7)).toIso8601String(),
        'current_device_id': 'mock_device_id',
      },
    );
    await sendMessage(peerId, syncRequest);
    
    logger.info('Sync Request enviado para $peerId', tag: 'P2P');
  }

  void _handleSyncMessage(P2PMessage message) {
    logger.info('Mensagem de sincronização recebida: ${message.type}', tag: 'P2P');
    
    final remoteDeviceId = message.payload['current_device_id'] as String?;
    if (remoteDeviceId == 'mock_device_id') {
      logger.warn('Mensagem de sincronização ignorada (dispositivo local)', tag: 'P2P');
      return;
    }
    
    if (message.type == 'sync_request') {
      final syncData = {
        'new_messages': 5,
        'updated_contacts': 2,
        'read_receipts': ['msg_id_1', 'msg_id_2'],
      };
      
      final syncResponse = P2PMessage(
        messageId: _crypto.generateUniqueId(),
        senderId: 'self',
        receiverId: message.senderId,
        type: 'sync_response',
        payload: {'status': 'success', 'data': syncData},
      );
      sendMessage(message.senderId, syncResponse);
      
      logger.info('Sync Response enviado com dados de estado.', tag: 'P2P');
      
    } else if (message.type == 'sync_response') {
      final syncData = message.payload['data'] as Map<String, dynamic>;
      
      logger.info('Sync Response recebido. Aplicando ${syncData['new_messages']} novas mensagens.', tag: 'P2P');
    }
  }

  void _handleFileChunk(P2PMessage message) {
    try {
      final chunk = FileChunk.fromMap(message.payload);
      
      logger.debug('Chunk ${chunk.chunkIndex}/${chunk.totalChunks} recebido para arquivo ${chunk.fileId}', tag: 'P2P');
      
      if (chunk.chunkIndex == chunk.totalChunks - 1) {
        logger.info('Arquivo ${chunk.fileId} recebido e remontado com sucesso.', tag: 'P2P');
        
        final fileCompleteMessage = P2PMessage(
          messageId: _crypto.generateUniqueId(),
          senderId: message.senderId,
          receiverId: 'self',
          type: 'file_received',
          payload: {'fileId': chunk.fileId, 'filePath': '/temp/${chunk.fileId}.png'},
        );
        _handleIncomingMessage(fileCompleteMessage);
      }
    } catch (e) {
      logger.error('Erro ao processar chunk de arquivo: $e', tag: 'P2P');
    }
  }

  void _handleIncomingMessage(P2PMessage message) {
    _messageStreamController.add(message);

    if (message.type == 'text' || message.type == 'audio') {
      final senderName = 'Peer ${message.senderId.substring(0, 4)}';
      final content = message.type == 'text' ? 'Nova mensagem de texto' : 'Nova mensagem de voz';
      
      _notificationService.handleNewMessage(
        senderId: message.senderId,
        senderName: senderName,
        messageContent: content,
      );
    }
  }

  List<List<Peer>> findAllRoutes(String destinationId) {
    try {
      final destinationPeer = _connectedPeers.firstWhere(
        (p) => p.peerId == destinationId,
        orElse: () => throw Exception('Peer não conectado'),
      );
      
      final route1 = [destinationPeer];
      final routes = [route1];
      
      if (_connectedPeers.length > 1) {
        final otherPeer = _connectedPeers.firstWhere((p) => p.peerId != destinationId);
        routes.add([otherPeer, destinationPeer]);
      }
      
      return routes;
    } catch (e) {
      logger.warn('Falha ao encontrar rotas para $destinationId: $e', tag: 'P2P');
      return [];
    }
  }

  Future<void> sendDataToTransport({
    required String peerId,
    required String data,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final peer = _connectedPeers.firstWhere(
        (p) => p.peerId == peerId,
        orElse: () => throw Exception('Peer não conectado'),
      );
      
      logger.debug('Dados enviados para ${peer.displayName} (Tamanho: ${data.length}, Metadata: $metadata)', tag: 'P2P');
      
      await Future.delayed(const Duration(milliseconds: 50));
    } catch (e) {
      logger.error('Falha ao enviar dados para $peerId: $e', tag: 'P2P');
      throw P2PException.sendFailed('Falha ao enviar dados', error: e);
    }
  }

  bool isSendingLimitReached() {
    return false;
  }

  Future<void> propagateMessage(P2PMessage message, {String? excludePeerId}) async {
    try {
      for (final peer in _connectedPeers) {
        if (peer.peerId != excludePeerId) {
          _dispatcher.enqueueMessage(
            message: message.incrementHop(),
            peerId: peer.peerId,
            priorityType: MessagePriority.SYNC,
            senderId: message.senderId,
          );
        }
      }
      
      logger.info('Mensagem propagada na mesh: ${message.messageId}', tag: 'P2P');
    } catch (e) {
      logger.info('Erro ao propagar mensagem: $e', tag: 'P2P');
    }
  }

  @override
  void dispose() {
    stopServer();
    stopDiscovery();
    _messageStreamController.close();
    super.dispose();
  }
}

// ==================== CLASSES AUXILIARES ====================

class Peer {
  final String peerId;
  final String displayName;
  final String publicKey;
  final String connectionType;
  final int signalStrength;
  final DateTime discoveredAt;

  Peer({
    required this.peerId,
    required this.displayName,
    required this.publicKey,
    required this.connectionType,
    required this.signalStrength,
    DateTime? discoveredAt,
  }) : discoveredAt = discoveredAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'peerId': peerId,
      'displayName': displayName,
      'publicKey': publicKey,
      'connectionType': connectionType,
      'signalStrength': signalStrength,
      'discoveredAt': discoveredAt.toIso8601String(),
    };
  }

  factory Peer.fromMap(Map<String, dynamic> map) {
    return Peer(
      peerId: map['peerId'] as String,
      displayName: map['displayName'] as String,
      publicKey: map['publicKey'] as String,
      connectionType: map['connectionType'] as String,
      signalStrength: map['signalStrength'] as int,
      discoveredAt: DateTime.parse(map['discoveredAt'] as String),
    );
  }
}

class P2PMessage {
  final String messageId;
  final String senderId;
  final String receiverId;
  final String type;
  final Map<String, dynamic> payload;
  final int hopCount;
  final DateTime timestamp;

  P2PMessage({
    required this.messageId,
    required this.senderId,
    required this.receiverId,
    required this.type,
    required this.payload,
    this.hopCount = 0,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'messageId': messageId,
      'senderId': senderId,
      'receiverId': receiverId,
      'type': type,
      'payload': payload,
      'hopCount': hopCount,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory P2PMessage.fromMap(Map<String, dynamic> map) {
    return P2PMessage(
      messageId: map['messageId'] as String,
      senderId: map['senderId'] as String,
      receiverId: map['receiverId'] as String,
      type: map['type'] as String,
      payload: map['payload'] as Map<String, dynamic>,
      hopCount: map['hopCount'] as int? ?? 0,
      timestamp: DateTime.parse(map['timestamp'] as String),
    );
  }

  P2PMessage incrementHop() {
    return P2PMessage(
      messageId: messageId,
      senderId: senderId,
      receiverId: receiverId,
      type: type,
      payload: payload,
      hopCount: hopCount + 1,
      timestamp: timestamp,
    );
  }
}

// NOVA CLASSE DE TRANSAÇÃO (REALISMO ECONÔMICO)
class CoinTransaction {
  final String transactionId;
  final String senderPublicKey;
  final String receiverPublicKey;
  final double amount;
  final double fee;
  final DateTime timestamp;
  final String signature;
  final String? memo;

  CoinTransaction({
    required this.transactionId,
    required this.senderPublicKey,
    required this.receiverPublicKey,
    required this.amount,
    required this.fee,
    required this.timestamp,
    required this.signature,
    this.memo,
  });

  Map<String, dynamic> toMap() {
    return {
      'transactionId': transactionId,
      'senderPublicKey': senderPublicKey,
      'receiverPublicKey': receiverPublicKey,
      'amount': amount,
      'fee': fee,
      'timestamp': timestamp.toIso8601String(),
      'signature': signature,
      'memo': memo,
    };
  }

  factory CoinTransaction.fromMap(Map<String, dynamic> map) {
    return CoinTransaction(
      transactionId: map['transactionId'] as String,
      senderPublicKey: map['senderPublicKey'] as String,
      receiverPublicKey: map['receiverPublicKey'] as String,
      amount: map['amount'] as double,
      fee: map['fee'] as double,
      timestamp: DateTime.parse(map['timestamp'] as String),
      signature: map['signature'] as String,
      memo: map['memo'] as String?,
    );
  }

  String get payloadToSign {
    return '$transactionId|$senderPublicKey|$receiverPublicKey|$amount|$fee|${timestamp.toIso8601String()}';
  }
}
