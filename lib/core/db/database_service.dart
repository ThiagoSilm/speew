import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'models/utxo_entry.dart';
import 'models/sequence_entry.dart';
import 'models/peer_entry.dart';
import 'models/mempool_entry.dart';

/// Serviço de Banco de Dados para persistência de estado crítico
/// Usa Sqflite com transações atômicas para garantir ACID
class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, 'speew_ledger.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        // Tabela UTXO (Unspent Transaction Output)
        await db.execute('''
          CREATE TABLE utxo (
            utxoHash TEXT PRIMARY KEY,
            amount INTEGER NOT NULL,
            ownerId TEXT NOT NULL,
            timestamp INTEGER NOT NULL
          )
        ''');
        // Tabela Sequence (para Sequence Check)
        await db.execute('''
          CREATE TABLE sequence (
            peerId TEXT PRIMARY KEY,
            lastSequenceNumber INTEGER NOT NULL,
            lastEntryHash TEXT
          )
        ''');
        // Tabela Mempool (Memory Pool)
        await db.execute('''
          CREATE TABLE mempool (
            entryHash TEXT PRIMARY KEY,
            entryJson TEXT NOT NULL,
            receivedAt INTEGER NOT NULL,
            fee INTEGER NOT NULL
          )
        ''');
        
        // Tabela Peers (para Peer Discovery - Kademlia-lite)
        await db.execute('''
          CREATE TABLE peers (
            peerId TEXT PRIMARY KEY,
            address TEXT NOT NULL,
            port INTEGER NOT NULL,
            lastSeen INTEGER NOT NULL,
            failureCount INTEGER NOT NULL
          )
        ''');
        // Tabela de Ledger da malha (Mesh Ledger)
        await db.execute('''
          CREATE TABLE mesh_ledger (
            block_index INTEGER PRIMARY KEY,
            timestamp TEXT NOT NULL,
            peer_data TEXT NOT NULL,
            prev_hash TEXT NOT NULL,
            signature TEXT NOT NULL,
            emitter_id TEXT NOT NULL,
            hash TEXT NOT NULL
          )
        ''');
      },
    );
  }

  // ==================== UTXO OPERATIONS ====================

  /// Persiste um UTXO (Unspent Transaction Output)
  Future<void> saveUTXO(UTXOEntry entry) async {
    final db = await database;
    await db.insert(
      'utxo',
      entry.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Marca um UTXO como gasto (deleta da tabela)
  Future<void> spendUTXO(String utxoHash) async {
    final db = await database;
    await db.delete(
      'utxo',
      where: 'utxoHash = ?',
      whereArgs: [utxoHash],
    );
  }

  /// Verifica se um UTXO está disponível (existe na tabela)
  Future<bool> isUTXOAvailable(String utxoHash) async {
    final db = await database;
    final result = await db.query(
      'utxo',
      where: 'utxoHash = ?',
      whereArgs: [utxoHash],
      limit: 1,
    );
    return result.isNotEmpty;
  }

  // ==================== SEQUENCE OPERATIONS ====================

  /// Obtém o último SequenceEntry para um peer
  Future<SequenceEntry?> getSequenceEntry(String peerId) async {
    final db = await database;
    final result = await db.query(
      'sequence',
      where: 'peerId = ?',
      whereArgs: [peerId],
      limit: 1,
    );
    if (result.isEmpty) return null;
    return SequenceEntry.fromMap(result.first);
  }

  /// Salva ou atualiza o SequenceEntry para um peer
  Future<void> saveSequenceEntry(SequenceEntry entry) async {
    final db = await database;
    await db.insert(
      'sequence',
      entry.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// ==================== MEMPOOL METHODS ====================

  /// Salva uma entrada na Mempool
  Future<void> saveMempoolEntry(MempoolEntry entry) async {
    final db = await database;
    await db.insert(
      'mempool',
      entry.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Remove uma entrada da Mempool
  Future<void> removeMempoolEntry(String entryHash) async {
    final db = await database;
    await db.delete(
      'mempool',
      where: 'entryHash = ?',
      whereArgs: [entryHash],
    );
  }

  /// Obtém todas as entradas da Mempool, ordenadas por taxa (Fee Ranking)
  Future<List<MempoolEntry>> getMempoolEntries() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'mempool',
      orderBy: 'fee DESC, receivedAt ASC', // Prioriza maior taxa, depois o mais antigo
    );

    return List.generate(maps.length, (i) {
      return MempoolEntry.fromMap(maps[i]);
    });
  }

  /// Obtém entradas da Mempool que tentam gastar um UTXO específico
  Future<List<MempoolEntry>> getMempoolEntriesByInputUTXO(String utxoHash) async {
    final db = await database;
    // Busca entradas onde o JSON da entrada contém o inputUTXOHash
    // Nota: Esta é uma busca ineficiente em JSON, mas é a única forma sem uma tabela auxiliar
    final List<Map<String, dynamic>> maps = await db.query(
      'mempool',
      where: "entryJson LIKE '%\"inputUTXOHash\":\"$utxoHash\"%'",
    );

    return List.generate(maps.length, (i) {
      return MempoolEntry.fromMap(maps[i]);
    });
  }

// ==================== PEER METHODS ======================

  /// Salva ou atualiza um PeerEntry
  Future<void> savePeer(PeerEntry peer) async {
    final db = await database;
    await db.insert(
      'peers',
      peer.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Obtém uma lista de peers (Kademlia-lite)
  Future<List<PeerEntry>> getPeers({int limit = 20}) async {
    final db = await database;
    final result = await db.query(
      'peers',
      orderBy: 'lastSeen DESC', // Prioriza peers vistos recentemente
      limit: limit,
    );
    return result.map((map) => PeerEntry.fromMap(map)).toList();
  }

  /// Obtém um peer aleatório (para Gossip)
  Future<PeerEntry?> getRandomPeer() async {
    final db = await database;
    final result = await db.rawQuery('SELECT * FROM peers ORDER BY RANDOM() LIMIT 1');
    if (result.isEmpty) return null;
    return PeerEntry.fromMap(result.first);
  // ==================== ATOMIC TRANSACTION ====================

  // Lock para evitar concorrência pesada em escritas simultâneas
  bool _isWriting = false;

  /// Executa uma transação atômica no banco de dados com controle de concorrência
  Future<T> transaction<T>(Future<T> Function(Transaction txn) action) async {
    while (_isWriting) {
      await Future.delayed(const Duration(milliseconds: 10));
    }
    
    _isWriting = true;
    try {
      final db = await database;
      return await db.transaction(action);
    } finally {
      _isWriting = false;
    }
  }

  /// Limpa dados antigos para economizar espaço no celular do usuário
  Future<void> cleanupOldData() async {
    final db = await database;
    final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30)).millisecondsSinceEpoch;
    
    // Remove peers inativos há mais de 30 dias
    await db.delete('peers', where: 'lastSeen < ?', whereArgs: [thirtyDaysAgo]);
    
    // Remove blocos de ledger muito antigos (mantendo os últimos 1000 por segurança)
    final count = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM mesh_ledger')) ?? 0;
    if (count > 1000) {
      final lastIndexToKeep = count - 1000;
      await db.delete('mesh_ledger', where: 'block_index < ?', whereArgs: [lastIndexToKeep]);
    }
    
    logger.info('Limpeza de banco de dados concluída', tag: 'Database');
  }======== MESH LEDGER PERSISTENCE ====================

  /// Salva um bloco do MeshLedger de forma atômica (replace em conflito)
  Future<void> saveMeshBlock(Transaction txn, dynamic blockMap) async {
    await txn.insert(
      'mesh_ledger',
      blockMap,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Convenience wrapper que executa a persistência em transação
  Future<void> persistMeshBlockAtomic(Map<String, dynamic> blockMap) async {
    await transaction((txn) async {
      await saveMeshBlock(txn, blockMap);
    });
  }

  /// Carrega todo o ledger da tabela `mesh_ledger` ordenado por índice
  Future<List<Map<String, dynamic>>> loadLedgerRaw() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('mesh_ledger', orderBy: 'block_index ASC');
    return maps;
  }
}
