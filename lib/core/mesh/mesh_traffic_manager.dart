import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import '../utils/logger_service.dart';
import '../p2p/p2p_service.dart';
import '../models/message.dart';

enum PacketPriority { critical, normal, bulk }

class MeshTrafficManager {
  static final MeshTrafficManager _instance = MeshTrafficManager._internal();
  factory MeshTrafficManager() => _instance;
  MeshTrafficManager._internal();

  final _queue = DoubleLinkedQueue<_QueuedPacket>();
  bool _isProcessing = false;
  
  // Limites para evitar estouro de memória
  static const int _maxQueueSize = 5000;

  void handlePacket(P2PMessage message, String receiverId, PacketPriority priority) {
    if (_queue.length >= _maxQueueSize) {
      logger.warn('Fila de tráfego cheia! Descartando pacote bulk.', tag: 'TrafficManager');
      if (priority == PacketPriority.bulk) return;
      // Se for crítico ou normal, removemos o mais antigo da fila bulk para dar lugar
      _removeOldestBulk();
    }

    final packet = _QueuedPacket(
      message: message,
      receiverId: receiverId,
      priority: priority,
      timestamp: DateTime.now(),
    );

    if (priority == PacketPriority.critical) {
      // Processa imediatamente ou coloca no início da fila
      logger.debug('Pacote CRÍTICO recebido. Furando fila.', tag: 'TrafficManager');
      _executeNow(packet);
    } else {
      _enqueueByPriority(packet);
      _processNext();
    }
  }

  void _enqueueByPriority(_QueuedPacket packet) {
    // Inserção simples baseada em prioridade
    // Pacotes normais entram antes dos bulk
    if (packet.priority == PacketPriority.normal) {
      // Encontra o primeiro pacote bulk e insere antes dele
      bool inserted = false;
      final list = _queue.toList();
      _queue.clear();
      
      for (var p in list) {
        if (!inserted && p.priority == PacketPriority.bulk) {
          _queue.addLast(packet);
          inserted = true;
        }
        _queue.addLast(p);
      }
      if (!inserted) _queue.addLast(packet);
    } else {
      _queue.addLast(packet);
    }
  }

  void _removeOldestBulk() {
    try {
      final oldestBulk = _queue.firstWhere((p) => p.priority == PacketPriority.bulk);
      _queue.remove(oldestBulk);
    } catch (_) {
      if (_queue.isNotEmpty) _queue.removeFirst();
    }
  }

  Future<void> _executeNow(_QueuedPacket packet) async {
    try {
      await P2PService().sendDataRaw(
        packet.receiverId,
        packet.message,
        priority: packet.priority,
      );
    } catch (e) {
      logger.error('Erro ao processar pacote crítico', tag: 'TrafficManager', error: e);
    }
  }

  Future<void> _processNext() async {
    if (_isProcessing || _queue.isEmpty) return;

    _isProcessing = true;
    
    while (_queue.isNotEmpty) {
      final packet = _queue.removeFirst();
      
      try {
        final success = await P2PService().sendDataRaw(
          packet.receiverId,
          packet.message,
          priority: packet.priority,
        );
        
        if (!success && packet.priority != PacketPriority.bulk) {
          // Re-enfileira se falhar e não for bulk (com limite de tentativas?)
          logger.warn('Falha no envio, re-enfileirando...', tag: 'TrafficManager');
        }
      } catch (e) {
        logger.error('Erro no processamento da fila', tag: 'TrafficManager', error: e);
      }
      
      // Pequeno delay para não engasgar a CPU em loops intensos
      await Future.delayed(const Duration(milliseconds: 10));
    }

    _isProcessing = false;
  }
}

class _QueuedPacket {
  final P2PMessage message;
  final String receiverId;
  final PacketPriority priority;
  final DateTime timestamp;

  _QueuedPacket({
    required this.message,
    required this.receiverId,
    required this.priority,
    required this.timestamp,
  });
}
