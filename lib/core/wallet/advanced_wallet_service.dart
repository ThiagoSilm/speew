import '../../core/utils/logger_service.dart';
import '../../models/coin_transaction.dart';
import '../../models/coin_type.dart';
import '../../models/marketplace_item.dart';
import '../crypto/crypto_service.dart';
import '../storage/database_service.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';

/// ==================== EXPANSÃO: ECONOMIA SIMBÓLICA AVANÇADA ====================
/// Serviço expandido de carteira com suporte a:
/// - Múltiplos tipos de moedas
/// - Transações encadeadas (A → B → C)
/// - Marketplace offline
/// - Histórico detalhado
///
/// ADICIONADO: Fase 4 - Expansão da economia simbólica
/// Este módulo EXPANDE o wallet_service.dart existente, não o substitui
class AdvancedWalletService extends ChangeNotifier {
  static final AdvancedWalletService _instance = AdvancedWalletService._internal();
  factory AdvancedWalletService() => _instance;
  AdvancedWalletService._internal();

  final DatabaseService _db = DatabaseService();
  final CryptoService _crypto = CryptoService();

  /// Cache de saldos por tipo de moeda
  final Map<String, Map<String, double>> _balanceCache = {};

  /// Tipos de moeda disponíveis
  final Map<String, CoinType> _coinTypes = {};

  // ==================== GERENCIAMENTO DE TIPOS DE MOEDA ====================

  /// Inicializa tipos de moeda padrão
  Future<void> initializeDefaultCoinTypes() async {
    try {
      await addCoinType(CoinType.helpCredits);
      await addCoinType(CoinType.serviceCoins);
      await addCoinType(CoinType.knowledgePoints);
      await addCoinType(CoinType.gratitudeTokens);
      
      logger.info('Tipos de moeda padrão inicializados', tag: 'AdvancedWallet');
    } catch (e) {
      logger.info('Erro ao inicializar tipos de moeda: $e', tag: 'AdvancedWallet');
    }
  }

  /// Adiciona um novo tipo de moeda
  Future<void> addCoinType(CoinType coinType) async {
    try {
      await _db.insertCoinType(coinType);
      _coinTypes[coinType.coinTypeId] = coinType;
      notifyListeners();
      
      logger.info('Tipo de moeda adicionado: ${coinType.name}', tag: 'AdvancedWallet');
    } catch (e) {
      logger.info('Erro ao adicionar tipo de moeda: $e', tag: 'AdvancedWallet');
      rethrow;
    }
  }

  /// Obtém todos os tipos de moeda
  Future<List<CoinType>> getAllCoinTypes() async {
    try {
      final types = await _db.getAllCoinTypes();
      for (final type in types) {
        _coinTypes[type.coinTypeId] = type;
      }
      return types;
    } catch (e) {
      logger.info('Erro ao obter tipos de moeda: $e', tag: 'AdvancedWallet');
      return [];
    }
  }

  /// Obtém um tipo de moeda específico
  CoinType? getCoinType(String coinTypeId) {
    return _coinTypes[coinTypeId];
  }

  // ==================== SALDOS POR TIPO DE MOEDA ====================

  /// Calcula saldo de um usuário para um tipo específico de moeda
  Future<double> getUserBalanceByType(String userId, String coinTypeId) async {
    try {
      // Verifica cache
      if (_balanceCache.containsKey(userId) && 
          _balanceCache[userId]!.containsKey(coinTypeId)) {
        return _balanceCache[userId]![coinTypeId]!;
      }

      // Calcula saldo do banco
      final balance = await _db.getUserBalanceByType(userId, coinTypeId);

      // Atualiza cache
      if (!_balanceCache.containsKey(userId)) {
        _balanceCache[userId] = {};
      }
      _balanceCache[userId]![coinTypeId] = balance;

      return balance;
    } catch (e) {
      logger.info('Erro ao calcular saldo por tipo: $e', tag: 'AdvancedWallet');
      return 0.0;
    }
  }

  /// Obtém todos os saldos de um usuário (todos os tipos)
  Future<Map<String, double>> getAllBalances(String userId) async {
    try {
      final balances = <String, double>{};
      final types = await getAllCoinTypes();

      for (final type in types) {
        final balance = await getUserBalanceByType(userId, type.coinTypeId);
        balances[type.coinTypeId] = balance;
      }

      return balances;
    } catch (e) {
      logger.info('Erro ao obter todos os saldos: $e', tag: 'AdvancedWallet');
      return {};
    }
  }

  // ==================== TRANSAÇÕES ENCADEADAS ====================

  /// Cria uma transação encadeada (A → B → C)
  Future<List<String>> createChainedTransaction({
    required List<String> userIds,
    required List<double> amounts,
    required String coinTypeId,
    required String privateKey,
  }) async {
    try {
      if (userIds.length < 2) {
        throw Exception('Transação encadeada requer pelo menos 2 usuários');
      }

      if (userIds.length != amounts.length + 1) {
        throw Exception('Número de valores deve ser igual ao número de usuários - 1');
      }

      final transactionIds = <String>[];
      String? previousTxId;

      // Cria cada transação da cadeia
      for (int i = 0; i < amounts.length; i++) {
        final senderId = userIds[i];
        final receiverId = userIds[i + 1];
        final amount = amounts[i];

        final txId = _crypto.generateUniqueId();
        final timestamp = DateTime.now();

        // Dados para assinatura
        final dataToSign = '$txId$senderId$receiverId$amount${timestamp.toIso8601String()}';
        final signature = await _crypto.signData(dataToSign, privateKey);

        // Cria transação
        final transaction = CoinTransaction(
          transactionId: txId,
          senderId: senderId,
          receiverId: receiverId,
          amount: amount,
          timestamp: timestamp,
          status: 'pending',
          signatureSender: signature,
          coinTypeId: coinTypeId,
          previousTransactionId: previousTxId,
        );

        await _db.insertTransaction(transaction);
        transactionIds.add(txId);

        // Atualiza a transação anterior com o nextTransactionId
        if (previousTxId != null) {
          await _db.updateTransactionChain(previousTxId, txId);
        }

        previousTxId = txId;
      }

      logger.info('Transação encadeada criada: ${transactionIds.length} transações', tag: 'AdvancedWallet');
      notifyListeners();
      
      return transactionIds;
    } catch (e) {
      logger.info('Erro ao criar transação encadeada: $e', tag: 'AdvancedWallet');
      rethrow;
    }
  }

  /// Obtém toda a cadeia de transações a partir de uma transação
  Future<List<CoinTransaction>> getTransactionChain(String transactionId) async {
    try {
      final chain = <CoinTransaction>[];
      
      // Obtém a transação inicial
      final transaction = await _db.getTransaction(transactionId);
      if (transaction == null) return chain;

      // Navega para o início da cadeia
      CoinTransaction? current = transaction;
      while (current?.previousTransactionId != null) {
        current = await _db.getTransaction(current!.previousTransactionId!);
        if (current == null) break;
      }

      // Adiciona todas as transações da cadeia
      if (current != null) {
        chain.add(current);
        
        while (current?.nextTransactionId != null) {
          current = await _db.getTransaction(current!.nextTransactionId!);
          if (current == null) break;
          chain.add(current);
        }
      }

      return chain;
    } catch (e) {
      logger.info('Erro ao obter cadeia de transações: $e', tag: 'AdvancedWallet');
      return [];
    }
  }

  /// Valida uma cadeia de transações
  Future<bool> validateTransactionChain(String transactionId) async {
    try {
      final chain = await getTransactionChain(transactionId);
      
      if (chain.isEmpty) return false;

      // Verifica integridade da cadeia
      for (int i = 0; i < chain.length - 1; i++) {
        if (chain[i].nextTransactionId != chain[i + 1].transactionId) {
          return false;
        }
        if (chain[i + 1].previousTransactionId != chain[i].transactionId) {
          return false;
        }
      }

      return true;
    } catch (e) {
      logger.info('Erro ao validar cadeia: $e', tag: 'AdvancedWallet');
      return false;
    }
  }

  // ==================== MARKETPLACE ====================

  /// Cria um novo item no marketplace
  Future<String> createMarketplaceItem({
    required String sellerId,
    required String title,
    required String description,
    required String category,
    required double price,
    required String coinTypeId,
    required List<String> tags,
    String? imageData,
  }) async {
    try {
      final itemId = _crypto.generateUniqueId();
      final now = DateTime.now();

      final item = MarketplaceItem(
        itemId: itemId,
        sellerId: sellerId,
        title: title,
        description: description,
        category: category,
        price: price,
        coinTypeId: coinTypeId,
        status: 'available',
        createdAt: now,
        updatedAt: now,
        tags: tags,
        imageData: imageData,
      );

      await _db.insertMarketplaceItem(item);
      
      logger.info('Item criado no marketplace: $title', tag: 'AdvancedWallet');
      notifyListeners();
      
      return itemId;
    } catch (e) {
      logger.info('Erro ao criar item no marketplace: $e', tag: 'AdvancedWallet');
      rethrow;
    }
  }

  /// Busca itens no marketplace
  Future<List<MarketplaceItem>> searchMarketplace({
    String? category,
    String? coinTypeId,
    String? searchQuery,
    double? maxPrice,
  }) async {
    try {
      return await _db.searchMarketplaceItems(
        category: category,
        coinTypeId: coinTypeId,
        searchQuery: searchQuery,
        maxPrice: maxPrice,
      );
    } catch (e) {
      logger.info('Erro ao buscar no marketplace: $e', tag: 'AdvancedWallet');
      return [];
    }
  }

  /// Compra um item do marketplace
  Future<String> purchaseMarketplaceItem({
    required String itemId,
    required String buyerId,
    required String privateKey,
  }) async {
    try {
      // Obtém o item
      final item = await _db.getMarketplaceItem(itemId);
      if (item == null) {
        throw Exception('Item não encontrado');
      }

      if (item.status != 'available') {
        throw Exception('Item não está disponível');
      }

      // Verifica saldo do comprador
      final balance = await getUserBalanceByType(buyerId, item.coinTypeId);
      if (balance < item.price) {
        throw Exception('Saldo insuficiente');
      }

      // Cria transação de pagamento
      final txId = _crypto.generateUniqueId();
      final timestamp = DateTime.now();
      final dataToSign = '$txId$buyerId${item.sellerId}${item.price}${timestamp.toIso8601String()}';
      final signature = await _crypto.signData(dataToSign, privateKey);

      final transaction = CoinTransaction(
        transactionId: txId,
        senderId: buyerId,
        receiverId: item.sellerId,
        amount: item.price,
        timestamp: timestamp,
        status: 'pending',
        signatureSender: signature,
        coinTypeId: item.coinTypeId,
      );

      await _db.insertTransaction(transaction);

      // Atualiza status do item
      await _db.updateMarketplaceItemStatus(itemId, 'sold', buyerId);

      // Limpa cache
      _balanceCache.remove(buyerId);

      logger.info('Item comprado: ${item.title}', tag: 'AdvancedWallet');
      notifyListeners();
      
      return txId;
    } catch (e) {
      logger.info('Erro ao comprar item: $e', tag: 'AdvancedWallet');
      rethrow;
    }
  }

  /// Obtém itens vendidos por um usuário
  Future<List<MarketplaceItem>> getUserMarketplaceItems(String userId) async {
    try {
      return await _db.getMarketplaceItemsBySeller(userId);
    } catch (e) {
      logger.info('Erro ao obter itens do usuário: $e', tag: 'AdvancedWallet');
      return [];
    }
  }

  // ==================== HISTÓRICO DETALHADO ====================

  /// Obtém histórico detalhado de transações com filtros
  Future<List<CoinTransaction>> getDetailedTransactionHistory({
    required String userId,
    String? coinTypeId,
    DateTime? startDate,
    DateTime? endDate,
    String? status,
  }) async {
    try {
      return await _db.getFilteredTransactions(
        userId: userId,
        coinTypeId: coinTypeId,
        startDate: startDate,
        endDate: endDate,
        status: status,
      );
    } catch (e) {
      logger.info('Erro ao obter histórico detalhado: $e', tag: 'AdvancedWallet');
      return [];
    }
  }

  /// Obtém estatísticas de transações
  Future<Map<String, dynamic>> getTransactionStats(String userId) async {
    try {
      final transactions = await _db.getUserTransactions(userId);
      
      final stats = <String, dynamic>{
        'total': transactions.length,
        'sent': 0,
        'received': 0,
        'pending': 0,
        'accepted': 0,
        'rejected': 0,
        'byType': <String, int>{},
        'totalAmountSent': 0.0,
        'totalAmountReceived': 0.0,
      };

      for (final tx in transactions) {
        if (tx.senderId == userId) {
          stats['sent']++;
          stats['totalAmountSent'] += tx.amount;
        }
        if (tx.receiverId == userId) {
          stats['received']++;
          stats['totalAmountReceived'] += tx.amount;
        }
        
        if (tx.status == 'pending') stats['pending']++;
        if (tx.status == 'accepted') stats['accepted']++;
        if (tx.status == 'rejected') stats['rejected']++;
        
        stats['byType'][tx.coinTypeId] = (stats['byType'][tx.coinTypeId] ?? 0) + 1;
      }

      return stats;
    } catch (e) {
      logger.info('Erro ao obter estatísticas: $e', tag: 'AdvancedWallet');
      return {};
    }
  }

  // ==================== LIMPEZA ====================

  /// Limpa cache de saldos
  void clearBalanceCache() {
    _balanceCache.clear();
    notifyListeners();
  }

  /// Limpa cache de um usuário específico
  void clearUserCache(String userId) {
    _balanceCache.remove(userId);
    notifyListeners();
  }
}
