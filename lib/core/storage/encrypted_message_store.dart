import 'dart:async';
import 'dart:convert';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import '../utils/logger_service.dart';
import '../identity/device_identity_service.dart';
import '../crypto/crypto_manager.dart';
import 'dart:io';

/// Armazenamento Criptografado de Mensagens
/// 
/// Implementa persistência de mensagens mesh usando SQLite com SQLCipher.
/// TODAS as mensagens são criptografadas em disco usando AES-256.
/// 
/// CARACTERÍSTICAS CRÍTICAS:
/// - SQLite criptografado com SQLCipher (AES-256)
/// - Senha derivada do peerId do dispositivo
/// - Índices para busca rápida
/// - Auto-limpeza de mensagens antigas
/// - Suporte a Wipe completo
class EncryptedMessageStore {
  static final EncryptedMessageStore _instance = EncryptedMessageStore._internal();
  factory EncryptedMessageStore() => _instance;
  EncryptedMessageStore._internal();

  Database? _database;
  final DeviceIdentityService _identity = DeviceIdentityService();
  final CryptoManager _crypto = CryptoManager();
  
  // Configurações
  static const String _DB_NAME = 'speew_messages.db';
  static const int _DB_VERSION = 1;
  static const int _MAX_MESSAGES = 10000; // Limite de mensagens armazenadas
  static const int _RETENTION_DAYS = 30; // Retenção de 30 dias

  /// Inicializa o banco de dados criptografado
  Future<void> initialize() async {
    try {
      if (_database != null) {
        logger.warn('Banco de dados já inicializado', tag: 'Storage');
        return;
      }

      // Obter diretório de documentos
      final documentsDirectory = await getApplicationDocumentsDirectory();
      final path = join(documentsDirectory.path, _DB_NAME);

      // Derivar senha do peerId (garantir unicidade por dispositivo)
      final password = _derivePassword();

      // 2. Checagem de Integridade e Auto-Reparo (Lógica de Contingência)
      if (await databaseExists(path)) {
        final integrityCheck = await _runIntegrityCheck(path, password);
        if (!integrityCheck) {
          logger.error('Banco de dados corrompido detectado. Iniciando Auto-Reparo.', tag: 'Storage');
          await _repairCorruptedDatabase(path);
        }
      }

      // 3. Abrir o banco de dados (novo ou reparado)
      _database = await openDatabase(
        path,
        version: _DB_VERSION,
        password: password,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      );

      logger.info('SQLite criptografado inicializado: $path', tag: 'Storage');
      
      // Executar limpeza automática de mensagens antigas
      await _autoCleanup();
    } catch (e) {
      logger.error('Falha ao inicializar banco de dados', tag: 'Storage', error: e);
      throw Exception('Inicialização do storage falhou: $e');
    }
  }

  /// Roda o PRAGMA integrity_check
  Future<bool> _runIntegrityCheck(String dbPath, String key) async {
    Database? tempDb;
    try {
      // Abrir o banco de dados temporariamente para checagem
      tempDb = await openDatabase(dbPath, password: key, readOnly: true);
      final result = await tempDb.rawQuery('PRAGMA integrity_check');
      
      // O resultado deve ser uma lista com um mapa contendo {'integrity_check': 'ok'}
      return result.isNotEmpty && result.first.values.first == 'ok';
    } catch (e) {
      logger.error('Falha ao rodar integrity_check. Assumindo corrupção.', tag: 'Storage', error: e);
      return false;
    } finally {
      if (tempDb != null) {
        await tempDb.close();
      }
    }
  }

  /// Renomeia o arquivo corrompido para .bak e cria um novo
  Future<void> _repairCorruptedDatabase(String dbPath) async {
    try {
      final corruptedFile = File(dbPath);
      final backupPath = '$dbPath.bak';
      
      if (await corruptedFile.exists()) {
        // Renomear o arquivo corrompido
        await corruptedFile.rename(backupPath);
        logger.warn('Banco de dados corrompido movido para quarentena: $backupPath', tag: 'Storage');
      }
    } catch (e) {
      logger.error('Falha ao renomear banco de dados corrompido.', tag: 'Storage', error: e);
      // Não lançar exceção, o openDatabase criará um novo
    }
  }

  /// Deriva senha do banco de dados a partir do peerId
  String _derivePassword() {
    // Usar peerId + salt para derivar senha forte
    final salt = 'speew_alpha1_sqlcipher_salt';
    final combined = '${_identity.peerId}:$salt';
    return _crypto.hash(combined);
  }

  /// Cria tabelas no primeiro boot
  Future<void> _onCreate(Database db, int version) async {
    // Tabela de mensagens
    await db.execute('''
      CREATE TABLE messages (
        id TEXT PRIMARY KEY,
        content TEXT NOT NULL,
        sender_id TEXT NOT NULL,
        receiver_id TEXT,
        ttl INTEGER NOT NULL,
        origin_node_id TEXT NOT NULL,
        visited_nodes TEXT NOT NULL,
        metadata TEXT,
        timestamp INTEGER NOT NULL,
        status TEXT NOT NULL,
        created_at INTEGER NOT NULL
      )
    ''');

    // Índices para busca rápida
    await db.execute('CREATE INDEX idx_timestamp ON messages(timestamp)');
    await db.execute('CREATE INDEX idx_sender ON messages(sender_id)');
    await db.execute('CREATE INDEX idx_status ON messages(status)');
    await db.execute('CREATE INDEX idx_created_at ON messages(created_at)');

    // Tabela de peers conhecidos
    await db.execute('''
      CREATE TABLE known_peers (
        peer_id TEXT PRIMARY KEY,
        display_name TEXT,
        public_key TEXT,
        last_seen INTEGER NOT NULL,
        reputation_score REAL DEFAULT 0.0,
        total_messages INTEGER DEFAULT 0,
        created_at INTEGER NOT NULL
      )
    ''');

	    await db.execute('CREATE INDEX idx_last_seen ON known_peers(last_seen)');

	    // Tabela do DLT Mesh Ledger
	    await db.execute('''
	      CREATE TABLE ledger (
	        index_id INTEGER PRIMARY KEY,
	        block_data TEXT NOT NULL
	      )
	    ''');
	
	    logger.info('Tabelas criadas com sucesso', tag: 'Storage');
	  }

  /// Atualiza esquema do banco de dados
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    logger.info('Atualizando banco de dados de v$oldVersion para v$newVersion', tag: 'Storage');
    // Implementar migrações aqui se necessário
  }

  // ==================== OPERAÇÕES DE MENSAGENS ====================

  /// Salva uma mensagem no banco de dados
  Future<void> saveMessage(MeshMessageRecord message) async {
    if (_database == null) {
      throw Exception('Banco de dados não inicializado');
    }

    try {
      await _database!.insert(
        'messages',
        message.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      logger.debug('Mensagem salva: ${message.id}', tag: 'Storage');

      // Verificar limite de mensagens
      await _enforceMessageLimit();
    } catch (e) {
      logger.error('Erro ao salvar mensagem', tag: 'Storage', error: e);
      throw Exception('Falha ao salvar mensagem: $e');
    }
  }

  /// Busca mensagens por critérios
  Future<List<MeshMessageRecord>> getMessages({
    String? senderId,
    String? receiverId,
    String? status,
    int? limit,
    int? offset,
  }) async {
    if (_database == null) {
      throw Exception('Banco de dados não inicializado');
    }

    try {
      String where = '';
      List<dynamic> whereArgs = [];

      if (senderId != null) {
        where += 'sender_id = ?';
        whereArgs.add(senderId);
      }

      if (receiverId != null) {
        if (where.isNotEmpty) where += ' AND ';
        where += 'receiver_id = ?';
        whereArgs.add(receiverId);
      }

      if (status != null) {
        if (where.isNotEmpty) where += ' AND ';
        where += 'status = ?';
        whereArgs.add(status);
      }

      final List<Map<String, dynamic>> maps = await _database!.query(
        'messages',
        where: where.isEmpty ? null : where,
        whereArgs: whereArgs.isEmpty ? null : whereArgs,
        orderBy: 'timestamp DESC',
        limit: limit,
        offset: offset,
      );

      return maps.map((map) => MeshMessageRecord.fromMap(map)).toList();
    } catch (e) {
      logger.error('Erro ao buscar mensagens', tag: 'Storage', error: e);
      return [];
    }
  }

  /// Busca mensagem por ID
  Future<MeshMessageRecord?> getMessageById(String id) async {
    if (_database == null) {
      throw Exception('Banco de dados não inicializado');
    }

    try {
      final List<Map<String, dynamic>> maps = await _database!.query(
        'messages',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );

      if (maps.isEmpty) return null;
      return MeshMessageRecord.fromMap(maps.first);
    } catch (e) {
      logger.error('Erro ao buscar mensagem por ID', tag: 'Storage', error: e);
      return null;
    }
  }

  /// Atualiza status de uma mensagem
  Future<void> updateMessageStatus(String id, String status) async {
    if (_database == null) {
      throw Exception('Banco de dados não inicializado');
    }

    try {
      await _database!.update(
        'messages',
        {'status': status},
        where: 'id = ?',
        whereArgs: [id],
      );

      logger.debug('Status da mensagem atualizado: $id -> $status', tag: 'Storage');
    } catch (e) {
      logger.error('Erro ao atualizar status da mensagem', tag: 'Storage', error: e);
    }
  }

	  /// Deleta mensagem por ID
	  Future<void> deleteMessage(String id) async {
	    if (_database == null) {
	      throw Exception('Banco de dados não inicializado');
	    }
	
	    try {
	      await _database!.delete(
	        'messages',
	        where: 'id = ?',
	        whereArgs: [id],
	      );
	
	      logger.debug('Mensagem deletada: $id', tag: 'Storage');
	    } catch (e) {
	      logger.error('Erro ao deletar mensagem', tag: 'Storage', error: e);
	    }
	  }
	
	  // ==================== OPERAÇÕES DE LEDGER (DLT) ====================
	
	  /// Salva a cadeia de blocos do Ledger no storage.
	  Future<void> saveLedger(List<Map<String, dynamic>> ledgerJson) async {
	    if (_database == null) {
	      throw Exception('Banco de dados não inicializado');
	    }
	
	    await _database!.transaction((txn) async {
	      // Limpa a tabela antes de inserir a nova cadeia (Anti-Entropy)
	      await txn.delete('ledger');
	
	      for (var blockJson in ledgerJson) {
	        await txn.insert(
	          'ledger',
	          {
	            'index_id': blockJson['index'],
	            'block_data': jsonEncode(blockJson),
	          },
	          conflictAlgorithm: ConflictAlgorithm.replace,
	        );
	      }
	    });
	    logger.debug('Ledger DLT salvo com ${ledgerJson.length} blocos.', tag: 'Storage');
	  }
	
	  /// Carrega a cadeia de blocos do Ledger do storage.
	  Future<List<Map<String, dynamic>>> loadLedger() async {
	    if (_database == null) {
	      // Se o DB não estiver inicializado, retorna vazio para que o Ledger crie o Gênesis
	      return [];
	    }
	
	    try {
	      final List<Map<String, dynamic>> maps = await _database!.query(
	        'ledger',
	        orderBy: 'index_id ASC',
	      );
	
	      return maps.map((map) => jsonDecode(map['block_data'] as String) as Map<String, dynamic>).toList();
	    } catch (e) {
	      logger.error('Erro ao carregar Ledger DLT', tag: 'Storage', error: e);
	      return [];
	    }
	  }

  // ==================== OPERAÇÕES DE PEERS ====================

  /// Salva informações de um peer
  Future<void> savePeer(KnownPeerRecord peer) async {
    if (_database == null) {
      throw Exception('Banco de dados não inicializado');
    }

    try {
      await _database!.insert(
        'known_peers',
        peer.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      logger.debug('Peer salvo: ${peer.peerId}', tag: 'Storage');
    } catch (e) {
      logger.error('Erro ao salvar peer', tag: 'Storage', error: e);
    }
  }

  /// Busca peer por ID
  Future<KnownPeerRecord?> getPeerById(String peerId) async {
    if (_database == null) {
      throw Exception('Banco de dados não inicializado');
    }

    try {
      final List<Map<String, dynamic>> maps = await _database!.query(
        'known_peers',
        where: 'peer_id = ?',
        whereArgs: [peerId],
        limit: 1,
      );

      if (maps.isEmpty) return null;
      return KnownPeerRecord.fromMap(maps.first);
    } catch (e) {
      logger.error('Erro ao buscar peer', tag: 'Storage', error: e);
      return null;
    }
  }

  /// Lista todos os peers conhecidos
  Future<List<KnownPeerRecord>> getAllPeers() async {
    if (_database == null) {
      throw Exception('Banco de dados não inicializado');
    }

    try {
      final List<Map<String, dynamic>> maps = await _database!.query(
        'known_peers',
        orderBy: 'last_seen DESC',
      );

      return maps.map((map) => KnownPeerRecord.fromMap(map)).toList();
    } catch (e) {
      logger.error('Erro ao listar peers', tag: 'Storage', error: e);
      return [];
    }
  }

  // ==================== LIMPEZA E MANUTENÇÃO ====================

  /// Limpeza automática de mensagens antigas
  Future<void> _autoCleanup() async {
    if (_database == null) return;

    try {
      final cutoffTime = DateTime.now()
          .subtract(Duration(days: _RETENTION_DAYS))
          .millisecondsSinceEpoch;

      final deleted = await _database!.delete(
        'messages',
        where: 'created_at < ?',
        whereArgs: [cutoffTime],
      );

      if (deleted > 0) {
        logger.info('Auto-cleanup: $deleted mensagens antigas removidas', tag: 'Storage');
      }
    } catch (e) {
      logger.error('Erro no auto-cleanup', tag: 'Storage', error: e);
    }
  }

  /// Garante que não excedemos o limite de mensagens
  Future<void> _enforceMessageLimit() async {
    if (_database == null) return;

    try {
      final count = Sqflite.firstIntValue(
        await _database!.rawQuery('SELECT COUNT(*) FROM messages'),
      );

      if (count != null && count > _MAX_MESSAGES) {
        // Deletar mensagens mais antigas
        final toDelete = count - _MAX_MESSAGES;
        await _database!.rawDelete('''
          DELETE FROM messages 
          WHERE id IN (
            SELECT id FROM messages 
            ORDER BY created_at ASC 
            LIMIT ?
          )
        ''', [toDelete]);

        logger.info('Limite de mensagens excedido: $toDelete mensagens removidas', tag: 'Storage');
      }
    } catch (e) {
      logger.error('Erro ao aplicar limite de mensagens', tag: 'Storage', error: e);
    }
  }

  // ==================== WIPE COMPLETO ====================

  /// WIPE: Apaga TODOS os dados do banco de dados
  /// Função crítica para software de missão crítica
  Future<void> wipeAllData() async {
    if (_database == null) {
      throw Exception('Banco de dados não inicializado');
    }

    try {
      logger.warn('WIPE INICIADO: Apagando todos os dados...', tag: 'Storage');

      // Deletar todas as mensagens
      await _database!.delete('messages');
      
      // Deletar todos os peers
      await _database!.delete('known_peers');

      // Executar VACUUM para liberar espaço
      await _database!.execute('VACUUM');

      logger.warn('WIPE CONCLUÍDO: Todos os dados foram apagados', tag: 'Storage');
    } catch (e) {
      logger.error('Erro ao executar WIPE', tag: 'Storage', error: e);
      throw Exception('Falha ao executar WIPE: $e');
    }
  }

  /// WIPE NUCLEAR: Apaga o banco de dados do disco
  Future<void> wipeDatabase() async {
    try {
      logger.warn('WIPE NUCLEAR INICIADO: Deletando banco de dados do disco...', tag: 'Storage');

      // Fechar banco de dados
      if (_database != null) {
        await _database!.close();
        _database = null;
      }

      // Obter caminho do banco
      final documentsDirectory = await getApplicationDocumentsDirectory();
      final path = join(documentsDirectory.path, _DB_NAME);

      // Deletar arquivo do disco
      final dbFile = await databaseFactory.getDatabasesPath();
      await databaseFactory.deleteDatabase(path);

      logger.warn('WIPE NUCLEAR CONCLUÍDO: Banco de dados deletado do disco', tag: 'Storage');
    } catch (e) {
      logger.error('Erro ao executar WIPE NUCLEAR', tag: 'Storage', error: e);
      throw Exception('Falha ao executar WIPE NUCLEAR: $e');
    }
  }

  // ==================== ESTATÍSTICAS ====================

  /// Retorna estatísticas do banco de dados
  Future<Map<String, dynamic>> getStats() async {
    if (_database == null) {
      return {'initialized': false};
    }

    try {
      final messageCount = Sqflite.firstIntValue(
        await _database!.rawQuery('SELECT COUNT(*) FROM messages'),
      );

      final peerCount = Sqflite.firstIntValue(
        await _database!.rawQuery('SELECT COUNT(*) FROM known_peers'),
      );

      final oldestMessage = await _database!.query(
        'messages',
        orderBy: 'created_at ASC',
        limit: 1,
      );

      final newestMessage = await _database!.query(
        'messages',
        orderBy: 'created_at DESC',
        limit: 1,
      );

      return {
        'initialized': true,
        'messageCount': messageCount ?? 0,
        'peerCount': peerCount ?? 0,
        'oldestMessageTime': oldestMessage.isNotEmpty 
            ? oldestMessage.first['created_at'] 
            : null,
        'newestMessageTime': newestMessage.isNotEmpty 
            ? newestMessage.first['created_at'] 
            : null,
        'maxMessages': _MAX_MESSAGES,
        'retentionDays': _RETENTION_DAYS,
      };
    } catch (e) {
      logger.error('Erro ao obter estatísticas', tag: 'Storage', error: e);
      return {'error': e.toString()};
    }
  }

  /// Fecha o banco de dados
  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
      logger.info('Banco de dados fechado', tag: 'Storage');
    }
  }
}

// ==================== MODELOS DE DADOS ====================

/// Registro de mensagem mesh
class MeshMessageRecord {
  final String id;
  final String content;
  final String senderId;
  final String? receiverId;
  final int ttl;
  final String originNodeId;
  final List<String> visitedNodes;
  final Map<String, dynamic> metadata;
  final int timestamp;
  final String status; // 'pending', 'sent', 'delivered', 'failed'
  final int createdAt;

  MeshMessageRecord({
    required this.id,
    required this.content,
    required this.senderId,
    this.receiverId,
    required this.ttl,
    required this.originNodeId,
    required this.visitedNodes,
    required this.metadata,
    required this.timestamp,
    required this.status,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'content': content,
      'sender_id': senderId,
      'receiver_id': receiverId,
      'ttl': ttl,
      'origin_node_id': originNodeId,
      'visited_nodes': jsonEncode(visitedNodes),
      'metadata': jsonEncode(metadata),
      'timestamp': timestamp,
      'status': status,
      'created_at': createdAt,
    };
  }

  factory MeshMessageRecord.fromMap(Map<String, dynamic> map) {
    return MeshMessageRecord(
      id: map['id'] as String,
      content: map['content'] as String,
      senderId: map['sender_id'] as String,
      receiverId: map['receiver_id'] as String?,
      ttl: map['ttl'] as int,
      originNodeId: map['origin_node_id'] as String,
      visitedNodes: List<String>.from(jsonDecode(map['visited_nodes'] as String)),
      metadata: Map<String, dynamic>.from(jsonDecode(map['metadata'] as String)),
      timestamp: map['timestamp'] as int,
      status: map['status'] as String,
      createdAt: map['created_at'] as int,
    );
  }
}

/// Registro de peer conhecido
class KnownPeerRecord {
  final String peerId;
  final String? displayName;
  final String? publicKey;
  final int lastSeen;
  final double reputationScore;
  final int totalMessages;
  final int createdAt;

  KnownPeerRecord({
    required this.peerId,
    this.displayName,
    this.publicKey,
    required this.lastSeen,
    this.reputationScore = 0.0,
    this.totalMessages = 0,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'peer_id': peerId,
      'display_name': displayName,
      'public_key': publicKey,
      'last_seen': lastSeen,
      'reputation_score': reputationScore,
      'total_messages': totalMessages,
      'created_at': createdAt,
    };
  }

  factory KnownPeerRecord.fromMap(Map<String, dynamic> map) {
    return KnownPeerRecord(
      peerId: map['peer_id'] as String,
      displayName: map['display_name'] as String?,
      publicKey: map['public_key'] as String?,
      lastSeen: map['last_seen'] as int,
      reputationScore: (map['reputation_score'] as num?)?.toDouble() ?? 0.0,
      totalMessages: map['total_messages'] as int? ?? 0,
      createdAt: map['created_at'] as int,
    );
  }
}
