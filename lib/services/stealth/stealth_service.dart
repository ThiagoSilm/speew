import '../../core/utils/logger_service.dart';
import '../crypto/crypto_service.dart';
import '../storage/database_service.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';

/// ==================== NOVO MÓDULO: MODO FANTASMA ====================
/// Serviço de modo stealth para operação anônima na rede P2P
/// 
/// Funcionalidades:
/// - Ofuscação do nome do dispositivo
/// - Rotação automática de identificadores
/// - Beacons silenciosos (descoberta sem broadcasting forte)
/// - Timer de autodestruição para mensagens (wipe seguro)
///
/// ADICIONADO: Fase 2 - Expansão do projeto
class StealthService extends ChangeNotifier {
  static final StealthService _instance = StealthService._internal();
  factory StealthService() => _instance;
  StealthService._internal();

  final CryptoService _crypto = CryptoService();
  final DatabaseService _db = DatabaseService();
  final Random _random = Random.secure();

  /// Estado do modo fantasma
  bool _isStealthMode = false;
  bool get isStealthMode => _isStealthMode;

  /// Identificador atual ofuscado
  String _currentObfuscatedId = '';
  String get currentObfuscatedId => _currentObfuscatedId;

  /// Timer para rotação automática de identificadores
  Timer? _rotationTimer;

  /// Intervalo de rotação (padrão: 5 minutos)
  Duration _rotationInterval = const Duration(minutes: 5);

  /// Timers de autodestruição de mensagens
  final Map<String, Timer> _destructionTimers = {};

  // ==================== ATIVAÇÃO/DESATIVAÇÃO ====================

  /// Ativa o modo fantasma
  Future<void> enableStealthMode({Duration? rotationInterval}) async {
    try {
      _isStealthMode = true;
      
      if (rotationInterval != null) {
        _rotationInterval = rotationInterval;
      }

      // Gera primeiro identificador ofuscado
      await _rotateIdentifier();

      // Inicia rotação automática
      _startAutoRotation();

      notifyListeners();
      logger.info('Modo fantasma ativado', tag: 'Stealth');
    } catch (e) {
      logger.info('Erro ao ativar modo fantasma: $e', tag: 'Stealth');
      rethrow;
    }
  }

  /// Desativa o modo fantasma
  Future<void> disableStealthMode() async {
    try {
      _isStealthMode = false;
      _stopAutoRotation();
      _currentObfuscatedId = '';
      
      notifyListeners();
      logger.info('Modo fantasma desativado', tag: 'Stealth');
    } catch (e) {
      logger.info('Erro ao desativar modo fantasma: $e', tag: 'Stealth');
    }
  }

  // ==================== OFUSCAÇÃO DE IDENTIFICADORES ====================

  /// Gera um identificador ofuscado aleatório
  String _generateObfuscatedId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final randomBytes = List.generate(16, (_) => _random.nextInt(256));
    final combined = '$timestamp${base64Encode(randomBytes)}';
    return _crypto.sha256Hash(combined).substring(0, 16);
  }

  /// Rotaciona o identificador atual
  Future<void> _rotateIdentifier() async {
    try {
      final newId = _generateObfuscatedId();
      _currentObfuscatedId = newId;
      
      logger.info('Identificador rotacionado: $newId', tag: 'Stealth');
      notifyListeners();
    } catch (e) {
      logger.info('Erro ao rotacionar identificador: $e', tag: 'Stealth');
    }
  }

  /// Inicia rotação automática de identificadores
  void _startAutoRotation() {
    _stopAutoRotation();
    
    _rotationTimer = Timer.periodic(_rotationInterval, (_) async {
      if (_isStealthMode) {
        await _rotateIdentifier();
      }
    });
    
    logger.info('Rotação automática iniciada (intervalo: $_rotationInterval)', tag: 'Stealth');
  }

  /// Para rotação automática
  void _stopAutoRotation() {
    _rotationTimer?.cancel();
    _rotationTimer = null;
  }

  /// Configura intervalo de rotação
  void setRotationInterval(Duration interval) {
    _rotationInterval = interval;
    
    if (_isStealthMode) {
      _startAutoRotation();
    }
    
    logger.info('Intervalo de rotação atualizado: $interval', tag: 'Stealth');
  }

  // ==================== BEACONS SILENCIOSOS ====================

  /// Gera um beacon silencioso para descoberta passiva
  /// Beacon com potência reduzida e identificador ofuscado
  Map<String, dynamic> generateSilentBeacon() {
    if (!_isStealthMode) {
      throw Exception('Modo fantasma não está ativado');
    }

    return {
      'type': 'silent_beacon',
      'id': _currentObfuscatedId,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'ttl': 60, // Time-to-live em segundos
      'power': 'low', // Potência reduzida
    };
  }

  /// Valida um beacon silencioso recebido
  bool validateSilentBeacon(Map<String, dynamic> beacon) {
    try {
      if (beacon['type'] != 'silent_beacon') return false;
      
      final timestamp = beacon['timestamp'] as int;
      final ttl = beacon['ttl'] as int;
      final now = DateTime.now().millisecondsSinceEpoch;
      
      // Verifica se o beacon ainda é válido
      return (now - timestamp) < (ttl * 1000);
    } catch (e) {
      logger.info('Erro ao validar beacon: $e', tag: 'Stealth');
      return false;
    }
  }

  // ==================== AUTODESTRUIÇÃO DE MENSAGENS ====================

  /// Agenda autodestruição de uma mensagem
  void scheduleMessageDestruction(String messageId, Duration delay) {
    // Cancela timer anterior se existir
    _destructionTimers[messageId]?.cancel();

    // Cria novo timer
    _destructionTimers[messageId] = Timer(delay, () async {
      await _destroyMessage(messageId);
    });

    logger.info('Autodestruição agendada para mensagem $messageId em $delay', tag: 'Stealth');
  }

  /// Destrói uma mensagem de forma segura
  Future<void> _destroyMessage(String messageId) async {
    try {
      // Obtém a mensagem do banco
      final message = await _db.getMessage(messageId);
      
      if (message == null) {
        logger.info('Mensagem $messageId não encontrada', tag: 'Stealth');
        return;
      }

      // Sobrescreve os dados da mensagem com dados aleatórios (wipe seguro)
      final randomData = List.generate(1024, (_) => _random.nextInt(256));
      await _db.updateMessageContent(messageId, base64Encode(randomData));

      // Aguarda um ciclo para garantir escrita
      await Future.delayed(const Duration(milliseconds: 100));

      // Remove a mensagem do banco
      await _db.deleteMessage(messageId);

      // Remove o timer
      _destructionTimers.remove(messageId);

      logger.info('Mensagem $messageId destruída com segurança', tag: 'Stealth');
      notifyListeners();
    } catch (e) {
      logger.info('Erro ao destruir mensagem $messageId: $e', tag: 'Stealth');
    }
  }

  /// Cancela autodestruição de uma mensagem
  void cancelMessageDestruction(String messageId) {
    _destructionTimers[messageId]?.cancel();
    _destructionTimers.remove(messageId);
    logger.info('Autodestruição cancelada para mensagem $messageId', tag: 'Stealth');
  }

  /// Obtém tempo restante para autodestruição de uma mensagem
  Duration? getTimeUntilDestruction(String messageId) {
    final timer = _destructionTimers[messageId];
    if (timer == null || !timer.isActive) return null;
    
    // Não há API direta para obter tempo restante, retorna null
    return null;
  }

  /// Verifica se uma mensagem tem autodestruição agendada
  bool hasScheduledDestruction(String messageId) {
    final timer = _destructionTimers[messageId];
    return timer != null && timer.isActive;
  }

  // ==================== NOME DO DISPOSITIVO OFUSCADO ====================

  /// Gera um nome de dispositivo ofuscado
  String generateObfuscatedDeviceName() {
    final adjectives = [
      'Silent', 'Shadow', 'Ghost', 'Phantom', 'Stealth',
      'Hidden', 'Invisible', 'Dark', 'Mystic', 'Secret'
    ];
    
    final nouns = [
      'Node', 'Peer', 'Device', 'Unit', 'Agent',
      'Client', 'Host', 'Entity', 'Point', 'Station'
    ];
    
    final adjective = adjectives[_random.nextInt(adjectives.length)];
    final noun = nouns[_random.nextInt(nouns.length)];
    final number = _random.nextInt(9999);
    
    return '$adjective$noun$number';
  }

  // ==================== UTILITÁRIOS ====================

  /// Obtém estatísticas do modo fantasma
  Map<String, dynamic> getStealthStats() {
    return {
      'isActive': _isStealthMode,
      'currentId': _currentObfuscatedId,
      'rotationInterval': _rotationInterval.inMinutes,
      'scheduledDestructions': _destructionTimers.length,
      'activeTimers': _destructionTimers.values.where((t) => t.isActive).length,
    };
  }

  /// Limpa todos os timers de autodestruição
  void clearAllDestructionTimers() {
    for (final timer in _destructionTimers.values) {
      timer.cancel();
    }
    _destructionTimers.clear();
    logger.info('Todos os timers de autodestruição cancelados', tag: 'Stealth');
  }

  // ==================== CLEANUP ====================

  /// Libera recursos
  @override
  void dispose() {
    _stopAutoRotation();
    clearAllDestructionTimers();
    super.dispose();
  }
}
