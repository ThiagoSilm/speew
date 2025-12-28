import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../utils/logger_service.dart';
import '../storage/encrypted_message_store.dart';
import '../identity/device_identity_service.dart';
import '../crypto/crypto_manager.dart';
import '../mesh/message_queue_processor.dart';
import '../background/mesh_background_service.dart';

/// Serviço de Wipe de Emergência
/// 
/// Implementa função de "Wipe" (limpar tudo) para software de missão crítica.
/// O usuário pode apagar TODOS os rastros de comunicação com um toque.
/// 
/// CARACTERÍSTICAS CRÍTICAS:
/// - Wipe de mensagens (banco de dados)
/// - Wipe de chaves criptográficas
/// - Wipe de identidade (peerId)
/// - Wipe de cache e filas
/// - Wipe de SecureStorage
/// - Confirmação obrigatória
/// - Irreversível
class EmergencyWipeService {
  static final EmergencyWipeService _instance = EmergencyWipeService._internal();
  factory EmergencyWipeService() => _instance;
  EmergencyWipeService._internal();

  // Referências a serviços
  final EncryptedMessageStore _storage = EncryptedMessageStore();
  final DeviceIdentityService _identity = DeviceIdentityService();
  final CryptoManager _crypto = CryptoManager();
  final MessageQueueProcessor _queue = MessageQueueProcessor();
  final MeshBackgroundService _background = MeshBackgroundService();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  // Estado do wipe
  bool _isWiping = false;
  WipeProgress? _currentProgress;

  // Stream de progresso
  final StreamController<WipeProgress> _progressController = 
      StreamController<WipeProgress>.broadcast();
  Stream<WipeProgress> get progressStream => _progressController.stream;

  /// Inicializa o serviço de wipe
  Future<void> initialize() async {
    logger.info('EmergencyWipeService inicializado', tag: 'Wipe');
  }

  // ==================== WIPE COMPLETO ====================

  /// Executa WIPE COMPLETO de todos os dados
  /// 
  /// ATENÇÃO: Esta operação é IRREVERSÍVEL!
  /// Todos os dados serão permanentemente apagados.
  Future<WipeResult> executeFullWipe({
    required String confirmationCode,
    bool includeIdentity = true,
    bool includeCryptoKeys = true,
    bool includeMessages = true,
    bool includeCache = true,
  }) async {
    if (_isWiping) {
      return WipeResult(
        success: false,
        message: 'Wipe já em andamento',
        timestamp: DateTime.now(),
      );
    }

    try {
      _isWiping = true;
      logger.warn('🔥 WIPE COMPLETO INICIADO 🔥', tag: 'Wipe');

      // Validar código de confirmação
      if (!_validateConfirmationCode(confirmationCode)) {
        return WipeResult(
          success: false,
          message: 'Código de confirmação inválido',
          timestamp: DateTime.now(),
        );
      }

      final steps = <WipeStep>[];
      int currentStep = 0;
      int totalSteps = 6;

      // PASSO 1: Parar serviços em execução
      currentStep++;
      _updateProgress(currentStep, totalSteps, 'Parando serviços...');
      steps.add(await _stopServices());

      // PASSO 2: Limpar filas de mensagens
      if (includeCache) {
        currentStep++;
        _updateProgress(currentStep, totalSteps, 'Limpando filas...');
        steps.add(await _clearQueues());
      }

      // PASSO 3: Apagar mensagens do banco de dados
      if (includeMessages) {
        currentStep++;
        _updateProgress(currentStep, totalSteps, 'Apagando mensagens...');
        steps.add(await _wipeMessages());
      }

      // PASSO 4: Apagar chaves criptográficas
      if (includeCryptoKeys) {
        currentStep++;
        _updateProgress(currentStep, totalSteps, 'Apagando chaves...');
        steps.add(await _wipeCryptoKeys());
      }

      // PASSO 5: Apagar identidade
      if (includeIdentity) {
        currentStep++;
        _updateProgress(currentStep, totalSteps, 'Apagando identidade...');
        steps.add(await _wipeIdentity());
      }

      // PASSO 6: Limpar SecureStorage
      currentStep++;
      _updateProgress(currentStep, totalSteps, 'Limpando storage seguro...');
      steps.add(await _wipeSecureStorage());

      // Verificar se todos os passos foram bem-sucedidos
      final allSuccess = steps.every((step) => step.success);

      final result = WipeResult(
        success: allSuccess,
        message: allSuccess 
            ? 'Wipe completo executado com sucesso' 
            : 'Wipe completo com alguns erros',
        steps: steps,
        timestamp: DateTime.now(),
      );

      logger.warn(
        '🔥 WIPE COMPLETO FINALIZADO: ${allSuccess ? "SUCESSO" : "COM ERROS"} 🔥',
        tag: 'Wipe',
      );

      return result;
    } catch (e) {
      logger.error('Erro crítico durante wipe', tag: 'Wipe', error: e);
      return WipeResult(
        success: false,
        message: 'Erro crítico durante wipe: $e',
        timestamp: DateTime.now(),
      );
    } finally {
      _isWiping = false;
      _currentProgress = null;
    }
  }

  // ==================== PASSOS DO WIPE ====================

  /// Passo 1: Parar todos os serviços
  Future<WipeStep> _stopServices() async {
    try {
      logger.info('Parando serviços...', tag: 'Wipe');

      // Parar background service
      if (_background.isRunning) {
        await _background.stop();
      }

      // Parar processamento de fila
      _queue.stop();

      return WipeStep(
        name: 'Parar Serviços',
        success: true,
        message: 'Serviços parados com sucesso',
      );
    } catch (e) {
      logger.error('Erro ao parar serviços', tag: 'Wipe', error: e);
      return WipeStep(
        name: 'Parar Serviços',
        success: false,
        message: 'Erro ao parar serviços: $e',
      );
    }
  }

  /// Passo 2: Limpar filas de mensagens
  Future<WipeStep> _clearQueues() async {
    try {
      logger.info('Limpando filas...', tag: 'Wipe');

      await _queue.clear();

      return WipeStep(
        name: 'Limpar Filas',
        success: true,
        message: 'Filas limpas com sucesso',
      );
    } catch (e) {
      logger.error('Erro ao limpar filas', tag: 'Wipe', error: e);
      return WipeStep(
        name: 'Limpar Filas',
        success: false,
        message: 'Erro ao limpar filas: $e',
      );
    }
  }

  /// Passo 3: Apagar mensagens do banco de dados
  Future<WipeStep> _wipeMessages() async {
    try {
      logger.warn('Apagando TODAS as mensagens...', tag: 'Wipe');

      // Obter estatísticas antes do wipe
      final statsBefore = await _storage.getStats();
      final messageCount = statsBefore['messageCount'] ?? 0;

      // Executar wipe de dados
      await _storage.wipeAllData();

      // Executar wipe nuclear (deletar banco do disco)
      await _storage.wipeDatabase();

      return WipeStep(
        name: 'Apagar Mensagens',
        success: true,
        message: '$messageCount mensagens apagadas permanentemente',
      );
    } catch (e) {
      logger.error('Erro ao apagar mensagens', tag: 'Wipe', error: e);
      return WipeStep(
        name: 'Apagar Mensagens',
        success: false,
        message: 'Erro ao apagar mensagens: $e',
      );
    }
  }

  /// Passo 4: Apagar chaves criptográficas
  Future<WipeStep> _wipeCryptoKeys() async {
    try {
      logger.warn('Apagando chaves criptográficas...', tag: 'Wipe');

      // Deletar chaves do SecureStorage
      await _secureStorage.delete(key: 'signing_private_key');
      await _secureStorage.delete(key: 'signing_public_key');
      await _secureStorage.delete(key: 'encryption_private_key');
      await _secureStorage.delete(key: 'encryption_public_key');

      return WipeStep(
        name: 'Apagar Chaves Criptográficas',
        success: true,
        message: 'Chaves criptográficas apagadas',
      );
    } catch (e) {
      logger.error('Erro ao apagar chaves', tag: 'Wipe', error: e);
      return WipeStep(
        name: 'Apagar Chaves Criptográficas',
        success: false,
        message: 'Erro ao apagar chaves: $e',
      );
    }
  }

  /// Passo 5: Apagar identidade (peerId)
  Future<WipeStep> _wipeIdentity() async {
    try {
      logger.warn('Apagando identidade do dispositivo...', tag: 'Wipe');

      await _identity.resetIdentity();

      return WipeStep(
        name: 'Apagar Identidade',
        success: true,
        message: 'Identidade do dispositivo apagada',
      );
    } catch (e) {
      logger.error('Erro ao apagar identidade', tag: 'Wipe', error: e);
      return WipeStep(
        name: 'Apagar Identidade',
        success: false,
        message: 'Erro ao apagar identidade: $e',
      );
    }
  }

  /// Passo 6: Limpar SecureStorage
  Future<WipeStep> _wipeSecureStorage() async {
    try {
      logger.warn('Limpando SecureStorage...', tag: 'Wipe');

      // Deletar TUDO do SecureStorage
      await _secureStorage.deleteAll();

      return WipeStep(
        name: 'Limpar SecureStorage',
        success: true,
        message: 'SecureStorage limpo completamente',
      );
    } catch (e) {
      logger.error('Erro ao limpar SecureStorage', tag: 'Wipe', error: e);
      return WipeStep(
        name: 'Limpar SecureStorage',
        success: false,
        message: 'Erro ao limpar SecureStorage: $e',
      );
    }
  }

  // ==================== WIPES PARCIAIS ====================

  /// Wipe apenas de mensagens (mantém identidade e chaves)
  Future<WipeResult> wipeMessagesOnly() async {
    return await executeFullWipe(
      confirmationCode: 'WIPE_MESSAGES',
      includeIdentity: false,
      includeCryptoKeys: false,
      includeMessages: true,
      includeCache: true,
    );
  }

  /// Wipe de cache (filas e mensagens temporárias)
  Future<WipeResult> wipeCacheOnly() async {
    try {
      logger.info('Limpando cache...', tag: 'Wipe');

      await _queue.clear();

      return WipeResult(
        success: true,
        message: 'Cache limpo com sucesso',
        timestamp: DateTime.now(),
      );
    } catch (e) {
      logger.error('Erro ao limpar cache', tag: 'Wipe', error: e);
      return WipeResult(
        success: false,
        message: 'Erro ao limpar cache: $e',
        timestamp: DateTime.now(),
      );
    }
  }

  // ==================== VALIDAÇÃO ====================

  /// Valida código de confirmação
  bool _validateConfirmationCode(String code) {
    // Em produção, usar código mais robusto
    // Por exemplo: PIN do usuário, biometria, etc.
    const validCodes = [
      'WIPE_ALL',
      'EMERGENCY_WIPE',
      'DELETE_EVERYTHING',
    ];
    return validCodes.contains(code);
  }

  /// Gera código de confirmação único
  String generateConfirmationCode() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final code = 'WIPE_${timestamp % 10000}';
    logger.info('Código de confirmação gerado: $code', tag: 'Wipe');
    return code;
  }

  // ==================== PROGRESSO ====================

  /// Atualiza progresso do wipe
  void _updateProgress(int current, int total, String message) {
    _currentProgress = WipeProgress(
      currentStep: current,
      totalSteps: total,
      message: message,
      percentage: (current / total * 100).round(),
    );

    _progressController.add(_currentProgress!);
    logger.info('Wipe: [$current/$total] $message', tag: 'Wipe');
  }

  // ==================== ESTATÍSTICAS ====================

  /// Retorna estatísticas de dados que serão apagados
  Future<Map<String, dynamic>> getWipePreview() async {
    try {
      final storageStats = await _storage.getStats();
      final queueStats = _queue.getStats();

      return {
        'messages': storageStats['messageCount'] ?? 0,
        'peers': storageStats['peerCount'] ?? 0,
        'queuedMessages': queueStats['queues']['total'] ?? 0,
        'identityExists': _identity.isInitialized,
        'cryptoKeysExist': true, // Assumir que existem
      };
    } catch (e) {
      logger.error('Erro ao obter preview de wipe', tag: 'Wipe', error: e);
      return {};
    }
  }

  // ==================== CLEANUP ====================

  /// Encerra o serviço
  void dispose() {
    _progressController.close();
    logger.info('EmergencyWipeService encerrado', tag: 'Wipe');
  }
}

// ==================== MODELOS ====================

/// Resultado do wipe
class WipeResult {
  final bool success;
  final String message;
  final List<WipeStep>? steps;
  final DateTime timestamp;

  WipeResult({
    required this.success,
    required this.message,
    this.steps,
    required this.timestamp,
  });

  @override
  String toString() {
    return 'WipeResult(success: $success, message: $message, steps: ${steps?.length ?? 0})';
  }
}

/// Passo individual do wipe
class WipeStep {
  final String name;
  final bool success;
  final String message;

  WipeStep({
    required this.name,
    required this.success,
    required this.message,
  });

  @override
  String toString() {
    return 'WipeStep(name: $name, success: $success)';
  }
}

/// Progresso do wipe
class WipeProgress {
  final int currentStep;
  final int totalSteps;
  final String message;
  final int percentage;

  WipeProgress({
    required this.currentStep,
    required this.totalSteps,
    required this.message,
    required this.percentage,
  });

  @override
  String toString() {
    return 'WipeProgress($percentage% - $message)';
  }
}
