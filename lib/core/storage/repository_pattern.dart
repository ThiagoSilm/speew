import '../utils/logger_service.dart';
import '../errors/exceptions.dart';
import 'database_service.dart';

/// Interface base para repositórios
/// 
/// Implementa Repository Pattern para acesso a dados
abstract class Repository<T> {
  /// Busca item por ID
  Future<T?> findById(String id);

  /// Busca todos os itens
  Future<List<T>> findAll();

  /// Salva ou atualiza item
  Future<void> save(T item);

  /// Deleta item por ID
  Future<void> delete(String id);

  /// Verifica se item existe
  Future<bool> exists(String id);
}

/// Repositório para usuários
class UserRepository implements Repository<dynamic> {
  final DatabaseService _db = DatabaseService();

  @override
  Future<dynamic> findById(String id) async {
    try {
      final users = await _db.getAllUsers();
      return users.firstWhere(
        (user) => user.userId == id,
        orElse: () => throw StorageException('Usuário não encontrado: $id', code: 'USER_NOT_FOUND'),
      );
    } catch (e) {
      logger.error('Erro ao buscar usuário', tag: 'UserRepository', error: e);
      rethrow;
    }
  }

  @override
  Future<List<dynamic>> findAll() async {
    try {
      return await _db.getAllUsers();
    } catch (e) {
      logger.error('Erro ao buscar todos usuários', tag: 'UserRepository', error: e);
      throw StorageException.readFailed('usuários', error: e);
    }
  }

  @override
  Future<void> save(dynamic user) async {
    try {
      await _db.insertUser(user);
      logger.debug('Usuário salvo: ${user.userId}', tag: 'UserRepository');
    } catch (e) {
      logger.error('Erro ao salvar usuário', tag: 'UserRepository', error: e);
      throw StorageException.writeFailed('usuário', error: e);
    }
  }

  @override
  Future<void> delete(String id) async {
    try {
      await _db.deleteUser(id);
      logger.debug('Usuário deletado: $id', tag: 'UserRepository');
    } catch (e) {
      logger.error('Erro ao deletar usuário', tag: 'UserRepository', error: e);
      throw StorageException.writeFailed('usuário', error: e);
    }
  }

  @override
  Future<bool> exists(String id) async {
    try {
      final user = await findById(id);
      return user != null;
    } catch (e) {
      return false;
    }
  }

  /// Busca usuários por reputação mínima
  Future<List<dynamic>> findByMinReputation(double minReputation) async {
    try {
      final users = await findAll();
      return users.where((user) => user.reputationScore >= minReputation).toList();
    } catch (e) {
      logger.error('Erro ao buscar usuários por reputação', tag: 'UserRepository', error: e);
      throw StorageException.readFailed('usuários por reputação', error: e);
    }
  }
}

/// Repositório para mensagens
class MessageRepository implements Repository<dynamic> {
  final DatabaseService _db = DatabaseService();

  @override
  Future<dynamic> findById(String id) async {
    try {
      final messages = await _db.getAllMessages();
      return messages.firstWhere(
        (msg) => msg.messageId == id,
        orElse: () => throw StorageException('Mensagem não encontrada: $id', code: 'MESSAGE_NOT_FOUND'),
      );
    } catch (e) {
      logger.error('Erro ao buscar mensagem', tag: 'MessageRepository', error: e);
      rethrow;
    }
  }

  @override
  Future<List<dynamic>> findAll() async {
    try {
      return await _db.getAllMessages();
    } catch (e) {
      logger.error('Erro ao buscar todas mensagens', tag: 'MessageRepository', error: e);
      throw StorageException.readFailed('mensagens', error: e);
    }
  }

  @override
  Future<void> save(dynamic message) async {
    try {
      await _db.insertMessage(message);
      logger.debug('Mensagem salva: ${message.messageId}', tag: 'MessageRepository');
    } catch (e) {
      logger.error('Erro ao salvar mensagem', tag: 'MessageRepository', error: e);
      throw StorageException.writeFailed('mensagem', error: e);
    }
  }

  @override
  Future<void> delete(String id) async {
    try {
      await _db.deleteMessage(id);
      logger.debug('Mensagem deletada: $id', tag: 'MessageRepository');
    } catch (e) {
      logger.error('Erro ao deletar mensagem', tag: 'MessageRepository', error: e);
      throw StorageException.writeFailed('mensagem', error: e);
    }
  }

  @override
  Future<bool> exists(String id) async {
    try {
      final message = await findById(id);
      return message != null;
    } catch (e) {
      return false;
    }
  }

  /// Busca mensagens entre dois usuários
  Future<List<dynamic>> findBetweenUsers(String userId1, String userId2) async {
    try {
      final messages = await findAll();
      return messages.where((msg) {
        return (msg.senderId == userId1 && msg.receiverId == userId2) ||
               (msg.senderId == userId2 && msg.receiverId == userId1);
      }).toList();
    } catch (e) {
      logger.error('Erro ao buscar mensagens entre usuários', tag: 'MessageRepository', error: e);
      throw StorageException.readFailed('mensagens entre usuários', error: e);
    }
  }

  /// Busca mensagens não lidas de um usuário
  Future<List<dynamic>> findUnreadByUser(String userId) async {
    try {
      final messages = await findAll();
      return messages.where((msg) {
        return msg.receiverId == userId && msg.status != 'read';
      }).toList();
    } catch (e) {
      logger.error('Erro ao buscar mensagens não lidas', tag: 'MessageRepository', error: e);
      throw StorageException.readFailed('mensagens não lidas', error: e);
    }
  }
}

/// Repositório para transações
class TransactionRepository implements Repository<dynamic> {
  final DatabaseService _db = DatabaseService();

  @override
  Future<dynamic> findById(String id) async {
    try {
      final transactions = await _db.getAllTransactions();
      return transactions.firstWhere(
        (tx) => tx.transactionId == id,
        orElse: () => throw StorageException('Transação não encontrada: $id', code: 'TRANSACTION_NOT_FOUND'),
      );
    } catch (e) {
      logger.error('Erro ao buscar transação', tag: 'TransactionRepository', error: e);
      rethrow;
    }
  }

  @override
  Future<List<dynamic>> findAll() async {
    try {
      return await _db.getAllTransactions();
    } catch (e) {
      logger.error('Erro ao buscar todas transações', tag: 'TransactionRepository', error: e);
      throw StorageException.readFailed('transações', error: e);
    }
  }

  @override
  Future<void> save(dynamic transaction) async {
    try {
      await _db.insertTransaction(transaction);
      logger.debug('Transação salva: ${transaction.transactionId}', tag: 'TransactionRepository');
    } catch (e) {
      logger.error('Erro ao salvar transação', tag: 'TransactionRepository', error: e);
      throw StorageException.writeFailed('transação', error: e);
    }
  }

  @override
  Future<void> delete(String id) async {
    try {
      await _db.deleteTransaction(id);
      logger.debug('Transação deletada: $id', tag: 'TransactionRepository');
    } catch (e) {
      logger.error('Erro ao deletar transação', tag: 'TransactionRepository', error: e);
      throw StorageException.writeFailed('transação', error: e);
    }
  }

  @override
  Future<bool> exists(String id) async {
    try {
      final transaction = await findById(id);
      return transaction != null;
    } catch (e) {
      return false;
    }
  }

  /// Busca transações de um usuário
  Future<List<dynamic>> findByUser(String userId) async {
    try {
      final transactions = await findAll();
      return transactions.where((tx) {
        return tx.senderId == userId || tx.receiverId == userId;
      }).toList();
    } catch (e) {
      logger.error('Erro ao buscar transações do usuário', tag: 'TransactionRepository', error: e);
      throw StorageException.readFailed('transações do usuário', error: e);
    }
  }

  /// Busca transações pendentes
  Future<List<dynamic>> findPending() async {
    try {
      final transactions = await findAll();
      return transactions.where((tx) => tx.status == 'pending').toList();
    } catch (e) {
      logger.error('Erro ao buscar transações pendentes', tag: 'TransactionRepository', error: e);
      throw StorageException.readFailed('transações pendentes', error: e);
    }
  }

  /// Calcula saldo de um usuário
  Future<double> calculateBalance(String userId) async {
    try {
      final transactions = await findByUser(userId);
      double balance = 0.0;

      for (final tx in transactions) {
        if (tx.receiverId == userId && tx.status == 'confirmed') {
          balance += tx.amount;
        } else if (tx.senderId == userId && tx.status == 'confirmed') {
          balance -= tx.amount;
        }
      }

      return balance;
    } catch (e) {
      logger.error('Erro ao calcular saldo', tag: 'TransactionRepository', error: e);
      throw StorageException.readFailed('saldo', error: e);
    }
  }
}

/// Factory para criar repositórios
class RepositoryFactory {
  static final RepositoryFactory _instance = RepositoryFactory._internal();
  factory RepositoryFactory() => _instance;
  RepositoryFactory._internal();

  final Map<Type, Repository> _repositories = {};

  /// Obtém repositório de usuários
  UserRepository get users {
    return _repositories.putIfAbsent(
      UserRepository,
      () => UserRepository(),
    ) as UserRepository;
  }

  /// Obtém repositório de mensagens
  MessageRepository get messages {
    return _repositories.putIfAbsent(
      MessageRepository,
      () => MessageRepository(),
    ) as MessageRepository;
  }

  /// Obtém repositório de transações
  TransactionRepository get transactions {
    return _repositories.putIfAbsent(
      TransactionRepository,
      () => TransactionRepository(),
    ) as TransactionRepository;
  }

  /// Limpa cache de repositórios
  void clearCache() {
    _repositories.clear();
    logger.debug('Cache de repositórios limpo', tag: 'RepositoryFactory');
  }
}

/// Instância global da factory
final repositories = RepositoryFactory();
