import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import '../utils/logger_service.dart';
import '../mesh/nearby_relay_service.dart';
import '../identity/device_identity_service.dart';

/// Serviço de Background para Malha Mesh
/// 
/// Garante que o Speew continue operando com o celular no bolso.
/// Implementa WakeLock para impedir a CPU de dormir e
/// Foreground Service (Android) para manter o processo ativo.
/// 
/// CARACTERÍSTICAS ALPHA-1 SDA-STRICT:
/// - WakeLock: Impede a CPU de entrar em deep sleep
/// - Foreground Service: Notificação persistente "Monitoramento de Malha"
/// - Relay contínuo de mensagens mesmo em background
/// - Otimização de bateria com modo low-power
class MeshBackgroundService {
  static final MeshBackgroundService _instance = MeshBackgroundService._internal();
  factory MeshBackgroundService() => _instance;
  MeshBackgroundService._internal();

  final DeviceIdentityService _identity = DeviceIdentityService();
  final NearbyRelayService _relay = NearbyRelayService();
  
  bool _isRunning = false;
  bool _wakeLockEnabled = false;
  Timer? _heartbeatTimer;

  /// Inicializa o serviço de background
  Future<void> initialize() async {
    try {
      // Inicializar Foreground Task
      await _initializeForegroundTask();
      
      logger.info('MeshBackgroundService inicializado', tag: 'Background');
    } catch (e) {
      logger.error('Falha ao inicializar MeshBackgroundService', tag: 'Background', error: e);
      throw Exception('Inicialização do background falhou: $e');
    }
  }

  /// Inicializa o Foreground Task
  Future<void> _initializeForegroundTask() async {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'speew_mesh_channel',
        channelName: 'Speew Mesh Network',
        channelDescription: 'Mantém a malha mesh ativa em background',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        iconData: const NotificationIconData(
          resType: ResourceType.mipmap,
          resPrefix: ResourcePrefix.ic,
          name: 'launcher',
        ),
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound: false,
      ),
      foregroundTaskOptions: const ForegroundTaskOptions(
        interval: 5000, // 5 segundos
        isOnceEvent: false,
        autoRunOnBoot: true,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
  }

  /// Inicia o serviço de background
  Future<void> start() async {
    if (_isRunning) {
      logger.warn('Serviço de background já está rodando', tag: 'Background');
      return;
    }

    try {
      // 1. ATIVAR WAKELOCK (impede CPU de dormir)
      await _enableWakeLock();

      // 2. INICIAR FOREGROUND SERVICE (notificação persistente)
      await _startForegroundService();

      // 3. Iniciar heartbeat para manter conexão ativa
      _startHeartbeat();

      _isRunning = true;
      logger.info('Serviço de background iniciado com WakeLock e Foreground Service', tag: 'Background');
    } catch (e) {
      logger.error('Erro ao iniciar serviço de background', tag: 'Background', error: e);
      throw Exception('Falha ao iniciar background: $e');
    }
  }

  /// Para o serviço de background
  Future<void> stop() async {
    if (!_isRunning) return;

    try {
      // 1. Parar heartbeat
      _stopHeartbeat();

      // 2. PARAR FOREGROUND SERVICE
      await _stopForegroundService();

      // 3. DESATIVAR WAKELOCK
      await _disableWakeLock();

      _isRunning = false;
      logger.info('Serviço de background parado', tag: 'Background');
    } catch (e) {
      logger.error('Erro ao parar serviço de background', tag: 'Background', error: e);
    }
  }

  /// Ativa o WakeLock (impede CPU de dormir)
  Future<void> _enableWakeLock() async {
    try {
      await WakelockPlus.enable();
      _wakeLockEnabled = true;
      logger.info('WakeLock ativado: CPU não entrará em deep sleep', tag: 'Background');
    } catch (e) {
      logger.error('Erro ao ativar WakeLock', tag: 'Background', error: e);
      throw Exception('Falha ao ativar WakeLock: $e');
    }
  }

  /// Desativa o WakeLock
  Future<void> _disableWakeLock() async {
    try {
      await WakelockPlus.disable();
      _wakeLockEnabled = false;
      logger.info('WakeLock desativado', tag: 'Background');
    } catch (e) {
      logger.error('Erro ao desativar WakeLock', tag: 'Background', error: e);
    }
  }

  /// Inicia o Foreground Service (notificação persistente)
  Future<void> _startForegroundService() async {
    try {
      // Verificar se já está rodando
      if (await FlutterForegroundTask.isRunningService) {
        logger.warn('Foreground Service já está rodando', tag: 'Background');
        return;
      }

      // Iniciar Foreground Service
      final serviceStarted = await FlutterForegroundTask.startService(
        notificationTitle: 'Speew Mesh Ativo',
        notificationText: 'Monitoramento de Malha em execução',
        callback: _foregroundTaskCallback,
      );

      if (serviceStarted) {
        logger.info('Foreground Service iniciado: Notificação "Monitoramento de Malha" ativa', tag: 'Background');
      } else {
        throw Exception('Falha ao iniciar Foreground Service');
      }
    } catch (e) {
      logger.error('Erro ao iniciar Foreground Service', tag: 'Background', error: e);
      throw Exception('Falha ao iniciar Foreground Service: $e');
    }
  }

  /// Para o Foreground Service
  Future<void> _stopForegroundService() async {
    try {
      await FlutterForegroundTask.stopService();
      logger.info('Foreground Service parado', tag: 'Background');
    } catch (e) {
      logger.error('Erro ao parar Foreground Service', tag: 'Background', error: e);
    }
  }

  /// Callback do Foreground Task (executado periodicamente)
  @pragma('vm:entry-point')
  static void _foregroundTaskCallback() {
    // Este callback é executado em background
    // Aqui você pode fazer operações periódicas
    
    // Atualizar notificação com estatísticas
    FlutterForegroundTask.updateService(
      notificationTitle: 'Speew Mesh Ativo',
      notificationText: 'Monitoramento de Malha: ${DateTime.now().hour}:${DateTime.now().minute}',
    );
    
    // Enviar dados para a UI (opcional)
    FlutterForegroundTask.sendDataToMain({
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'status': 'running',
    });
  }

  /// Inicia heartbeat para manter conexão ativa
  void _startHeartbeat() {
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (_isRunning) {
        _sendHeartbeat();
      }
    });
    logger.info('Heartbeat iniciado (30s)', tag: 'Background');
  }

  /// Para o heartbeat
  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    logger.info('Heartbeat parado', tag: 'Background');
  }

  /// Envia heartbeat para manter conexão ativa
  void _sendHeartbeat() {
    try {
      // Enviar mensagem de heartbeat para a malha
      _relay.sendToMesh(
        'heartbeat',
        metadata: {
          'type': 'heartbeat',
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'nodeId': _identity.peerId,
        },
      );
      
      if (kDebugMode) {
        print('Heartbeat enviado: ${DateTime.now()}');
      }
    } catch (e) {
      logger.error('Erro ao enviar heartbeat', tag: 'Background', error: e);
    }
  }

  /// Verifica se o WakeLock está ativo
  Future<bool> isWakeLockEnabled() async {
    try {
      return await WakelockPlus.enabled;
    } catch (e) {
      logger.error('Erro ao verificar WakeLock', tag: 'Background', error: e);
      return false;
    }
  }

  /// Verifica se o Foreground Service está rodando
  Future<bool> isForegroundServiceRunning() async {
    try {
      return await FlutterForegroundTask.isRunningService;
    } catch (e) {
      logger.error('Erro ao verificar Foreground Service', tag: 'Background', error: e);
      return false;
    }
  }

  /// Retorna estatísticas do serviço
  Future<Map<String, dynamic>> getStats() async {
    return {
      'isRunning': _isRunning,
      'wakeLockEnabled': await isWakeLockEnabled(),
      'foregroundServiceRunning': await isForegroundServiceRunning(),
      'relayStats': _relay.getStats(),
    };
  }

  /// Getter para verificar se está rodando
  bool get isRunning => _isRunning;
}
