import '../core/utils/logger_service.dart';
import 'backup/backup_service.dart';
import 'crypto/crypto_service.dart';
import 'identity/identity_rotation_service.dart';
import 'ledger/distributed_ledger_service.dart';
import 'mesh/intelligent_mesh_service.dart';
import 'mesh/priority_queue_service.dart';
import 'network/file_transfer_service.dart';
import 'network/large_file_transfer_service.dart';
import 'network/p2p_service.dart';
import 'network/private_network_service.dart';
import 'package:flutter/foundation.dart';
import 'reputation/reputation_service.dart';
import 'security/conflict_detection_service.dart';
import 'stealth/stealth_service.dart';
import 'storage/database_service.dart';
import 'sync/social_sync_service.dart';
import 'trust/advanced_trust_service.dart';
import 'wallet/advanced_wallet_service.dart';
import 'wallet/wallet_service.dart';

// Importações dos serviços base (existentes)
// Importações dos novos serviços (adicionados)
// Importações da Segunda Atualização: Sincronização Social Distribuída
/// ==================== SERVIÇO DE INTEGRAÇÃO ====================
/// Coordena todos os serviços do aplicativo (base + expansões)
/// 
/// Este serviço atua como ponto central de inicialização e coordenação
/// entre os serviços existentes e os novos módulos adicionados.
///
/// ADICIONADO: Fase 9 - Integração de todas as funcionalidades
class IntegrationService extends ChangeNotifier {
  static final IntegrationService _instance = IntegrationService._internal();
  factory IntegrationService() => _instance;
  IntegrationService._internal();

  // ==================== SERVIÇOS BASE (EXISTENTES) ====================
  
  late final CryptoService crypto;
  late final DatabaseService database;
  late final ReputationService reputation;
  late final WalletService wallet;
  late final P2PService p2p;
  late final FileTransferService fileTransfer;

  // ==================== NOVOS SERVIÇOS (EXPANSÕES) ====================
  
  late final StealthService stealth;
  late final IntelligentMeshService mesh;
  late final AdvancedWalletService advancedWallet;
  late final AdvancedTrustService trust;
  late final LargeFileTransferService largeFileTransfer;
  late final PrivateNetworkService privateNetwork;
  late final BackupService backup;

  // ==================== SEGUNDA ATUALIZAÇÃO: SINCRONIZAÇÃO SOCIAL ====================
  
  late final SocialSyncService socialSync;
  late final DistributedLedgerService distributedLedger;
  late final ConflictDetectionService conflictDetection;
  late final IdentityRotationService identityRotation;
  late final PriorityQueueService priorityQueue;

  /// Estado de inicialização
  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  /// Modo de operação atual
  AppMode _currentMode = AppMode.normal;
  AppMode get currentMode => _currentMode;

  // ==================== INICIALIZAÇÃO ====================

  /// Inicializa todos os serviços
  Future<void> initialize() async {
    if (_isInitialized) {
      logger.info('Serviços já inicializados', tag: 'Integration');
      return;
    }

    try {
      logger.info('Inicializando serviços...', tag: 'Integration');

      // Inicializa serviços base
      crypto = CryptoService();
      database = DatabaseService();
      reputation = ReputationService();
      wallet = WalletService();
      p2p = P2PService();
      fileTransfer = FileTransferService();

      // Inicializa novos serviços
      stealth = StealthService();
      mesh = IntelligentMeshService();
      advancedWallet = AdvancedWalletService();
      trust = AdvancedTrustService();
      largeFileTransfer = LargeFileTransferService();
      privateNetwork = PrivateNetworkService();
      backup = BackupService();

      // Inicializa serviços da Segunda Atualização
      socialSync = SocialSyncService();
      distributedLedger = DistributedLedgerService();
      conflictDetection = ConflictDetectionService();
      identityRotation = IdentityRotationService();
      priorityQueue = PriorityQueueService();

      // Inicializa tipos de moeda padrão
      await advancedWallet.initializeDefaultCoinTypes();

      logger.info('Segunda Atualização: Sincronização Social Distribuída ativada', tag: 'Integration');

      _isInitialized = true;
      logger.info('Todos os serviços inicializados com sucesso', tag: 'Integration');
      notifyListeners();
    } catch (e) {
      logger.info('Erro ao inicializar serviços: $e', tag: 'Integration');
      rethrow;
    }
  }

  // ==================== MODOS DE OPERAÇÃO ====================

  /// Alterna para modo fantasma
  Future<void> enableStealthMode({Duration? rotationInterval}) async {
    try {
      await stealth.enableStealthMode(rotationInterval: rotationInterval);
      _currentMode = AppMode.stealth;
      
      logger.info('Modo fantasma ativado', tag: 'Integration');
      notifyListeners();
    } catch (e) {
      logger.info('Erro ao ativar modo fantasma: $e', tag: 'Integration');
      rethrow;
    }
  }

  /// Desativa modo fantasma
  Future<void> disableStealthMode() async {
    try {
      await stealth.disableStealthMode();
      _currentMode = AppMode.normal;
      
      logger.info('Modo fantasma desativado', tag: 'Integration');
      notifyListeners();
    } catch (e) {
      logger.info('Erro ao desativar modo fantasma: $e', tag: 'Integration');
    }
  }

  /// Entra em uma rede privada
  Future<bool> joinPrivateNetwork({
    required String networkId,
    required String userId,
    required String accessKey,
  }) async {
    try {
      final success = await privateNetwork.joinPrivateNetwork(
        networkId: networkId,
        userId: userId,
        accessKey: accessKey,
      );

      if (success) {
        _currentMode = AppMode.privateNetwork;
        notifyListeners();
      }

      return success;
    } catch (e) {
      logger.info('Erro ao entrar em rede privada: $e', tag: 'Integration');
      return false;
    }
  }

  /// Sai da rede privada atual
  Future<void> leavePrivateNetwork(String userId) async {
    try {
      if (privateNetwork.currentNetworkId != null) {
        await privateNetwork.leavePrivateNetwork(
          privateNetwork.currentNetworkId!,
          userId,
        );
        _currentMode = AppMode.normal;
        notifyListeners();
      }
    } catch (e) {
      logger.info('Erro ao sair da rede privada: $e', tag: 'Integration');
    }
  }

  // ==================== COORDENAÇÃO DE FUNCIONALIDADES ====================

  /// Envia mensagem com todas as otimizações
  Future<String> sendOptimizedMessage({
    required String senderId,
    required String receiverId,
    required String content,
    Duration? selfDestructDelay,
  }) async {
    try {
      // 1. Verifica confiança do destinatário
      final isTrusted = await trust.isTrustedForTransactions(receiverId);
      if (!isTrusted) {
        logger.info('Destinatário não é confiável', tag: 'Integration');
      }

      // 2. Calcula prioridade da mensagem
      final priority = await mesh.calculateMessagePriority(senderId, 'text');

      // 3. Envia mensagem (implementação simulada)
      final messageId = crypto.generateUniqueId();

      // 4. Agenda autodestruição se em modo stealth
      if (stealth.isStealthMode && selfDestructDelay != null) {
        stealth.scheduleMessageDestruction(messageId, selfDestructDelay);
      }

      // 5. Registra evento de confiança
      await trust.recordTrustEvent(
        userId: senderId,
        eventType: 'message_delivered',
      );

      logger.info('Mensagem enviada com otimizações: $messageId', tag: 'Integration');
      return messageId;
    } catch (e) {
      logger.info('Erro ao enviar mensagem otimizada: $e', tag: 'Integration');
      rethrow;
    }
  }

  /// Transfere arquivo grande com otimizações
  Future<bool> transferLargeFile({
    required String filePath,
    required String ownerId,
    required String receiverId,
    bool enableCompression = true,
  }) async {
    try {
      // 1. Verifica confiança
      final isTrusted = await trust.isTrustedForFileSharing(receiverId);
      if (!isTrusted) {
        logger.info('Destinatário não é confiável para arquivos', tag: 'Integration');
        return false;
      }

      // 2. Fragmenta arquivo (implementação simulada)
      logger.info('Fragmentando arquivo grande...', tag: 'Integration');

      // 3. Registra evento de confiança
      await trust.recordTrustEvent(
        userId: ownerId,
        eventType: 'file_shared',
      );

      return true;
    } catch (e) {
      logger.info('Erro ao transferir arquivo: $e', tag: 'Integration');
      return false;
    }
  }

  /// Cria transação com validação completa
  Future<String?> createValidatedTransaction({
    required String senderId,
    required String receiverId,
    required double amount,
    required String coinTypeId,
    required String privateKey,
  }) async {
    try {
      // 1. Verifica confiança
      final isTrusted = await trust.isTrustedForTransactions(receiverId);
      if (!isTrusted) {
        logger.info('Destinatário não é confiável para transações', tag: 'Integration');
      }

      // 2. Verifica saldo
      final balance = await advancedWallet.getUserBalanceByType(senderId, coinTypeId);
      if (balance < amount) {
        logger.info('Saldo insuficiente', tag: 'Integration');
        return null;
      }

      // 3. Cria transação (implementação simulada)
      final txId = crypto.generateUniqueId();

      // 4. Registra evento de confiança
      await trust.recordTrustEvent(
        userId: senderId,
        eventType: 'transaction_accepted',
      );

      logger.info('Transação criada: $txId', tag: 'Integration');
      return txId;
    } catch (e) {
      logger.info('Erro ao criar transação: $e', tag: 'Integration');
      return null;
    }
  }

  // ==================== MANUTENÇÃO E LIMPEZA ====================

  /// Executa manutenção periódica de todos os serviços
  Future<void> performMaintenance() async {
    try {
      logger.info('Executando manutenção...', tag: 'Integration');

      // Manutenção do mesh inteligente
      mesh.performMaintenance();

      // Limpeza de eventos antigos
      await trust.cleanOldEvents();

      // Limpeza de transferências concluídas
      largeFileTransfer.clearCompletedTransfers();

      logger.info('Manutenção concluída', tag: 'Integration');
    } catch (e) {
      logger.info('Erro na manutenção: $e', tag: 'Integration');
    }
  }

  /// Limpa todos os caches
  void clearAllCaches() {
    reputation.clearCache();
    advancedWallet.clearBalanceCache();
    trust.clearCache();
    privateNetwork.clearCache();
    
    logger.info('Todos os caches limpos', tag: 'Integration');
    notifyListeners();
  }

  // ==================== ESTATÍSTICAS GLOBAIS ====================

  /// Obtém estatísticas gerais do aplicativo
  Future<Map<String, dynamic>> getGlobalStats(String userId) async {
    try {
      return {
        'mode': _currentMode.toString(),
        'stealth': stealth.getStealthStats(),
        'mesh': mesh.getMeshStats(),
        'trust': await trust.getTrustStats(userId),
        'wallet': await advancedWallet.getTransactionStats(userId),
        'privateNetwork': privateNetwork.currentNetworkId != null
            ? await privateNetwork.getNetworkStats(privateNetwork.currentNetworkId!)
            : null,
      };
    } catch (e) {
      logger.info('Erro ao obter estatísticas: $e', tag: 'Integration');
      return {};
    }
  }
}

/// Enum de modos de operação do aplicativo
enum AppMode {
  normal,
  stealth,
  privateNetwork,
}
