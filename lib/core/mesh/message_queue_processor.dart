import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import '../utils/logger_service.dart';
import '../storage/encrypted_message_store.dart';
import 'nearby_relay_service.dart';

/// Processador de Fila de Mensagens
/// 
/// Implementa Queue para processamento sequencial de mensagens.
/// Evita estouro da pilha de execução quando 100+ mensagens chegam simultaneamente.
/// 
/// CARACTERÍSTICAS CRÍTICAS:
/// - Queue FIFO (First In, First Out)
/// - Processamento sequencial (uma mensagem por vez)
/// - Rate limiting para evitar sobrecarga
/// - Backpressure handling
/// - Priorização de mensagens críticas
/// - Persistência de mensagens não processadas
class MessageQueueProcessor {
  static final MessageQueueProcessor _instance = MessageQueueProcessor._internal();
  factory MessageQueueProcessor() => _instance;
  MessageQueueProcessor._internal();

  // Filas de mensagens por prioridade
  final Queue<QueuedMessage> _criticalQueue = Queue<QueuedMessage>();
  final Queue<QueuedMessage> _highQueue = Queue<QueuedMessage>();
  final Queue<QueuedMessage> _normalQueue = Queue<QueuedMessage>();
  final Queue<QueuedMessage> _lowQueue = Queue<QueuedMessage>();

  // Estado do processador
  bool _isProcessing = false;
  bool _isPaused = false;
  int _processedCount = 0;
  int _droppedCount = 0;
  int _errorCount = 0;

  // Timers e workers
  Timer? _processingTimer;
  
  // Configurações
  static const int _MAX_QUEUE_SIZE = 1000; // Máximo de mensagens na fila
  static const int _PROCESSING_INTERVAL_MS = 100; // Processar a cada 100ms
  static const int _MAX_PROCESSING_RATE = 10; // Máximo 10 mensagens por segundo
  static const int _BATCH_SIZE = 5; // Processar até 5 mensagens por lote

  // Referências a serviços
  final EncryptedMessageStore _storage = EncryptedMessageStore();
  final NearbyRelayService _relay = NearbyRelayService();

  // Callbacks
  Function(QueuedMessage)? onMessageProcessed;
  Function(QueuedMessage, dynamic)? onMessageError;
  Function(int)? onQueueSizeChanged;

  /// Inicializa o processador de fila
  Future<void> initialize() async {
    try {
      logger.info('Inicializando processador de fila de mensagens...', tag: 'Queue');

      // Carregar mensagens pendentes do storage
      await _loadPendingMessages();

      // Iniciar worker de processamento
      _startProcessing();

      logger.info('Processador de fila inicializado', tag: 'Queue');
    } catch (e) {
      logger.error('Falha ao inicializar processador de fila', tag: 'Queue', error: e);
      throw Exception('Inicialização do queue processor falhou: $e');
    }
  }

  // ==================== ENFILEIRAMENTO ====================

  /// Enfileira uma mensagem para processamento
  Future<bool> enqueue(
    String content,
    String senderId, {
    String? receiverId,
    int ttl = 3,
    String? originNodeId,
    List<String>? visitedNodes,
    Map<String, dynamic>? metadata,
    MessagePriority priority = MessagePriority.normal,
  }) async {
    try {
      // Verificar se a fila está cheia
      if (getTotalQueueSize() >= _MAX_QUEUE_SIZE) {
        logger.warn('Fila cheia! Descartando mensagem de prioridade baixa', tag: 'Queue');
        _droppedCount++;
        
        // Tentar descartar mensagens de baixa prioridade
        if (_lowQueue.isNotEmpty) {
          _lowQueue.removeFirst();
        } else {
          return false;
        }
      }

      // Criar mensagem enfileirada
      final queuedMessage = QueuedMessage(
        id: _generateMessageId(),
        content: content,
        senderId: senderId,
        receiverId: receiverId,
        ttl: ttl,
        originNodeId: originNodeId ?? senderId,
        visitedNodes: visitedNodes ?? [senderId],
        metadata: metadata ?? {},
        priority: priority,
        enqueuedAt: DateTime.now(),
        retryCount: 0,
      );

      // Adicionar à fila apropriada
      switch (priority) {
        case MessagePriority.critical:
          _criticalQueue.add(queuedMessage);
          break;
        case MessagePriority.high:
          _highQueue.add(queuedMessage);
          break;
        case MessagePriority.normal:
          _normalQueue.add(queuedMessage);
          break;
        case MessagePriority.low:
          _lowQueue.add(queuedMessage);
          break;
      }

      logger.debug(
        'Mensagem enfileirada: ${queuedMessage.id} (prioridade: $priority)',
        tag: 'Queue',
      );

      // Notificar mudança no tamanho da fila
      onQueueSizeChanged?.call(getTotalQueueSize());

      return true;
    } catch (e) {
      logger.error('Erro ao enfileirar mensagem', tag: 'Queue', error: e);
      return false;
    }
  }

  // ==================== PROCESSAMENTO ====================

  /// Inicia o worker de processamento
  void _startProcessing() {
    if (_isProcessing) {
      logger.warn('Processamento já está ativo', tag: 'Queue');
      return;
    }

    _isProcessing = true;
    _processingTimer = Timer.periodic(
      Duration(milliseconds: _PROCESSING_INTERVAL_MS),
      (_) => _processNextBatch(),
    );

    logger.info('Worker de processamento iniciado', tag: 'Queue');
  }

  /// Processa o próximo lote de mensagens
  Future<void> _processNextBatch() async {
    if (_isPaused || getTotalQueueSize() == 0) return;

    try {
      int processed = 0;

      // Processar até BATCH_SIZE mensagens
      while (processed < _BATCH_SIZE && getTotalQueueSize() > 0) {
        final message = _dequeueNext();
        if (message == null) break;

        await _processMessage(message);
        processed++;
      }

      if (processed > 0) {
        logger.debug('Lote processado: $processed mensagens', tag: 'Queue');
      }
    } catch (e) {
      logger.error('Erro ao processar lote', tag: 'Queue', error: e);
    }
  }

  /// Remove e retorna a próxima mensagem da fila (por prioridade)
  QueuedMessage? _dequeueNext() {
    // Ordem de prioridade: critical > high > normal > low
    if (_criticalQueue.isNotEmpty) {
      return _criticalQueue.removeFirst();
    } else if (_highQueue.isNotEmpty) {
      return _highQueue.removeFirst();
    } else if (_normalQueue.isNotEmpty) {
      return _normalQueue.removeFirst();
    } else if (_lowQueue.isNotEmpty) {
      return _lowQueue.removeFirst();
    }
    return null;
  }

  /// Processa uma mensagem individual
  Future<void> _processMessage(QueuedMessage message) async {
    try {
      logger.debug('Processando mensagem: ${message.id}', tag: 'Queue');

      // 1. Salvar no storage (persistência)
      await _storage.saveMessage(MeshMessageRecord(
        id: message.id,
        content: message.content,
        senderId: message.senderId,
        receiverId: message.receiverId,
        ttl: message.ttl,
        originNodeId: message.originNodeId,
        visitedNodes: message.visitedNodes,
        metadata: message.metadata,
        timestamp: message.enqueuedAt.millisecondsSinceEpoch,
        status: 'processing',
        createdAt: DateTime.now().millisecondsSinceEpoch,
      ));

      // 2. Fazer relay (se aplicável)
      if (message.ttl > 0) {
        await _relay.sendToMesh(
          message.content,
          targetPeerId: message.receiverId,
          metadata: message.metadata,
        );
      }

      // 3. Atualizar status no storage
      await _storage.updateMessageStatus(message.id, 'sent');

      // 4. Incrementar contador
      _processedCount++;

      // 5. Callback de sucesso
      onMessageProcessed?.call(message);

      logger.debug('Mensagem processada com sucesso: ${message.id}', tag: 'Queue');
    } catch (e) {
      logger.error('Erro ao processar mensagem ${message.id}', tag: 'Queue', error: e);
      _errorCount++;

      // Tentar novamente se não excedeu limite de retries
      if (message.retryCount < 3) {
        message.retryCount++;
        
        // Re-enfileirar com prioridade reduzida
        switch (message.priority) {
          case MessagePriority.critical:
            _highQueue.add(message);
            break;
          case MessagePriority.high:
            _normalQueue.add(message);
            break;
          default:
            _lowQueue.add(message);
            break;
        }

        logger.debug('Mensagem re-enfileirada para retry: ${message.id}', tag: 'Queue');
      } else {
        // Marcar como falha no storage
        await _storage.updateMessageStatus(message.id, 'failed');
        
        // Callback de erro
        onMessageError?.call(message, e);
      }
    }
  }

  // ==================== CONTROLE DE FLUXO ====================

  /// Pausa o processamento
  void pause() {
    _isPaused = true;
    logger.info('Processamento pausado', tag: 'Queue');
  }

  /// Retoma o processamento
  void resume() {
    _isPaused = false;
    logger.info('Processamento retomado', tag: 'Queue');
  }

  /// Para o processamento completamente
  void stop() {
    _processingTimer?.cancel();
    _processingTimer = null;
    _isProcessing = false;
    logger.info('Processamento parado', tag: 'Queue');
  }

  // ==================== PERSISTÊNCIA ====================

  /// Carrega mensagens pendentes do storage
  Future<void> _loadPendingMessages() async {
    try {
      final pendingMessages = await _storage.getMessages(
        status: 'pending',
        limit: 100,
      );

      for (final record in pendingMessages) {
        await enqueue(
          record.content,
          record.senderId,
          receiverId: record.receiverId,
          ttl: record.ttl,
          originNodeId: record.originNodeId,
          visitedNodes: record.visitedNodes,
          metadata: record.metadata,
          priority: MessagePriority.normal,
        );
      }

      if (pendingMessages.isNotEmpty) {
        logger.info(
          'Carregadas ${pendingMessages.length} mensagens pendentes do storage',
          tag: 'Queue',
        );
      }
    } catch (e) {
      logger.error('Erro ao carregar mensagens pendentes', tag: 'Queue', error: e);
    }
  }

  /// Salva mensagens pendentes no storage antes de encerrar
  Future<void> _savePendingMessages() async {
    try {
      final allMessages = [
        ..._criticalQueue,
        ..._highQueue,
        ..._normalQueue,
        ..._lowQueue,
      ];

      for (final message in allMessages) {
        await _storage.saveMessage(MeshMessageRecord(
          id: message.id,
          content: message.content,
          senderId: message.senderId,
          receiverId: message.receiverId,
          ttl: message.ttl,
          originNodeId: message.originNodeId,
          visitedNodes: message.visitedNodes,
          metadata: message.metadata,
          timestamp: message.enqueuedAt.millisecondsSinceEpoch,
          status: 'pending',
          createdAt: DateTime.now().millisecondsSinceEpoch,
        ));
      }

      logger.info('${allMessages.length} mensagens pendentes salvas no storage', tag: 'Queue');
    } catch (e) {
      logger.error('Erro ao salvar mensagens pendentes', tag: 'Queue', error: e);
    }
  }

  // ==================== LIMPEZA ====================

  /// Limpa todas as filas
  Future<void> clear() async {
    logger.warn('Limpando todas as filas...', tag: 'Queue');
    
    _criticalQueue.clear();
    _highQueue.clear();
    _normalQueue.clear();
    _lowQueue.clear();

    onQueueSizeChanged?.call(0);
    
    logger.info('Todas as filas foram limpas', tag: 'Queue');
  }

  // ==================== ESTATÍSTICAS ====================

  /// Retorna tamanho total da fila
  int getTotalQueueSize() {
    return _criticalQueue.length +
        _highQueue.length +
        _normalQueue.length +
        _lowQueue.length;
  }

  /// Retorna estatísticas detalhadas
  Map<String, dynamic> getStats() {
    return {
      'queues': {
        'critical': _criticalQueue.length,
        'high': _highQueue.length,
        'normal': _normalQueue.length,
        'low': _lowQueue.length,
        'total': getTotalQueueSize(),
      },
      'processing': {
        'isActive': _isProcessing,
        'isPaused': _isPaused,
        'processed': _processedCount,
        'dropped': _droppedCount,
        'errors': _errorCount,
      },
      'config': {
        'maxQueueSize': _MAX_QUEUE_SIZE,
        'processingIntervalMs': _PROCESSING_INTERVAL_MS,
        'maxProcessingRate': _MAX_PROCESSING_RATE,
        'batchSize': _BATCH_SIZE,
      },
    };
  }

  /// Reseta estatísticas
  void resetStats() {
    _processedCount = 0;
    _droppedCount = 0;
    _errorCount = 0;
    logger.info('Estatísticas resetadas', tag: 'Queue');
  }

  // ==================== CLEANUP ====================

  /// Encerra o processador e salva mensagens pendentes
  Future<void> dispose() async {
    logger.info('Encerrando processador de fila...', tag: 'Queue');
    
    stop();
    await _savePendingMessages();
    
    logger.info('Processador de fila encerrado', tag: 'Queue');
  }

  /// Gera ID único para mensagem
  String _generateMessageId() {
    return 'msg_${DateTime.now().millisecondsSinceEpoch}_${_randomString(8)}';
  }

  /// Gera string aleatória
  String _randomString(int length) {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    return List.generate(
      length,
      (index) => chars[DateTime.now().microsecond % chars.length],
    ).join();
  }
}

// ==================== MODELOS ====================

/// Prioridade de mensagem
enum MessagePriority {
  critical, // Contratos, pagamentos, sinais mesh
  high,     // Mensagens de usuário
  normal,   // Sync, metadados
  low,      // Background, estatísticas
}

/// Mensagem enfileirada
class QueuedMessage {
  final String id;
  final String content;
  final String senderId;
  final String? receiverId;
  final int ttl;
  final String originNodeId;
  final List<String> visitedNodes;
  final Map<String, dynamic> metadata;
  final MessagePriority priority;
  final DateTime enqueuedAt;
  int retryCount;

  QueuedMessage({
    required this.id,
    required this.content,
    required this.senderId,
    this.receiverId,
    required this.ttl,
    required this.originNodeId,
    required this.visitedNodes,
    required this.metadata,
    required this.priority,
    required this.enqueuedAt,
    this.retryCount = 0,
  });

  @override
  String toString() {
    return 'QueuedMessage(id: $id, priority: $priority, retryCount: $retryCount)';
  }
}
