import 'package:flutter/material.dart';
import '../../core/storage/encrypted_message_store.dart';
import '../../core/mesh/message_queue_processor.dart';

/// Modelo de dados para a Thread de Mensagens (Conversa)
class MessageThread {
  final String id;
  final String peerId; // O ID do peer com quem a thread está
  final String displayName;
  final int unreadCount;
  final MeshMessageRecord? lastMessage;

  MessageThread({
    required this.id,
    required this.peerId,
    required this.displayName,
    this.unreadCount = 0,
    this.lastMessage,
  });

  // Construtor de exemplo para simulação
  factory MessageThread.mock(String id, String peerId, String displayName, int unreadCount, MeshMessageRecord? lastMessage) {
    return MessageThread(
      id: id,
      peerId: peerId,
      displayName: displayName,
      unreadCount: unreadCount,
      lastMessage: lastMessage,
    );
  }
}

/// Modelo de dados para a Mensagem (Bubble)
class MessageBubble {
  final String id;
  final String content;
  final String senderId;
  final String receiverId;
  final DateTime timestamp;
  final MessagePriority priority;
  final String status; // 'sent', 'delivered', 'failed', 'received'
  final bool isSelf;

  MessageBubble({
    required this.id,
    required this.content,
    required this.senderId,
    required this.receiverId,
    required this.timestamp,
    required this.priority,
    required this.status,
    required this.isSelf,
  });

  /// Converte um MeshMessageRecord do storage para um MessageBubble da UI
  factory MessageBubble.fromRecord(MeshMessageRecord record, String currentPeerId) {
    // Simular a prioridade a partir do metadata ou do conteúdo
    MessagePriority priority = MessagePriority.normal;
    if (record.metadata.containsKey('priority')) {
      try {
        priority = MessagePriority.values.firstWhere(
          (e) => e.toString() == 'MessagePriority.${record.metadata['priority']}',
          orElse: () => MessagePriority.normal,
        );
      } catch (_) {
        // Ignorar erro de parsing
      }
    } else if (record.content.toLowerCase().contains('emergency') || record.content.toLowerCase().contains('wipe')) {
      priority = MessagePriority.critical;
    }

    return MessageBubble(
      id: record.id,
      content: record.content,
      senderId: record.senderId,
      receiverId: record.receiverId ?? '',
      timestamp: DateTime.fromMillisecondsSinceEpoch(record.timestamp),
      priority: priority,
      status: record.status,
      isSelf: record.senderId == currentPeerId,
    );
  }
}

/// Gerenciador de Estado para a Tela de Mensagens
class MessageStateProvider extends ChangeNotifier {
  final EncryptedMessageStore _storage = EncryptedMessageStore();
  final MessageQueueProcessor _queue = MessageQueueProcessor();
  final String _currentPeerId;

  List<MessageThread> _threads = [];
  List<MessageBubble> _currentMessages = [];
  MessageThread? _activeThread;

  List<MessageThread> get threads => _threads;
  List<MessageBubble> get currentMessages => _currentMessages;
  MessageThread? get activeThread => _activeThread;

  MessageStateProvider(this._currentPeerId) {
    _loadThreads();
    _queue.onMessageProcessed = _handleMessageProcessed;
    _queue.onMessageError = _handleMessageError;
  }

  /// Carrega todas as threads (peers conhecidos)
  Future<void> _loadThreads() async {
    final peers = await _storage.getAllPeers();
    
    // Simulação de threads a partir de peers
    _threads = peers.map((peer) {
      // Simular displayName
      final displayName = peer.displayName ?? 'Nó Desconhecido ${peer.peerId.substring(0, 4)}';
      
      // Simular última mensagem
      // Em um app real, buscaria a última mensagem do peer
      final lastMessage = MeshMessageRecord(
        id: 'mock_last_${peer.peerId}',
        content: 'Última mensagem de ${displayName}',
        senderId: peer.peerId,
        receiverId: _currentPeerId,
        ttl: 3,
        originNodeId: peer.peerId,
        visitedNodes: [peer.peerId, _currentPeerId],
        metadata: {'priority': 'normal'},
        timestamp: DateTime.now().millisecondsSinceEpoch - 60000,
        status: 'delivered',
        createdAt: DateTime.now().millisecondsSinceEpoch - 60000,
      );

      return MessageThread(
        id: peer.peerId,
        peerId: peer.peerId,
        displayName: displayName,
        unreadCount: 0,
        lastMessage: lastMessage,
      );
    }).toList();

    // Adicionar um mock de thread se não houver peers
    if (_threads.isEmpty) {
      _threads.add(MessageThread.mock(
        'mock_peer_1',
        'mock_peer_1',
        'Nó de Teste (Mock)',
        2,
        MeshMessageRecord(
          id: 'mock_last_1',
          content: 'ALERTA CRÍTICO: Invasão detectada.',
          senderId: 'mock_peer_1',
          receiverId: _currentPeerId,
          ttl: 3,
          originNodeId: 'mock_peer_1',
          visitedNodes: ['mock_peer_1', _currentPeerId],
          metadata: {'priority': 'critical'},
          timestamp: DateTime.now().millisecondsSinceEpoch - 10000,
          status: 'received',
          createdAt: DateTime.now().millisecondsSinceEpoch - 10000,
        ),
      ));
    }

    notifyListeners();
  }

  /// Define a thread ativa e carrega as mensagens
  Future<void> setActiveThread(MessageThread thread) async {
    _activeThread = thread;
    await _loadMessages(thread.peerId);
    notifyListeners();
  }

  /// Carrega mensagens da thread ativa
  Future<void> _loadMessages(String peerId) async {
    // Buscar mensagens onde o sender ou receiver é o peerId
    final sentMessages = await _storage.getMessages(senderId: peerId);
    final receivedMessages = await _storage.getMessages(receiverId: peerId);

    final allRecords = [...sentMessages, ...receivedMessages];
    
    // Converter e ordenar
    _currentMessages = allRecords
        .map((record) => MessageBubble.fromRecord(record, _currentPeerId))
        .toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    notifyListeners();
  }

  /// Envia uma nova mensagem
  Future<void> sendMessage(String content, MessagePriority priority) async {
    if (_activeThread == null) return;

    // 1. Criar registro temporário para a UI
    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    final tempMessage = MessageBubble(
      id: tempId,
      content: content,
      senderId: _currentPeerId,
      receiverId: _activeThread!.peerId,
      timestamp: DateTime.now(),
      priority: priority,
      status: 'pending',
      isSelf: true,
    );

    _currentMessages.add(tempMessage);
    notifyListeners();

    // 2. Enfileirar para processamento
    await _queue.enqueue(
      content,
      _currentPeerId,
      receiverId: _activeThread!.peerId,
      priority: priority,
      metadata: {'priority': priority.toString().split('.').last},
    );
    
    // 3. Atualizar status no storage (será feito pelo queue processor)
    // Para a UI, vamos simular a atualização após um pequeno delay
    Future.delayed(const Duration(seconds: 1), () {
      _updateMessageStatus(tempId, 'sent');
    });
  }

  /// Atualiza o status de uma mensagem na UI
  void _updateMessageStatus(String tempId, String newStatus) {
    final index = _currentMessages.indexWhere((m) => m.id == tempId);
    if (index != -1) {
      final oldMessage = _currentMessages[index];
      _currentMessages[index] = MessageBubble(
        id: oldMessage.id,
        content: oldMessage.content,
        senderId: oldMessage.senderId,
        receiverId: oldMessage.receiverId,
        timestamp: oldMessage.timestamp,
        priority: oldMessage.priority,
        status: newStatus,
        isSelf: oldMessage.isSelf,
      );
      notifyListeners();
    }
  }

  /// Lida com mensagens processadas pelo queue
  void _handleMessageProcessed(QueuedMessage message) {
    // Se a mensagem foi processada com sucesso, ela já está no storage.
    // Recarregar a thread para garantir consistência.
    if (_activeThread?.peerId == message.receiverId || _activeThread?.peerId == message.senderId) {
      _loadMessages(_activeThread!.peerId);
    }
    _loadThreads(); // Atualizar última mensagem da thread
  }

  /// Lida com erros de processamento
  void _handleMessageError(QueuedMessage message, dynamic error) {
    // Marcar como falha na UI
    _updateMessageStatus(message.id, 'failed');
    _loadThreads();
  }

  @override
  void dispose() {
    // Remover listeners do queue
    _queue.onMessageProcessed = null;
    _queue.onMessageError = null;
    super.dispose();
  }
}
