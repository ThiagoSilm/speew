import '../../core/utils/logger_service.dart';
import '../../models/coin_transaction.dart';
import '../../models/user.dart';
import '../crypto/crypto_service.dart';
import '../network/p2p_service.dart';
import '../storage/database_service.dart';
import 'package:flutter/foundation.dart';

/// Serviço de carteira para moeda simbólica
/// Moeda infinita, voluntária e válida apenas com aceite do destinatário
class WalletService extends ChangeNotifier {
  static final WalletService _instance = WalletService._internal();
  factory WalletService() => _instance;
  WalletService._internal();

  final CryptoService _crypto = CryptoService();
  final DatabaseService _db = DatabaseService();
  final P2PService _p2p = P2PService();

  /// Saldo atual do usuário
  double _balance = 0.0;
  double get balance => _balance;

  /// Transações pendentes de aceite
  final List<CoinTransaction> _pendingTransactions = [];
  List<CoinTransaction> get pendingTransactions => List.unmodifiable(_pendingTransactions);

  /// Histórico de transações
  final List<CoinTransaction> _transactionHistory = [];
  List<CoinTransaction> get transactionHistory => List.unmodifiable(_transactionHistory);

  // ==================== INICIALIZAÇÃO ====================

  /// Inicializa a carteira para um usuário
  Future<void> initialize(String userId) async {
    try {
      // Carregar saldo
      _balance = await _db.getUserBalance(userId);

      // Carregar transações pendentes
      final pending = await _db.getPendingTransactions(userId);
      _pendingTransactions.clear();
      _pendingTransactions.addAll(pending);

      // Carregar histórico
      final history = await _db.getUserTransactions(userId);
      _transactionHistory.clear();
      _transactionHistory.addAll(history);

      notifyListeners();
      logger.info('Carteira inicializada - Saldo: $_balance', tag: 'Wallet');
    } catch (e) {
      logger.info('Erro ao inicializar carteira: $e', tag: 'Wallet');
      throw Exception('Falha ao inicializar carteira: $e');
    }
  }

  // ==================== ENVIO DE MOEDA ====================

  /// Envia moeda para outro usuário
  /// A transação fica pendente até o destinatário aceitar
  Future<CoinTransaction?> sendCoins({
    required String senderId,
    required String receiverId,
    required double amount,
    required String senderPrivateKey,
  }) async {
    try {
      // Validações
      if (amount <= 0) {
        throw Exception('Quantidade inválida: deve ser maior que zero');
      }

      // Verificar se o destinatário existe
      final receiver = await _db.getUser(receiverId);
      if (receiver == null) {
        throw Exception('Destinatário não encontrado');
      }

      // Criar transação
      final transactionId = _crypto.generateUniqueId();
      final timestamp = DateTime.now();

      // Criar dados para assinatura
      final dataToSign = '$transactionId|$senderId|$receiverId|$amount|${timestamp.toIso8601String()}';
      
      // Assinar transação
      final signature = await _crypto.signData(dataToSign, senderPrivateKey);

      // Criar objeto de transação
      final transaction = CoinTransaction(
        transactionId: transactionId,
        senderId: senderId,
        receiverId: receiverId,
        amount: amount,
        timestamp: timestamp,
        status: 'pending',
        signatureSender: signature,
      );

      // Salvar no banco de dados
      await _db.insertTransaction(transaction);

      // Enviar via P2P para o destinatário
      await _sendTransactionToPeer(transaction, receiverId);

      // Atualizar lista de transações
      _transactionHistory.insert(0, transaction);
      notifyListeners();

      logger.info('Moeda enviada: $amount para $receiverId', tag: 'Wallet');
      return transaction;
    } catch (e) {
      logger.info('Erro ao enviar moeda: $e', tag: 'Wallet');
      return null;
    }
  }

  /// Envia transação via P2P
  Future<void> _sendTransactionToPeer(CoinTransaction transaction, String receiverId) async {
    try {
      final message = P2PMessage(
        messageId: _crypto.generateUniqueId(),
        senderId: transaction.senderId,
        receiverId: receiverId,
        type: 'transaction',
        payload: transaction.toMap(),
      );

      // Tentar enviar diretamente
      final sent = await _p2p.sendMessage(receiverId, message);
      
      if (!sent) {
        // Se não conseguir enviar diretamente, usar store-and-forward
        logger.info('Destinatário offline, usando store-and-forward', tag: 'Wallet');
        await _p2p.propagateMessage(message);
      }
    } catch (e) {
      logger.info('Erro ao enviar transação via P2P: $e', tag: 'Wallet');
    }
  }

  // ==================== RECEPÇÃO E ACEITE DE MOEDA ====================

  /// Processa uma transação recebida
  Future<void> receiveTransaction(CoinTransaction transaction) async {
    try {
      // Verificar se a transação já existe
      final existing = _pendingTransactions.any((t) => t.transactionId == transaction.transactionId);
      if (existing) {
        logger.info('Transação já existe: ${transaction.transactionId}', tag: 'Wallet');
        return;
      }

      // Salvar no banco de dados
      await _db.insertTransaction(transaction);

      // Adicionar à lista de pendentes
      _pendingTransactions.add(transaction);
      notifyListeners();

      logger.info('Transação recebida: ${transaction.amount} de ${transaction.senderId}', tag: 'Wallet');
    } catch (e) {
      logger.info('Erro ao receber transação: $e', tag: 'Wallet');
    }
  }

  /// Aceita uma transação pendente
  Future<bool> acceptTransaction({
    required String transactionId,
    required String receiverId,
    required String receiverPrivateKey,
  }) async {
    try {
      // Buscar transação
      final transaction = _pendingTransactions.firstWhere(
        (t) => t.transactionId == transactionId,
        orElse: () => throw Exception('Transação não encontrada'),
      );

      // Verificar se o usuário é o destinatário
      if (transaction.receiverId != receiverId) {
        throw Exception('Você não é o destinatário desta transação');
      }

      // Criar dados para assinatura
      final dataToSign = '$transactionId|accepted|${DateTime.now().toIso8601String()}';
      
      // Assinar aceite
      final signature = await _crypto.signData(dataToSign, receiverPrivateKey);

      // Atualizar transação no banco de dados
      await _db.updateTransactionStatus(transactionId, 'accepted', signature);

      // Atualizar saldo
      _balance += transaction.amount;

      // Remover da lista de pendentes
      _pendingTransactions.removeWhere((t) => t.transactionId == transactionId);

      // Atualizar histórico
      final updatedTransaction = transaction.copyWith(
        status: 'accepted',
        signatureReceiver: signature,
      );
      _transactionHistory.insert(0, updatedTransaction);

      notifyListeners();

      // Notificar o remetente via P2P
      await _notifyTransactionStatus(transaction.senderId, transactionId, 'accepted');

      logger.info('Transação aceita: ${transaction.amount}', tag: 'Wallet');
      return true;
    } catch (e) {
      logger.info('Erro ao aceitar transação: $e', tag: 'Wallet');
      return false;
    }
  }

  /// Rejeita uma transação pendente
  Future<bool> rejectTransaction({
    required String transactionId,
    required String receiverId,
  }) async {
    try {
      // Buscar transação
      final transaction = _pendingTransactions.firstWhere(
        (t) => t.transactionId == transactionId,
        orElse: () => throw Exception('Transação não encontrada'),
      );

      // Verificar se o usuário é o destinatário
      if (transaction.receiverId != receiverId) {
        throw Exception('Você não é o destinatário desta transação');
      }

      // Atualizar transação no banco de dados
      await _db.updateTransactionStatus(transactionId, 'rejected', null);

      // Remover da lista de pendentes
      _pendingTransactions.removeWhere((t) => t.transactionId == transactionId);

      // Atualizar histórico
      final updatedTransaction = transaction.copyWith(status: 'rejected');
      _transactionHistory.insert(0, updatedTransaction);

      notifyListeners();

      // Notificar o remetente via P2P
      await _notifyTransactionStatus(transaction.senderId, transactionId, 'rejected');

      logger.info('Transação rejeitada: ${transaction.transactionId}', tag: 'Wallet');
      return true;
    } catch (e) {
      logger.info('Erro ao rejeitar transação: $e', tag: 'Wallet');
      return false;
    }
  }

  /// Notifica o status de uma transação via P2P
  Future<void> _notifyTransactionStatus(String userId, String transactionId, String status) async {
    try {
      final message = P2PMessage(
        messageId: _crypto.generateUniqueId(),
        senderId: 'system',
        receiverId: userId,
        type: 'transaction_status',
        payload: {
          'transactionId': transactionId,
          'status': status,
        },
      );

      await _p2p.sendMessage(userId, message);
    } catch (e) {
      logger.info('Erro ao notificar status da transação: $e', tag: 'Wallet');
    }
  }

  // ==================== CONSULTAS ====================

  /// Obtém o saldo atualizado
  Future<double> refreshBalance(String userId) async {
    _balance = await _db.getUserBalance(userId);
    notifyListeners();
    return _balance;
  }

  /// Obtém transações com um usuário específico
  Future<List<CoinTransaction>> getTransactionsWithUser(String userId, String otherUserId) async {
    final allTransactions = await _db.getUserTransactions(userId);
    return allTransactions.where((t) => 
      t.senderId == otherUserId || t.receiverId == otherUserId
    ).toList();
  }

  /// Obtém estatísticas da carteira
  Future<Map<String, dynamic>> getWalletStats(String userId) async {
    final transactions = await _db.getUserTransactions(userId);
    
    final sent = transactions.where((t) => t.senderId == userId && t.status == 'accepted');
    final received = transactions.where((t) => t.receiverId == userId && t.status == 'accepted');
    
    final totalSent = sent.fold<double>(0.0, (sum, t) => sum + t.amount);
    final totalReceived = received.fold<double>(0.0, (sum, t) => sum + t.amount);
    
    return {
      'balance': _balance,
      'totalSent': totalSent,
      'totalReceived': totalReceived,
      'transactionCount': transactions.length,
      'pendingCount': _pendingTransactions.length,
    };
  }

  // ==================== SINCRONIZAÇÃO ====================

  /// Sincroniza transações com peers conectados
  Future<void> syncTransactions(String userId) async {
    try {
      // Em produção:
      // 1. Solicitar transações pendentes de peers
      // 2. Enviar confirmações de transações aceitas
      // 3. Resolver conflitos de sincronização
      
      logger.info('Sincronização de transações iniciada', tag: 'Wallet');
    } catch (e) {
      logger.info('Erro ao sincronizar transações: $e', tag: 'Wallet');
    }
  }
}
