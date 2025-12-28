// ==================== STUB DE DEPENDÊNCIA ====================
import 'package:flutter/foundation.dart';
// '../utils/logger_service.dart'
class LoggerService {
  void info(String message, {String? tag, dynamic error}) => print('[INFO][${tag ?? 'App'}] $message ${error ?? ''}');
  void warn(String message, {String? tag, dynamic error}) => print('[WARN][${tag ?? 'App'}] $message ${error ?? ''}');
  void error(String message, {String? tag, dynamic error}) => print('[ERROR][${tag ?? 'App'}] $message ${error ?? ''}');
  void debug(String message, {String? tag, dynamic error}) {
    if (kDebugMode) print('[DEBUG][${tag ?? 'App'}] $message ${error ?? ''}');
  }
}
final logger = LoggerService();

// ==================== MeshTimeSyncService ====================

import 'dart:async';
import 'dart:math';

/// Serviço de Sincronização de Tempo da Mesh (Relógio Lógico de Lamport).
/// Garante um timestamp confiável e ordenado para o ledger e a economia.
class MeshTimeSyncService {
  int _lamportClock = 0;
  final Random _random = Random();
  late Timer _driftTimer;

  MeshTimeSyncService() {
    // Simula um pequeno "drift" para forçar a sincronização e garantir a progressão do tempo
    _driftTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      _lamportClock += _random.nextInt(5); // Drift aleatório
    });
  }

  /// Retorna o timestamp lógico atual.
  int get currentLogicalTime => _lamportClock;

  /// Atualiza o relógio lógico com base em um evento interno.
  /// Garante que o relógio local avance monotonicamente.
  int tick() {
    _lamportClock++;
    return _lamportClock;
  }

  /// Atualiza o relógio lógico com base em um timestamp recebido de outro peer.
  /// Regra do Lamport Clock: $C_a = \max(C_a, C_b) + 1$
  int syncWithPeerTime(int peerTime) {
    final oldTime = _lamportClock;
    _lamportClock = max(_lamportClock, peerTime) + 1;
    logger.debug('Relógio Lamport sincronizado. Tempo Antigo: $oldTime, Peer Time: $peerTime, Novo tempo: $_lamportClock', tag: 'TimeSync');
    return _lamportClock;
  }

  /// Retorna um timestamp confiável para uso em transações.
  /// Usa o tick para garantir que o tempo sempre avance, prevenindo transações com o mesmo Lamport Time.
  int getReliableTimestamp() {
    return tick(); 
  }

  void dispose() {
    _driftTimer.cancel();
  }
}
