import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:location/location.dart';
import '../utils/logger_service.dart';
import '../mesh/nearby_relay_service.dart';
import '../background/mesh_background_service.dart';

/// Serviço de Monitoramento de Hardware
/// 
/// Monitora mudanças de estado de Bluetooth, GPS e outros rádios.
/// Reage em TEMPO REAL quando o hardware é desligado/ligado.
/// 
/// CARACTERÍSTICAS CRÍTICAS:
/// - Listeners para Bluetooth ON/OFF
/// - Listeners para GPS ON/OFF
/// - Reação automática a mudanças de estado
/// - Reconexão automática quando hardware volta
/// - Notificação ao usuário sobre problemas de hardware
class HardwareMonitorService {
  static final HardwareMonitorService _instance = HardwareMonitorService._internal();
  factory HardwareMonitorService() => _instance;
  HardwareMonitorService._internal();

  // Streams de estado
  final StreamController<BluetoothState> _bluetoothStateController = 
      StreamController<BluetoothState>.broadcast();
  final StreamController<LocationState> _locationStateController = 
      StreamController<LocationState>.broadcast();
  final StreamController<HardwareEvent> _hardwareEventController = 
      StreamController<HardwareEvent>.broadcast();

  Stream<BluetoothState> get bluetoothStateStream => _bluetoothStateController.stream;
  Stream<LocationState> get locationStateStream => _locationStateController.stream;
  Stream<HardwareEvent> get hardwareEventStream => _hardwareEventController.stream;

  // Estado atual
  BluetoothState _currentBluetoothState = BluetoothState.unknown;
  LocationState _currentLocationState = LocationState.unknown;
  
  // Streams de Subscrição
  StreamSubscription? _bluetoothSubscription;
  StreamSubscription? _locationSubscription;
  
  // Referências a serviços
  final NearbyRelayService _relay = NearbyRelayService();
  final MeshBackgroundService _background = MeshBackgroundService();
  
  // Configurações
  static const int _RECONNECT_DELAY_SECONDS = 3;

  /// Inicializa o monitoramento de hardware
  Future<void> initialize() async {
    try {
      logger.info('Inicializando monitoramento de hardware...', tag: 'Hardware');

      // Verificar estado inicial
      await _checkBluetoothState();
      await _checkLocationState();

      // Iniciar monitoramento reativo
      _startBluetoothMonitoring();
      _startLocationMonitoring();

      logger.info('Monitoramento de hardware inicializado', tag: 'Hardware');
    } catch (e) {
      logger.error('Falha ao inicializar monitoramento de hardware', tag: 'Hardware', error: e);
      throw Exception('Inicialização do hardware monitor falhou: $e');
    }
  }

  // ==================== MONITORAMENTO DE BLUETOOTH (REATIVO) ====================

  /// Inicia monitoramento reativo de Bluetooth
  void _startBluetoothMonitoring() {
    _bluetoothSubscription?.cancel();
    
    // Subscrição ao estado real do Bluetooth
    _bluetoothSubscription = FlutterBluePlus.adapterState.listen((state) async {
      BluetoothState newState;
      
      switch (state) {
        case BluetoothAdapterState.on:
          newState = BluetoothState.on;
          break;
        case BluetoothAdapterState.off:
          newState = BluetoothState.off;
          break;
        case BluetoothAdapterState.unauthorized:
          newState = BluetoothState.permissionDenied;
          break;
        case BluetoothAdapterState.unavailable:
          newState = BluetoothState.unsupported;
          break;
        default:
          newState = BluetoothState.unknown;
          break;
      }

      // Detectar mudança de estado
      if (newState != _currentBluetoothState) {
        final oldState = _currentBluetoothState;
        _currentBluetoothState = newState;
        
        logger.warn(
          'Bluetooth mudou de estado (Reativo): $oldState -> $newState',
          tag: 'Hardware',
        );

        // Emitir evento
        _bluetoothStateController.add(newState);
        _hardwareEventController.add(HardwareEvent(
          type: HardwareEventType.bluetoothStateChanged,
          oldState: oldState.toString(),
          newState: newState.toString(),
          timestamp: DateTime.now(),
        ));

        // Reagir à mudança
        await _handleBluetoothStateChange(oldState, newState);
      }
    });
    
    logger.info('Monitoramento de Bluetooth (Reativo) iniciado', tag: 'Hardware');
  }

  /// Verifica estado inicial do Bluetooth (usado apenas na inicialização)
  Future<void> _checkBluetoothState() async {
    final state = await FlutterBluePlus.adapterState.first;
    // Forçar a primeira notificação
    _bluetoothSubscription?.onData(state);
  }

  /// Reage a mudanças de estado do Bluetooth
  Future<void> _handleBluetoothStateChange(
    BluetoothState oldState,
    BluetoothState newState,
  ) async {
    if (newState == BluetoothState.off) {
      // BLUETOOTH DESLIGADO - AÇÃO CRÍTICA
      logger.error('⚠️ BLUETOOTH DESLIGADO! Malha mesh comprometida', tag: 'Hardware');
      
      // Pausar serviços que dependem de Bluetooth
      // await _relay.pause();
      
      // Notificar usuário
      _hardwareEventController.add(HardwareEvent(
        type: HardwareEventType.criticalHardwareFailure,
        message: 'Bluetooth desligado! Ative para continuar na malha mesh.',
        timestamp: DateTime.now(),
      ));
    } else if (newState == BluetoothState.on && oldState == BluetoothState.off) {
      // BLUETOOTH RELIGADO - RECONECTAR
      logger.info('✅ Bluetooth religado! Reconectando à malha...', tag: 'Hardware');
      
      // Aguardar estabilização
      await Future.delayed(Duration(seconds: _RECONNECT_DELAY_SECONDS));
      
      // Retomar serviços
      // await _relay.resume();
      
      // Notificar usuário
      _hardwareEventController.add(HardwareEvent(
        type: HardwareEventType.hardwareRecovered,
        message: 'Bluetooth ativo! Reconectando à malha mesh...',
        timestamp: DateTime.now(),
      ));
    } else if (newState == BluetoothState.permissionDenied) {
      // PERMISSÃO NEGADA
      logger.error('⚠️ Permissão de Bluetooth negada!', tag: 'Hardware');
      
      _hardwareEventController.add(HardwareEvent(
        type: HardwareEventType.permissionDenied,
        message: 'Permissão de Bluetooth necessária para operação.',
        timestamp: DateTime.now(),
      ));
    }
  }

  // ==================== MONITORAMENTO DE GPS/LOCALIZAÇÃO (REATIVO) ====================

  /// Inicia monitoramento reativo de GPS
  void _startLocationMonitoring() {
    _locationSubscription?.cancel();
    
    final Location location = Location();
    
    // Subscrição ao estado de serviço de localização
    _locationSubscription = location.onLocationChanged.listen((_) async {
      await _checkLocationState();
    });
    
    // Subscrição para garantir que o estado inicial seja verificado
    _checkLocationState();
    
    logger.info('Monitoramento de GPS (Reativo) iniciado', tag: 'Hardware');
  }

  /// Verifica estado atual do GPS
  Future<void> _checkLocationState() async {
    try {
      final Location location = Location();
      
      // 1. Verificar permissão
      final permissionStatus = await location.hasPermission();
      
      LocationState newState;

      if (permissionStatus == PermissionStatus.denied || permissionStatus == PermissionStatus.deniedForever) {
        newState = LocationState.permissionDenied;
      } else if (await location.serviceEnabled()) {
        newState = LocationState.on;
      } else {
        newState = LocationState.off;
      }

      // Detectar mudança de estado
      if (newState != _currentLocationState) {
        final oldState = _currentLocationState;
        _currentLocationState = newState;
        
        logger.warn(
          'GPS mudou de estado (Reativo): $oldState -> $newState',
          tag: 'Hardware',
        );

        // Emitir evento
        _locationStateController.add(newState);
        _hardwareEventController.add(HardwareEvent(
          type: HardwareEventType.locationStateChanged,
          oldState: oldState.toString(),
          newState: newState.toString(),
          timestamp: DateTime.now(),
        ));

        // Reagir à mudança
        await _handleLocationStateChange(oldState, newState);
      }
    } catch (e) {
      logger.error('Erro ao verificar estado do GPS', tag: 'Hardware', error: e);
    }
  }

  /// Reage a mudanças de estado do GPS
  Future<void> _handleLocationStateChange(
    LocationState oldState,
    LocationState newState,
  ) async {
    if (newState == LocationState.off) {
      // GPS DESLIGADO - AVISO
      logger.warn('⚠️ GPS desligado! Nearby Connections pode não funcionar', tag: 'Hardware');
      
      _hardwareEventController.add(HardwareEvent(
        type: HardwareEventType.locationDisabled,
        message: 'GPS desligado! Ative para melhor descoberta de peers.',
        timestamp: DateTime.now(),
      ));
    } else if (newState == LocationState.on && oldState == LocationState.off) {
      // GPS RELIGADO
      logger.info('✅ GPS religado!', tag: 'Hardware');
      
      _hardwareEventController.add(HardwareEvent(
        type: HardwareEventType.hardwareRecovered,
        message: 'GPS ativo! Descoberta de peers otimizada.',
        timestamp: DateTime.now(),
      ));
    } else if (newState == LocationState.permissionDenied) {
      // PERMISSÃO NEGADA
      logger.error('⚠️ Permissão de localização negada!', tag: 'Hardware');
      
      _hardwareEventController.add(HardwareEvent(
        type: HardwareEventType.permissionDenied,
        message: 'Permissão de localização necessária para Nearby Connections.',
        timestamp: DateTime.now(),
      ));
    }
  }

  // ==================== VERIFICAÇÃO MANUAL ====================

  /// Força verificação de todos os hardwares
  Future<void> checkAllHardware() async {
    logger.info('Verificação manual de hardware iniciada', tag: 'Hardware');
    // Forçar a reavaliação do estado
    await _checkBluetoothState();
    await _checkLocationState();
  }

  /// Solicita permissões necessárias
  Future<bool> requestPermissions() async {
    try {
      logger.info('Solicitando permissões de hardware...', tag: 'Hardware');

      // Solicitar Bluetooth
      final bluetoothStatus = await Permission.bluetooth.request();
      final bluetoothConnectStatus = await Permission.bluetoothConnect.request();
      final bluetoothScanStatus = await Permission.bluetoothScan.request();

      // Solicitar Localização
      final locationStatus = await Permission.location.request();

      final allGranted = bluetoothStatus.isGranted &&
          bluetoothConnectStatus.isGranted &&
          bluetoothScanStatus.isGranted &&
          locationStatus.isGranted;

      if (allGranted) {
        logger.info('✅ Todas as permissões concedidas', tag: 'Hardware');
      } else {
        logger.warn('⚠️ Algumas permissões foram negadas', tag: 'Hardware');
      }

      return allGranted;
    } catch (e) {
      logger.error('Erro ao solicitar permissões', tag: 'Hardware', error: e);
      return false;
    }
  }

  // ==================== GETTERS DE ESTADO ====================

  /// Retorna estado atual do Bluetooth
  BluetoothState get bluetoothState => _currentBluetoothState;

  /// Retorna estado atual do GPS
  LocationState get locationState => _currentLocationState;

  /// Verifica se todos os hardwares estão OK
  bool get isHardwareReady {
    return _currentBluetoothState == BluetoothState.on &&
        _currentLocationState == LocationState.on;
  }

  /// Retorna diagnóstico completo do hardware
  Map<String, dynamic> getDiagnostics() {
    return {
      'bluetooth': {
        'state': _currentBluetoothState.toString(),
        'isReady': _currentBluetoothState == BluetoothState.on,
      },
      'location': {
        'state': _currentLocationState.toString(),
        'isReady': _currentLocationState == LocationState.on,
      },
      'overall': {
        'isReady': isHardwareReady,
        'criticalIssues': _getCriticalIssues(),
      },
    };
  }

  /// Lista problemas críticos de hardware
  List<String> _getCriticalIssues() {
    final issues = <String>[];

    if (_currentBluetoothState == BluetoothState.off) {
      issues.add('Bluetooth desligado');
    } else if (_currentBluetoothState == BluetoothState.permissionDenied) {
      issues.add('Permissão de Bluetooth negada');
    }

    if (_currentLocationState == LocationState.off) {
      issues.add('GPS desligado');
    } else if (_currentLocationState == LocationState.permissionDenied) {
      issues.add('Permissão de localização negada');
    }

    return issues;
  }

  // ==================== CLEANUP ====================

  /// Para o monitoramento e libera recursos
  void dispose() {
    _bluetoothSubscription?.cancel();
    _locationSubscription?.cancel();
    _bluetoothStateController.close();
    _locationStateController.close();
    _hardwareEventController.close();
    logger.info('Monitoramento de hardware encerrado', tag: 'Hardware');
  }
}

// ==================== ENUMS E MODELOS ====================

/// Estados do Bluetooth
enum BluetoothState {
  unknown,
  on,
  off,
  permissionDenied,
  unsupported,
}

/// Estados do GPS/Localização
enum LocationState {
  unknown,
  on,
  off,
  permissionDenied,
}

/// Tipos de eventos de hardware
enum HardwareEventType {
  bluetoothStateChanged,
  locationStateChanged,
  criticalHardwareFailure,
  hardwareRecovered,
  permissionDenied,
  locationDisabled,
}

/// Evento de hardware
class HardwareEvent {
  final HardwareEventType type;
  final String? oldState;
  final String? newState;
  final String? message;
  final DateTime timestamp;

  HardwareEvent({
    required this.type,
    this.oldState,
    this.newState,
    this.message,
    required this.timestamp,
  });

  @override
  String toString() {
    return 'HardwareEvent(type: $type, message: $message, timestamp: $timestamp)';
  }
}
