// ==================== STUBS E MOCKS PARA COMPILAÇÃO ====================
import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';

// '../../models/message.dart'
class Message {
  final String id;
  final String content;
  Message({required this.id, required this.content});
}

// '../reputation/reputation_models.dart'
class ReputationScore {
  final double score;
  ReputationScore({required this.score});
}

// '../reputation/reputation_core.dart'
class ReputationCore {
  final Map<String, ReputationScore> _scores = {
    'peer-reliable': ReputationScore(score: 0.90), // Ganha 1.2x Multiplicador
    'peer-average': ReputationScore(score: 0.50),
    'peer-low': ReputationScore(score: 0.20),
  };

  ReputationScore? getReputationScore(String peerId) {
    return _scores[peerId];
  }
}

// ==================== PriorityQueueService ====================

/// Nível de prioridade para propagação no mesh
enum MessagePriority {
  critical, // Transações simbólicas, atualizações de reputação, chaves públicas
  high,     // Identidades rotacionadas, estados sociais
  medium,   // Mensagens recentes, blocos de arquivos pequenos
  low,      // Arquivos gigantes, dados auxiliares
}

/// Item na fila de prioridade
class PriorityQueueItem {
  final String itemId;
  final MessagePriority priority;
  final DateTime timestamp;
  final int retryCount;
  final Map<String, dynamic> data;
  final String? destinationId;
  final String? sourcePeerId; // Nó de origem do pacote

  PriorityQueueItem({
    required this.itemId,
    required this.priority,
    required this.timestamp,
    this.retryCount = 0,
    required this.data,
    this.destinationId,
    this.sourcePeerId,
  });

  /// Calcula score de prioridade (maior = mais prioritário)
  double priorityScore(ReputationCore reputationCore) {
    // 1. Base score por prioridade
    double baseScore = switch (priority) {
      MessagePriority.critical => 1000.0,
      MessagePriority.high => 500.0,
      MessagePriority.medium => 100.0,
      MessagePriority.low => 10.0,
    };
    
    // 2. Penalidade por idade (prioriza a justiça/fairness)
    final ageInSeconds = DateTime.now().difference(timestamp).inSeconds;
    final agePenalty = ageInSeconds * 0.01;
    
    // 3. Penalidade por tentativas de reenvio
    final retryPenalty = retryCount * 10.0;

    // 4. Multiplicador de Prioridade por Reputação (Segurança/Confiabilidade)
    double reputationMultiplier = 1.0;
    if (sourcePeerId != null) {
      final rs = reputationCore.getReputationScore(sourcePeerId!)?.score ?? 0.5;
      // Nós de alta reputação (RS >= 70%) ganham um multiplicador
      if (rs >= 0.7) {
        reputationMultiplier = 1.2;
      }
    }
    
    // Score final: (Base - Penalidades) * Multiplicador
    return (baseScore - agePenalty - retryPenalty).clamp(0, double.infinity) * reputationMultiplier;
  }

  PriorityQueueItem copyWith({
    String? itemId,
    MessagePriority? priority,
    DateTime? timestamp,
    int? retryCount,
    Map<String, dynamic>? data,
    String? destinationId,
    String? sourcePeerId,
  }) {
    return PriorityQueueItem(
      itemId: itemId ?? this.itemId,
      priority: priority ?? this.priority,
      timestamp: timestamp ?? this.timestamp,
      retryCount: retryCount ?? this.retryCount,
      data: data ?? this.data,
      destinationId: destinationId ?? this.destinationId,
      sourcePeerId: sourcePeerId ?? this.sourcePeerId,
    );
  }
}

/// Serviço de Fila de Prioridade para Propagação Inteligente no Mesh
class PriorityQueueService {
  static final PriorityQueueService _instance = PriorityQueueService._internal();
  factory PriorityQueueService() => _instance;
  PriorityQueueService._internal();

  final ReputationCore _reputationCore = ReputationCore();

  /// Fila principal (ordenada por prioridade)
  final List<PriorityQueueItem> _queue = [];
  
  /// Itens em processamento
  final Set<String> _processingItems = {};
  
  /// Histórico de itens processados (últimos 1000)
  final Queue<String> _processedHistory = Queue<String>();
  static const int _maxHistorySize = 1000;
  
  /// Estatísticas de processamento
  final Map<MessagePriority, int> _processedCounts = {
    MessagePriority.critical: 0,
    MessagePriority.high: 0,
    MessagePriority.medium: 0,
    MessagePriority.low: 0,
  };

  // ==================== ADIÇÃO À FILA ====================

  /// Adiciona item à fila com prioridade
  void enqueue(PriorityQueueItem item) {
    if (_isInQueue(item.itemId) || _wasRecentlyProcessed(item.itemId)) {
      return;
    }
    
    _queue.add(item);
    _sortQueue(); // Reordena a cada adição
  }
  
  // Métodos de conveniência para enfileiramento (simplificados)
  void enqueueTransaction({
    required String transactionId,
    required Map<String, dynamic> transactionData,
    String? destinationId,
  }) {
    enqueue(PriorityQueueItem(
      itemId: transactionId,
      priority: MessagePriority.critical,
      timestamp: DateTime.now(),
      data: transactionData,
      destinationId: destinationId,
    ));
  }
  
  void enqueueIdentityRotation({
    required String rotationId,
    required Map<String, dynamic> rotationData,
  }) {
    enqueue(PriorityQueueItem(
      itemId: rotationId,
      priority: MessagePriority.high,
      timestamp: DateTime.now(),
      data: rotationData,
    ));
  }
  
  void enqueueFileBlock({
    required String blockId,
    required Map<String, dynamic> blockData,
    required int blockSize,
    String? destinationId,
  }) {
    final priority = blockSize < 131072 ? MessagePriority.medium : MessagePriority.low;
    
    enqueue(PriorityQueueItem(
      itemId: blockId,
      priority: priority,
      timestamp: DateTime.now(),
      data: blockData,
      destinationId: destinationId,
    ));
  }

  // ==================== REMOÇÃO DA FILA ====================

  /// Remove e retorna o item de maior prioridade
  PriorityQueueItem? dequeue() {
    if (_queue.isEmpty) return null;
    
    _sortQueue(); // Garante que o item de maior score está no topo
    final item = _queue.removeAt(0);
    
    _processingItems.add(item.itemId);
    return item;
  }

  /// Remove itens de baixa prioridade se a fila estiver cheia (Anti-Congestionamento)
  void trimLowPriorityItems({int maxQueueSize = 1000}) {
    if (_queue.length <= maxQueueSize) return;
    
    _sortQueue();
    
    // Remove os itens de menor prioridade
    final itemsToRemove = _queue.length - maxQueueSize;
    _queue.removeRange(_queue.length - itemsToRemove, _queue.length);
  }

  // ==================== GERENCIAMENTO DE PROCESSAMENTO ====================

  /// Marca item como processado com sucesso
  void markAsProcessed(String itemId, MessagePriority priority) {
    _processingItems.remove(itemId);
    
    _processedHistory.addLast(itemId);
    if (_processedHistory.length > _maxHistorySize) {
      _processedHistory.removeFirst();
    }
    
    _processedCounts[priority] = (_processedCounts[priority] ?? 0) + 1;
  }

  /// Marca item como falho e reenfileira com retry
  void markAsFailed(PriorityQueueItem item, {int maxRetries = 3}) {
    _processingItems.remove(item.itemId);
    
    if (item.retryCount < maxRetries) {
      // Reenfileirar com contador de retry incrementado e novo timestamp
      final retriedItem = item.copyWith(
        retryCount: item.retryCount + 1,
        timestamp: DateTime.now(),
      );
      enqueue(retriedItem);
    }
  }

  // ==================== FUNÇÕES AUXILIARES ====================

  /// Ordena a fila por score de prioridade (decrescente)
  void _sortQueue() {
    _queue.sort((a, b) => b.priorityScore(_reputationCore).compareTo(a.priorityScore(_reputationCore)));
  }

  /// Verifica se item foi processado recentemente (para evitar loops ou re-processamento desnecessário)
  bool _wasRecentlyProcessed(String itemId) {
    return _processedHistory.contains(itemId);
  }

  /// Limpa a fila (para testes)
  void clear() {
    _queue.clear();
    _processingItems.clear();
    _processedHistory.clear();
    _processedCounts.clear();
  }
}
