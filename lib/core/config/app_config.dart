/// Configurações centralizadas da aplicação
/// 
/// Contém todas as constantes e parâmetros configuráveis do sistema
class AppConfig {
  // Configurações de Blockchain
  static const int blockSize = 1024 * 1024; // 1MB
  static const int maxBlocksPerBatch = 10;
  static const Duration blockValidationTimeout = Duration(seconds: 30);

  // Configurações de Rede P2P
  static const int maxConnections = 50;
  static const int minConnections = 3;
  static const Duration connectionTimeout = Duration(seconds: 15);
  static const Duration heartbeatInterval = Duration(seconds: 10);
  static const Duration reconnectDelay = Duration(seconds: 5);

  // Configurações de Mesh
  static const int maxHops = 7;
  static const double maxPacketLoss = 0.3; // 30%
  static const Duration meshSyncInterval = Duration(seconds: 20);
  static const Duration routeCacheExpiry = Duration(minutes: 5);
  static const bool enableCompression = true;
  static int maxMultiPaths = 3;
  static Duration marketplaceBroadcastInterval = Duration(seconds: 30);
  static Duration keepAliveInterval = Duration(seconds: 10);
  static int minSizeForCompression = 512; // bytes

  // Configurações de Criptografia
  static const int keyRotationDays = 30;
  static const int signatureSize = 64;
  static const String defaultHashAlgorithm = 'SHA-256';
  static const bool enableEndToEndEncryption = true;

  // Configurações de Reputação
  static const double initialReputation = 50.0;
  static const double minReputation = 0.0;
  static const double maxReputation = 100.0;
  static const double reputationDecayRate = 0.01; // por dia
  static const int reputationHistoryDays = 90;

  // Configurações de Wallet
  static const String defaultCurrency = 'MESH';
  static const int transactionConfirmations = 3;
  static const Duration transactionTimeout = Duration(minutes: 5);
  static const double minTransactionAmount = 0.001;

  // Configurações de Storage
  static const String databaseName = 'mesh_p2p.db';
  static const int databaseVersion = 1;
  static const Duration backupInterval = Duration(hours: 24);
  static const int maxBackupRetention = 7; // dias

  // Configurações de Simulador
  static const int simulatorSeed = 42;
  static const int simulatorDefaultNodes = 10;
  static const Duration simulatorLatencyMin = Duration(milliseconds: 10);
  static const Duration simulatorLatencyMax = Duration(milliseconds: 200);
  static const double simulatorPacketLoss = 0.05; // 5%

  // Configurações de Stealth/Fantasma
  static bool stealthMode = false;
  static const Duration stealthModeRotationInterval = Duration(hours: 1);
  static const bool enableIdentityRotation = true;

  // Configurações de UI
  static const Duration uiDebounceDelay = Duration(milliseconds: 300);
  static const int maxMessagesPerPage = 50;
  static const int maxFileSizeForPreview = 10 * 1024 * 1024; // 10MB

  // Configurações de Logger
  static const bool enableDebugLogs = true;
  static const bool enableInfoLogs = true;
  static const bool enableWarningLogs = true;
  static const bool enableErrorLogs = true;
  static const int maxLogFileSize = 5 * 1024 * 1024; // 5MB
  static const int maxLogFiles = 3;

  // Configurações de Performance
  static const bool enableShortCircuitDuplicates = true;
  static const bool enableIncrementalChecksum = true;
  static const int discoveryDebounceMs = 500;
  static const int stateRecalculationDebounceMs = 1000;

  // Ambiente
  static const String environment = 'development'; // development, staging, production
  static const String version = '0.5.0';
  static const String buildNumber = '5';

  /// Verifica se está em modo de desenvolvimento
  static bool get isDevelopment => environment == 'development';

  /// Verifica se está em modo de produção
  static bool get isProduction => environment == 'production';

  /// Retorna configurações como Map para debug
  static Map<String, dynamic> toMap() {
    return {
      'version': version,
      'buildNumber': buildNumber,
      'environment': environment,
      'blockSize': blockSize,
      'maxConnections': maxConnections,
      'maxHops': maxHops,
      'enableCompression': enableCompression,
      'enableStealthMode': enableStealthMode,
      'enableDebugLogs': enableDebugLogs,
    };
  }
}
