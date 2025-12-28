import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';
import '../utils/logger_service.dart';
import '../errors/exceptions.dart';

/// Serviço de Identidade do Dispositivo
/// 
/// Gerencia a identidade persistente do nó na malha mesh.
/// O peerId é um UUID v4 gerado nativamente no primeiro boot
/// e armazenado no SecureStorage para persistência entre sessões.
/// 
/// CARACTERÍSTICAS:
/// - UUID v4 gerado no primeiro boot
/// - Persistência no SecureStorage
/// - Imutável após criação (impressão digital do nó)
/// - Usado como identificador único na malha mesh
class DeviceIdentityService {
  static final DeviceIdentityService _instance = DeviceIdentityService._internal();
  factory DeviceIdentityService() => _instance;
  DeviceIdentityService._internal();

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  
  static const String _PEER_ID_KEY = 'device_peer_id';
  static const String _DEVICE_NAME_KEY = 'device_name';
  static const String _CREATED_AT_KEY = 'device_created_at';
  
  String? _peerId;
  String? _deviceName;
  DateTime? _createdAt;

  /// Inicializa o serviço de identidade
  /// Gera UUID v4 no primeiro boot ou carrega do SecureStorage
  Future<void> initialize({String? customDeviceName}) async {
    try {
      // Verificar se já existe um peerId armazenado
      final storedPeerId = await _secureStorage.read(key: _PEER_ID_KEY);
      
      if (storedPeerId == null) {
        // PRIMEIRO BOOT: Gerar UUID v4
        logger.info('Primeiro boot detectado. Gerando UUID v4 para peerId...', tag: 'Identity');
        await _generateAndStoreIdentity(customDeviceName);
      } else {
        // Carregar identidade existente
        logger.info('Carregando identidade do SecureStorage...', tag: 'Identity');
        await _loadIdentityFromStorage();
      }
      
      logger.info('Identidade do dispositivo: $_peerId', tag: 'Identity');
      logger.info('Nome do dispositivo: $_deviceName', tag: 'Identity');
      logger.info('Criado em: $_createdAt', tag: 'Identity');
    } catch (e) {
      logger.error('Falha ao inicializar DeviceIdentityService', tag: 'Identity', error: e);
      throw Exception('Inicialização de identidade falhou: $e');
    }
  }

  /// Gera e armazena identidade no primeiro boot
  Future<void> _generateAndStoreIdentity(String? customDeviceName) async {
    // Gerar UUID v4 nativo
    _peerId = _generateUUIDv4();
    _deviceName = customDeviceName ?? 'Speew-${_peerId!.substring(0, 8)}';
    _createdAt = DateTime.now();
    
    // Armazenar no SecureStorage
    await _secureStorage.write(key: _PEER_ID_KEY, value: _peerId);
    await _secureStorage.write(key: _DEVICE_NAME_KEY, value: _deviceName);
    await _secureStorage.write(key: _CREATED_AT_KEY, value: _createdAt!.toIso8601String());
    
    logger.info('Identidade gerada e armazenada: $_peerId', tag: 'Identity');
  }

  /// Carrega identidade do SecureStorage
  Future<void> _loadIdentityFromStorage() async {
    _peerId = await _secureStorage.read(key: _PEER_ID_KEY);
    _deviceName = await _secureStorage.read(key: _DEVICE_NAME_KEY);
    
    final createdAtStr = await _secureStorage.read(key: _CREATED_AT_KEY);
    if (createdAtStr != null) {
      _createdAt = DateTime.parse(createdAtStr);
    }
    
    if (_peerId == null) {
      throw Exception('PeerId não encontrado no SecureStorage');
    }
  }

  /// Gera UUID v4 nativo usando biblioteca uuid (RFC 4122)
  /// 
  /// Formato: xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx
  /// onde x é qualquer dígito hexadecimal e y é um de 8, 9, A ou B
  String _generateUUIDv4() {
    const uuid = Uuid();
    return uuid.v4();
  }

  /// Retorna o peerId do dispositivo
  String get peerId {
    if (_peerId == null) {
      throw Exception('DeviceIdentityService não inicializado');
    }
    return _peerId!;
  }

  /// Retorna o nome do dispositivo
  String get deviceName {
    if (_deviceName == null) {
      throw Exception('DeviceIdentityService não inicializado');
    }
    return _deviceName!;
  }

  /// Retorna a data de criação da identidade
  DateTime get createdAt {
    if (_createdAt == null) {
      throw Exception('DeviceIdentityService não inicializado');
    }
    return _createdAt!;
  }

  /// Verifica se o serviço está inicializado
  bool get isInitialized => _peerId != null;

  /// Atualiza o nome do dispositivo
  Future<void> updateDeviceName(String newName) async {
    if (!isInitialized) {
      throw Exception('DeviceIdentityService não inicializado');
    }
    
    _deviceName = newName;
    await _secureStorage.write(key: _DEVICE_NAME_KEY, value: newName);
    logger.info('Nome do dispositivo atualizado: $newName', tag: 'Identity');
  }

  /// Retorna informações completas da identidade
  Map<String, dynamic> getIdentityInfo() {
    if (!isInitialized) {
      throw Exception('DeviceIdentityService não inicializado');
    }
    
    return {
      'peerId': _peerId,
      'deviceName': _deviceName,
      'createdAt': _createdAt?.toIso8601String(),
      'isInitialized': isInitialized,
    };
  }

  /// APENAS PARA TESTES: Reseta a identidade (CUIDADO!)
  Future<void> resetIdentity() async {
    logger.warn('ATENÇÃO: Resetando identidade do dispositivo!', tag: 'Identity');
    
    await _secureStorage.delete(key: _PEER_ID_KEY);
    await _secureStorage.delete(key: _DEVICE_NAME_KEY);
    await _secureStorage.delete(key: _CREATED_AT_KEY);
    
    _peerId = null;
    _deviceName = null;
    _createdAt = null;
    
    logger.info('Identidade resetada', tag: 'Identity');
  }
}
