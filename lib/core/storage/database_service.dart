import '../../models/coin_transaction.dart';
import '../../models/file_block.dart';
import '../../models/file_model.dart';
import '../../models/message.dart';
import '../../models/user.dart';
import '../reputation/reputation_models.dart'; // Para ReputationScore
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// Serviço de gerenciamento do banco de dados SQLite local
/// Responsável por criar, atualizar e gerenciar todas as tabelas
class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  static Database? _database;

  /// Obtém a instância do banco de dados (singleton)
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  /// Inicializa o banco de dados e cria as tabelas
  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'rede_p2p.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  /// Cria todas as tabelas do banco de dados
  Future<void> _onCreate(Database db, int version) async {
    // Tabela de usuários
    await db.execute('''
      CREATE TABLE users (
        user_id TEXT PRIMARY KEY,
        public_key TEXT NOT NULL,
        display_name TEXT NOT NULL,
        reputation_score REAL NOT NULL DEFAULT 0.0,
        last_seen TEXT NOT NULL
      )
    ''');

    // Tabela de mensagens
    await db.execute('''
      CREATE TABLE messages (
        message_id TEXT PRIMARY KEY,
        sender_id TEXT NOT NULL,
        receiver_id TEXT NOT NULL,
        content_encrypted TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        status TEXT NOT NULL,
        type TEXT NOT NULL,
        FOREIGN KEY (sender_id) REFERENCES users (user_id),
        FOREIGN KEY (receiver_id) REFERENCES users (user_id)
      )
    ''');

    // Tabela de arquivos
    await db.execute('''
      CREATE TABLE files (
        file_id TEXT PRIMARY KEY,
        owner_id TEXT NOT NULL,
        filename TEXT NOT NULL,
        size INTEGER NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (owner_id) REFERENCES users (user_id)
      )
    ''');

    // Tabela de blocos de arquivo
    await db.execute('''
      CREATE TABLE file_blocks (
        block_id TEXT PRIMARY KEY,
        file_id TEXT NOT NULL,
        block_index INTEGER NOT NULL,
        total_blocks INTEGER NOT NULL,
        data_encrypted TEXT NOT NULL,
        checksum TEXT NOT NULL,
        FOREIGN KEY (file_id) REFERENCES files (file_id)
      )
    ''');

    // Tabela de reputação
    await db.execute('''
      CREATE TABLE reputation_scores (
        peer_id TEXT PRIMARY KEY,
        score REAL NOT NULL,
        last_updated TEXT NOT NULL
      )
    ''');

    // Tabela de chaves de dispositivo (Multi-Dispositivo POC)
    await db.execute('''
      CREATE TABLE device_keys (
        device_id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        public_key TEXT NOT NULL,
        last_seen TEXT NOT NULL,
        is_current_device INTEGER NOT NULL
      )
    ''');

    // Tabela de transações de moeda
    await db.execute('''
      CREATE TABLE coin_transactions (
        transaction_id TEXT PRIMARY KEY,
        sender_id TEXT NOT NULL,
        receiver_id TEXT NOT NULL,
        amount REAL NOT NULL,
        timestamp TEXT NOT NULL,
        status TEXT NOT NULL,
        signature_sender TEXT NOT NULL,
        signature_receiver TEXT,
        FOREIGN KEY (sender_id) REFERENCES users (user_id),
        FOREIGN KEY (receiver_id) REFERENCES users (user_id)
      )
    ''');

    // Índices para melhorar performance de consultas
    await db.execute('CREATE INDEX idx_messages_sender ON messages(sender_id)');
    await db.execute('CREATE INDEX idx_messages_receiver ON messages(receiver_id)');
    await db.execute('CREATE INDEX idx_messages_status ON messages(status)');
    await db.execute('CREATE INDEX idx_file_blocks_file ON file_blocks(file_id)');
    await db.execute('CREATE INDEX idx_transactions_sender ON coin_transactions(sender_id)');
    await db.execute('CREATE INDEX idx_transactions_receiver ON coin_transactions(receiver_id)');
    await db.execute('CREATE INDEX idx_reputation_score ON reputation_scores(score)');
    await db.execute('CREATE INDEX idx_transactions_status ON coin_transactions(status)');
  }

  // ==================== OPERAÇÕES DE USUÁRIOS ====================

  /// Insere um novo usuário no banco de dados
  Future<int> insertUser(User user) async {
    final db = await database;
    return await db.insert('users', user.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Obtém um usuário pelo ID
  Future<User?> getUser(String userId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'users',
      where: 'user_id = ?',
      whereArgs: [userId],
    );
    if (maps.isEmpty) return null;
    return User.fromMap(maps.first);
  }

  /// Obtém todos os usuários
  Future<List<User>> getAllUsers() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('users');
    return List.generate(maps.length, (i) => User.fromMap(maps[i]));
  }

  /// Atualiza um usuário
  Future<int> updateUser(User user) async {
    final db = await database;
    return await db.update(
      'users',
      user.toMap(),
      where: 'user_id = ?',
      whereArgs: [user.userId],
    );
  }

  // ==================== OPERAÇÕES DE MENSAGENS ====================

  /// Insere uma nova mensagem
  Future<int> insertMessage(Message message) async {
    final db = await database;
    return await db.insert('messages', message.toMap());
  }

  /// Obtém mensagens entre dois usuários
  Future<List<Message>> getMessagesBetweenUsers(String userId1, String userId2) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'messages',
      where: '(sender_id = ? AND receiver_id = ?) OR (sender_id = ? AND receiver_id = ?)',
      whereArgs: [userId1, userId2, userId2, userId1],
      orderBy: 'timestamp ASC',
    );
    return List.generate(maps.length, (i) => Message.fromMap(maps[i]));
  }

  /// Obtém mensagens pendentes de envio
  Future<List<Message>> getPendingMessages() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'messages',
      where: 'status = ?',
      whereArgs: ['pending'],
    );
    return List.generate(maps.length, (i) => Message.fromMap(maps[i]));
  }

  /// Atualiza o status de uma mensagem
  Future<int> updateMessageStatus(String messageId, String status) async {
    final db = await database;
    return await db.update(
      'messages',
      {'status': status},
      where: 'message_id = ?',
      whereArgs: [messageId],
    );
  }

  // ==================== OPERAÇÕES DE ARQUIVOS ====================

  /// Insere um novo arquivo
  Future<int> insertFile(FileModel file) async {
    final db = await database;
    return await db.insert('files', file.toMap());
  }

  /// Obtém um arquivo pelo ID
  Future<FileModel?> getFile(String fileId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'files',
      where: 'file_id = ?',
      whereArgs: [fileId],
    );
    if (maps.isEmpty) return null;
    return FileModel.fromMap(maps.first);
  }

  // ==================== OPERAÇÕES DE BLOCOS DE ARQUIVO ====================

  /// Insere um bloco de arquivo
  Future<int> insertFileBlock(FileBlock block) async {
    final db = await database;
    return await db.insert('file_blocks', block.toMap());
  }

  /// Obtém todos os blocos de um arquivo
  Future<List<FileBlock>> getFileBlocks(String fileId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'file_blocks',
      where: 'file_id = ?',
      whereArgs: [fileId],
      orderBy: 'block_index ASC',
    );
    return List.generate(maps.length, (i) => FileBlock.fromMap(maps[i]));
  }

  /// Verifica se todos os blocos de um arquivo foram recebidos
  Future<bool> isFileComplete(String fileId) async {
    final blocks = await getFileBlocks(fileId);
    if (blocks.isEmpty) return false;
    final totalBlocks = blocks.first.totalBlocks;
    return blocks.length == totalBlocks;
  }

  // ==================== OPERAÇÕES DE TRANSAÇÕES ====================

  /// Insere uma nova transação de moeda
  Future<int> insertTransaction(CoinTransaction transaction) async {
    final db = await database;
    return await db.insert('coin_transactions', transaction.toMap());
  }

  /// Obtém transações de um usuário
  Future<List<CoinTransaction>> getUserTransactions(String userId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'coin_transactions',
      where: 'sender_id = ? OR receiver_id = ?',
      whereArgs: [userId, userId],
      orderBy: 'timestamp DESC',
    );
    return List.generate(maps.length, (i) => CoinTransaction.fromMap(maps[i]));
  }

  /// Obtém transações pendentes de aceite para um usuário
  Future<List<CoinTransaction>> getPendingTransactions(String userId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'coin_transactions',
      where: 'receiver_id = ? AND status = ?',
      whereArgs: [userId, 'pending'],
    );
    return List.generate(maps.length, (i) => CoinTransaction.fromMap(maps[i]));
  }

  /// Atualiza o status de uma transação
  Future<int> updateTransactionStatus(String transactionId, String status, String? signatureReceiver) async {
    final db = await database;
    return await db.update(
      'coin_transactions',
      {
        'status': status,
        if (signatureReceiver != null) 'signature_receiver': signatureReceiver,
      },
      where: 'transaction_id = ?',
      whereArgs: [transactionId],
    );
  }

  /// Calcula o saldo de moeda de um usuário
  Future<double> getUserBalance(String userId) async {
    final db = await database;
    
    // Soma das moedas recebidas e aceitas
    final received = await db.rawQuery(
      'SELECT SUM(amount) as total FROM coin_transactions WHERE receiver_id = ? AND status = ?',
      [userId, 'accepted'],
    );
    final receivedTotal = (received.first['total'] as double?) ?? 0.0;
    
    // Soma das moedas enviadas e aceitas
    final sent = await db.rawQuery(
      'SELECT SUM(amount) as total FROM coin_transactions WHERE sender_id = ? AND status = ?',
      [userId, 'accepted'],
    );
    final sentTotal = (sent.first['total'] as double?) ?? 0.0;
    
    return receivedTotal - sentTotal;
  }

  // ==================== OPERAÇÕES DE REPUTAÇÃO ====================

  /// Insere ou atualiza um ReputationScore
  Future<int> updateReputationScore(ReputationScore score) async {
    final db = await database;
    return await db.insert('reputation_scores', {
      'peer_id': score.peerId,
      'score': score.score,
      'last_updated': score.lastUpdated.toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Obtém todos os ReputationScores
  Future<List<ReputationScore>> getAllReputationScores() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('reputation_scores');
    return List.generate(maps.length, (i) => ReputationScore(
      peerId: maps[i]['peer_id'] as String,
      score: maps[i]['score'] as double,
      lastUpdated: DateTime.parse(maps[i]['last_updated'] as String),
    ));
  }

  // ==================== STEALTH MODE SUPPORT ====================
  // ADICIONADO: Fase 2 - Suporte ao modo fantasma

  /// Atualiza o conteúdo de uma mensagem (para wipe seguro)
  Future<void> updateMessageContent(String messageId, String newContent) async {
    final db = await database;
    await db.update(
      'messages',
      {'content_encrypted': newContent},
      where: 'message_id = ?',
      whereArgs: [messageId],
    );
  }

  /// Remove uma mensagem do banco
  Future<void> deleteMessage(String messageId) async {
    final db = await database;
    await db.delete(
      'messages',
      where: 'message_id = ?',
      whereArgs: [messageId],
    );
  }

  /// Obtém uma mensagem pelo ID
  Future<Message?> getMessage(String messageId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'messages',
      where: 'message_id = ?',
      whereArgs: [messageId],
    );
    if (maps.isEmpty) return null;
    return Message.fromMap(maps.first);
  }

  /// Fecha o banco de dados
  Future<void> close() async {
    final db = await database;
    await db.close();
  }
}

  // ==================== OPERAÇÕES DE GRUPOS ====================

  /// Insere um novo grupo
  Future<void> insertGroup(dynamic group) async {
    final db = await database;
    
    // Criar tabela de grupos se não existir
    await db.execute('''
      CREATE TABLE IF NOT EXISTS groups (
        group_id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT,
        member_ids TEXT NOT NULL,
        creator_id TEXT NOT NULL,
        created_at TEXT NOT NULL,
        avatar_url TEXT
      )
    ''');
    
    await db.insert(
      'groups',
      {
        'group_id': group.groupId,
        'name': group.name,
        'description': group.description,
        'member_ids': group.memberIds.join(','),
        'creator_id': group.creatorId,
        'created_at': group.createdAt.toIso8601String(),
        'avatar_url': group.avatarUrl,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Atualiza um grupo existente
  Future<void> updateGroup(dynamic group) async {
    final db = await database;
    await db.update(
      'groups',
      {
        'name': group.name,
        'description': group.description,
        'member_ids': group.memberIds.join(','),
        'avatar_url': group.avatarUrl,
      },
      where: 'group_id = ?',
      whereArgs: [group.groupId],
    );
  }

  // ==================== OPERAÇÕES DE DEVICE KEY ====================

  /// Insere ou atualiza uma chave de dispositivo
  Future<void> insertDeviceKey(dynamic deviceKey) async {
    final db = await database;
    
    // Criar tabela se não existir (para evitar erro em versões antigas)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS device_keys (
        device_id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        public_key TEXT NOT NULL,
        last_seen TEXT NOT NULL,
        is_current_device INTEGER NOT NULL
      )
    ''');
    
    await db.insert(
      'device_keys',
      {
        'device_id': deviceKey.deviceId,
        'user_id': deviceKey.userId,
        'public_key': deviceKey.publicKey,
        'last_seen': deviceKey.lastSeen.toIso8601String(),
        'is_current_device': deviceKey.isCurrentDevice ? 1 : 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Obtém todas as chaves de dispositivo para um usuário
  Future<List<dynamic>> getUserDeviceKeys(String userId) async {
    final db = await database;
    
    // Criar tabela se não existir
    await db.execute('''
      CREATE TABLE IF NOT EXISTS device_keys (
        device_id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        public_key TEXT NOT NULL,
        last_seen TEXT NOT NULL,
        is_current_device INTEGER NOT NULL
      )
    ''');
    
    final results = await db.query(
      'device_keys',
      where: 'user_id = ?',
      whereArgs: [userId],
    );

    // Importação dinâmica para evitar dependência circular
    return results.map((map) => {
      'deviceId': map['device_id'],
      'userId': map['user_id'],
      'publicKey': map['public_key'],
      'lastSeen': map['last_seen'],
      'isCurrentDevice': map['is_current_device'] == 1,
    }).toList();
  }

  /// Obtém um grupo pelo ID
  Future<dynamic> getGroup(String groupId) async {
    final db = await database;
    
    // Criar tabela se não existir
    await db.execute('''
      CREATE TABLE IF NOT EXISTS groups (
        group_id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT,
        member_ids TEXT NOT NULL,
        creator_id TEXT NOT NULL,
        created_at TEXT NOT NULL,
        avatar_url TEXT
      )
    ''');
    
    final results = await db.query(
      'groups',
      where: 'group_id = ?',
      whereArgs: [groupId],
    );

    if (results.isEmpty) return null;

    final map = results.first;
    // Importar Group model dinamicamente
    return _mapToGroup(map);
  }

  /// Obtém todos os grupos de um usuário
  Future<List<dynamic>> getUserGroups(String userId) async {
    final db = await database;
    
    // Criar tabela se não existir
    await db.execute('''
      CREATE TABLE IF NOT EXISTS groups (
        group_id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT,
        member_ids TEXT NOT NULL,
        creator_id TEXT NOT NULL,
        created_at TEXT NOT NULL,
        avatar_url TEXT
      )
    ''');
    
    final results = await db.query('groups');

    // Filtrar grupos onde o usuário é membro
    return results
        .where((map) {
          final memberIds = (map['member_ids'] as String).split(',');
          return memberIds.contains(userId);
        })
        .map((map) => _mapToGroup(map))
        .toList();
  }

  /// Converte Map para Group
  dynamic _mapToGroup(Map<String, dynamic> map) {
    // Importação dinâmica para evitar dependência circular
    // Em produção, usar import adequado
    return {
      'groupId': map['group_id'],
      'name': map['name'],
      'description': map['description'] ?? '',
      'memberIds': (map['member_ids'] as String).split(','),
      'creatorId': map['creator_id'],
      'createdAt': map['created_at'],
      'avatarUrl': map['avatar_url'],
    };
  }

  /// Deleta um grupo
  Future<void> deleteGroup(String groupId) async {
    final db = await database;
    await db.delete(
      'groups',
      where: 'group_id = ?',
      whereArgs: [groupId],
    );
  }
