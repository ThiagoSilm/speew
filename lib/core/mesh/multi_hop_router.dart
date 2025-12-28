import 'dart:convert';
import '../utils/logger_service.dart';
import '../p2p/p2p_service.dart';

/// Roteador Multi-hop para mensagens mesh
/// Implementa roteamento com TTL (Time To Live) de 3 saltos
/// 
/// CARACTERÍSTICAS:
/// - TTL padrão de 3 saltos conforme especificação ALPHA-1
/// - Prevenção de loops através de lista de nós visitados
/// - Relay automático para todos os peers conectados
/// - Descarte de mensagens expiradas ou duplicadas
class MultiHopRouter {
  static final MultiHopRouter _instance = MultiHopRouter._internal();
  factory MultiHopRouter() => _instance;
  MultiHopRouter._internal();

  // TTL padrão conforme especificação ALPHA-1
  static const int DEFAULT_TTL = 3;

  // Cache de mensagens já processadas (para evitar duplicatas)
  final Set<String> _processedMessages = {};
  
  // Limite do cache (para evitar crescimento infinito)
  static const int MAX_CACHE_SIZE = 1000;

  // ID do nó local
  String? _localNodeId;

  // Referência ao serviço P2P
  P2PService? _p2pService;

  // ==================== INICIALIZAÇÃO ====================

  /// Inicializa o roteador com o ID do nó local e referência ao P2P
  void initialize(String localNodeId, P2PService p2pService) {
    _localNodeId = localNodeId;
    _p2pService = p2pService;
    logger.info('Roteador multi-hop inicializado: $localNodeId', tag: 'MultiHop');
  }

  // ==================== ENVIO DE MENSAGENS ====================

  /// Envia uma mensagem para a malha com TTL inicial
  Future<void> sendMessage(
    String content, {
    String? targetPeerId,
    int ttl = DEFAULT_TTL,
    Map<String, dynamic>? metadata,
  }) async {
    if (_localNodeId == null || _p2pService == null) {
      throw Exception('Roteador não inicializado');
    }

    final message = MeshMessage(
      id: _generateMessageId(),
      content: content,
      ttl: ttl,
      originNodeId: _localNodeId!,
      visitedNodes: [_localNodeId!],
      targetPeerId: targetPeerId,
      metadata: metadata ?? {},
      timestamp: DateTime.now(),
    );

    await _relayMessage(message, null);
  }

  // ==================== RECEBIMENTO E RELAY ====================

  /// Processa uma mensagem recebida e decide se deve fazer relay
  Future<void> receiveMessage(
    String messageJson,
    String fromPeerId,
  ) async {
    try {
      final message = MeshMessage.fromJson(jsonDecode(messageJson));

      // Verificar se já processamos esta mensagem
      if (_processedMessages.contains(message.id)) {
        logger.debug('Mensagem duplicada descartada: ${message.id}', tag: 'MultiHop');
        return;
      }

      // Adicionar ao cache de mensagens processadas
      _addToProcessedCache(message.id);

      // Verificar TTL
      if (message.ttl <= 0) {
        logger.info('Mensagem descartada: TTL expirado (${message.id})', tag: 'MultiHop');
        return;
      }

      // Verificar se já visitamos este nó (evitar loops)
      if (_localNodeId != null && message.visitedNodes.contains(_localNodeId)) {
        logger.info('Mensagem descartada: loop detectado (${message.id})', tag: 'MultiHop');
        return;
      }

      // Verificar se a mensagem é para este nó
      if (message.targetPeerId == null || message.targetPeerId == _localNodeId) {
        logger.info('Mensagem recebida: ${message.id}', tag: 'MultiHop');
        _deliverMessage(message);
      }

      // Fazer relay se ainda houver TTL
      if (message.ttl > 0) {
        await _relayMessage(message, fromPeerId);
      }
    } catch (e) {
      logger.error('Erro ao processar mensagem recebida', tag: 'MultiHop', error: e);
    }
  }

  /// Faz relay de uma mensagem para todos os peers (exceto o remetente)
  Future<void> _relayMessage(
    MeshMessage message,
    String? excludePeerId,
  ) async {
    if (_p2pService == null || _localNodeId == null) return;

    // Decrementar TTL e adicionar este nó à lista de visitados
    final relayedMessage = MeshMessage(
      id: message.id,
      content: message.content,
      ttl: message.ttl - 1,
      originNodeId: message.originNodeId,
      visitedNodes: [...message.visitedNodes, _localNodeId!],
      targetPeerId: message.targetPeerId,
      metadata: message.metadata,
      timestamp: message.timestamp,
    );

    // Obter lista de peers conectados
    final connectedPeers = _p2pService!.connectedPeers;

    // Enviar para todos os peers (exceto o remetente)
    int relayCount = 0;
    for (final peer in connectedPeers) {
      if (peer.peerId != excludePeerId) {
        try {
          await _p2pService!.sendMessage(
            peer.peerId,
            relayedMessage.toJsonString(),
          );
          relayCount++;
        } catch (e) {
          logger.error(
            'Erro ao fazer relay para peer ${peer.peerId}',
            tag: 'MultiHop',
            error: e,
          );
        }
      }
    }

    logger.info(
      'Mensagem ${message.id} retransmitida para $relayCount peers (TTL: ${relayedMessage.ttl})',
      tag: 'MultiHop',
    );
  }

  /// Entrega a mensagem ao aplicativo local
  void _deliverMessage(MeshMessage message) {
    // Aqui você pode emitir um evento ou chamar um callback
    // Por exemplo, adicionar ao stream de mensagens do P2PService
    logger.info(
      'Mensagem entregue: ${message.id} (origem: ${message.originNodeId})',
      tag: 'MultiHop',
    );
  }

  // ==================== CACHE DE MENSAGENS PROCESSADAS ====================

  /// Adiciona uma mensagem ao cache de processadas
  void _addToProcessedCache(String messageId) {
    _processedMessages.add(messageId);

    // Limpar cache se exceder o limite
    if (_processedMessages.length > MAX_CACHE_SIZE) {
      final toRemove = _processedMessages.length - MAX_CACHE_SIZE;
      _processedMessages.removeAll(_processedMessages.take(toRemove));
    }
  }

  // ==================== UTILITÁRIOS ====================

  /// Gera um ID único para mensagem
  String _generateMessageId() {
    return '${_localNodeId}_${DateTime.now().millisecondsSinceEpoch}_${_randomString(8)}';
  }

  /// Gera uma string aleatória
  String _randomString(int length) {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    return List.generate(length, (index) => chars[DateTime.now().microsecond % chars.length]).join();
  }

  /// Limpa o cache de mensagens processadas
  void clearCache() {
    _processedMessages.clear();
    logger.info('Cache de mensagens limpo', tag: 'MultiHop');
  }

  /// Retorna estatísticas do roteador
  Map<String, dynamic> getStats() {
    return {
      'processedMessagesCount': _processedMessages.length,
      'localNodeId': _localNodeId,
      'isInitialized': _localNodeId != null && _p2pService != null,
    };
  }
}

// ==================== MODELO DE MENSAGEM MESH ====================

/// Modelo de mensagem para roteamento mesh
class MeshMessage {
  final String id;
  final String content;
  final int ttl;
  final String originNodeId;
  final List<String> visitedNodes;
  final String? targetPeerId;
  final Map<String, dynamic> metadata;
  final DateTime timestamp;

  MeshMessage({
    required this.id,
    required this.content,
    required this.ttl,
    required this.originNodeId,
    required this.visitedNodes,
    this.targetPeerId,
    required this.metadata,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'ttl': ttl,
      'originNodeId': originNodeId,
      'visitedNodes': visitedNodes,
      'targetPeerId': targetPeerId,
      'metadata': metadata,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory MeshMessage.fromJson(Map<String, dynamic> json) {
    return MeshMessage(
      id: json['id'] as String,
      content: json['content'] as String,
      ttl: json['ttl'] as int,
      originNodeId: json['originNodeId'] as String,
      visitedNodes: List<String>.from(json['visitedNodes'] as List),
      targetPeerId: json['targetPeerId'] as String?,
      metadata: Map<String, dynamic>.from(json['metadata'] as Map),
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }

  String toJsonString() => jsonEncode(toJson());

  factory MeshMessage.fromJsonString(String jsonString) {
    return MeshMessage.fromJson(jsonDecode(jsonString));
  }

  @override
  String toString() {
    return 'MeshMessage(id: $id, ttl: $ttl, origin: $originNodeId, hops: ${visitedNodes.length})';
  }
}
