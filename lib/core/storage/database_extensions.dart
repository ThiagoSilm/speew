import '../../models/coin_transaction.dart';
import '../../models/coin_type.dart';
import '../../models/marketplace_item.dart';
import '../../models/private_network.dart';
import '../../models/trust_event.dart';
import 'database_service.dart';
import 'package:sqflite/sqflite.dart';

/// ==================== EXTENSÕES DO DATABASE SERVICE ====================
/// Métodos adicionais para suporte aos novos módulos
/// 
/// Este arquivo contém extensões do DatabaseService para:
/// - Tipos de moeda
/// - Marketplace
/// - Redes privadas
/// - Eventos de confiança
/// - Transações avançadas
///
/// ADICIONADO: Fase 9 - Integração com banco de dados
/// 
/// NOTA: Em produção, estes métodos devem ser adicionados diretamente
/// ao database_service.dart ou implementados via migration do banco.
extension DatabaseExtensions on DatabaseService {
  // ==================== COIN TYPES ====================

  Future<void> insertCoinType(CoinType coinType) async {
    final db = await database;
    await db.insert('coin_types', coinType.toMap(), 
      conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<CoinType>> getAllCoinTypes() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('coin_types');
    return List.generate(maps.length, (i) => CoinType.fromMap(maps[i]));
  }

  Future<double> getUserBalanceByType(String userId, String coinTypeId) async {
    final db = await database;
    
    final received = await db.rawQuery(
      'SELECT SUM(amount) as total FROM coin_transactions WHERE receiver_id = ? AND coin_type_id = ? AND status = ?',
      [userId, coinTypeId, 'accepted'],
    );
    final receivedTotal = (received.first['total'] as double?) ?? 0.0;
    
    final sent = await db.rawQuery(
      'SELECT SUM(amount) as total FROM coin_transactions WHERE sender_id = ? AND coin_type_id = ? AND status = ?',
      [userId, coinTypeId, 'accepted'],
    );
    final sentTotal = (sent.first['total'] as double?) ?? 0.0;
    
    return receivedTotal - sentTotal;
  }

  // ==================== MARKETPLACE ====================

  Future<void> insertMarketplaceItem(MarketplaceItem item) async {
    final db = await database;
    await db.insert('marketplace_items', item.toMap());
  }

  Future<MarketplaceItem?> getMarketplaceItem(String itemId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'marketplace_items',
      where: 'item_id = ?',
      whereArgs: [itemId],
    );
    if (maps.isEmpty) return null;
    return MarketplaceItem.fromMap(maps.first);
  }

  Future<List<MarketplaceItem>> searchMarketplaceItems({
    String? category,
    String? coinTypeId,
    String? searchQuery,
    double? maxPrice,
  }) async {
    final db = await database;
    String whereClause = 'status = ?';
    List<dynamic> whereArgs = ['available'];

    if (category != null) {
      whereClause += ' AND category = ?';
      whereArgs.add(category);
    }
    if (coinTypeId != null) {
      whereClause += ' AND coin_type_id = ?';
      whereArgs.add(coinTypeId);
    }
    if (maxPrice != null) {
      whereClause += ' AND price <= ?';
      whereArgs.add(maxPrice);
    }

    final List<Map<String, dynamic>> maps = await db.query(
      'marketplace_items',
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'created_at DESC',
    );
    return List.generate(maps.length, (i) => MarketplaceItem.fromMap(maps[i]));
  }

  Future<List<MarketplaceItem>> getMarketplaceItemsBySeller(String sellerId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'marketplace_items',
      where: 'seller_id = ?',
      whereArgs: [sellerId],
      orderBy: 'created_at DESC',
    );
    return List.generate(maps.length, (i) => MarketplaceItem.fromMap(maps[i]));
  }

  Future<void> updateMarketplaceItemStatus(String itemId, String status, String? buyerId) async {
    final db = await database;
    await db.update(
      'marketplace_items',
      {
        'status': status,
        'buyer_id': buyerId,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'item_id = ?',
      whereArgs: [itemId],
    );
  }

  // ==================== PRIVATE NETWORKS ====================

  Future<void> insertPrivateNetwork(PrivateNetwork network) async {
    final db = await database;
    await db.insert('private_networks', network.toMap());
  }

  Future<PrivateNetwork?> getPrivateNetwork(String networkId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'private_networks',
      where: 'network_id = ?',
      whereArgs: [networkId],
    );
    if (maps.isEmpty) return null;
    return PrivateNetwork.fromMap(maps.first);
  }

  Future<List<PrivateNetwork>> getUserPrivateNetworks(String userId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT pn.* FROM private_networks pn
      INNER JOIN network_participants np ON pn.network_id = np.network_id
      WHERE np.user_id = ? AND np.status = 'active'
      ORDER BY pn.created_at DESC
    ''', [userId]);
    return List.generate(maps.length, (i) => PrivateNetwork.fromMap(maps[i]));
  }

  Future<void> updatePrivateNetworkStatus(String networkId, String status) async {
    final db = await database;
    await db.update(
      'private_networks',
      {'status': status},
      where: 'network_id = ?',
      whereArgs: [networkId],
    );
  }

  // ==================== NETWORK PARTICIPANTS ====================

  Future<void> insertNetworkParticipant(NetworkParticipant participant) async {
    final db = await database;
    await db.insert('network_participants', participant.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<NetworkParticipant?> getNetworkParticipant(String networkId, String userId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'network_participants',
      where: 'network_id = ? AND user_id = ?',
      whereArgs: [networkId, userId],
    );
    if (maps.isEmpty) return null;
    return NetworkParticipant.fromMap(maps.first);
  }

  Future<List<NetworkParticipant>> getNetworkParticipants(String networkId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'network_participants',
      where: 'network_id = ? AND status = ?',
      whereArgs: [networkId, 'active'],
      orderBy: 'joined_at ASC',
    );
    return List.generate(maps.length, (i) => NetworkParticipant.fromMap(maps[i]));
  }

  Future<void> updateNetworkParticipantStatus(String networkId, String userId, String status) async {
    final db = await database;
    await db.update(
      'network_participants',
      {'status': status},
      where: 'network_id = ? AND user_id = ?',
      whereArgs: [networkId, userId],
    );
  }

  Future<void> updateNetworkParticipantRole(String networkId, String userId, String role) async {
    final db = await database;
    await db.update(
      'network_participants',
      {'role': role},
      where: 'network_id = ? AND user_id = ?',
      whereArgs: [networkId, userId],
    );
  }

  // ==================== TRUST EVENTS ====================

  Future<void> insertTrustEvent(TrustEvent event) async {
    final db = await database;
    await db.insert('trust_events', event.toMap());
  }

  Future<List<TrustEvent>> getTrustEvents(String userId, {int? limit}) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'trust_events',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'timestamp DESC',
      limit: limit,
    );
    return List.generate(maps.length, (i) => TrustEvent.fromMap(maps[i]));
  }

  Future<void> deleteTrustEventsBefore(DateTime cutoffDate) async {
    final db = await database;
    await db.delete(
      'trust_events',
      where: 'timestamp < ?',
      whereArgs: [cutoffDate.toIso8601String()],
    );
  }

  Future<void> updateUserTrustScore(String userId, double trustScore) async {
    final db = await database;
    await db.update(
      'users',
      {'trust_score': trustScore},
      where: 'user_id = ?',
      whereArgs: [userId],
    );
  }

  // ==================== ADVANCED TRANSACTIONS ====================

  Future<CoinTransaction?> getTransaction(String transactionId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'coin_transactions',
      where: 'transaction_id = ?',
      whereArgs: [transactionId],
    );
    if (maps.isEmpty) return null;
    return CoinTransaction.fromMap(maps.first);
  }

  Future<void> updateTransactionChain(String transactionId, String nextTransactionId) async {
    final db = await database;
    await db.update(
      'coin_transactions',
      {'next_transaction_id': nextTransactionId},
      where: 'transaction_id = ?',
      whereArgs: [transactionId],
    );
  }

  Future<List<CoinTransaction>> getFilteredTransactions({
    required String userId,
    String? coinTypeId,
    DateTime? startDate,
    DateTime? endDate,
    String? status,
  }) async {
    final db = await database;
    String whereClause = '(sender_id = ? OR receiver_id = ?)';
    List<dynamic> whereArgs = [userId, userId];

    if (coinTypeId != null) {
      whereClause += ' AND coin_type_id = ?';
      whereArgs.add(coinTypeId);
    }
    if (startDate != null) {
      whereClause += ' AND timestamp >= ?';
      whereArgs.add(startDate.toIso8601String());
    }
    if (endDate != null) {
      whereClause += ' AND timestamp <= ?';
      whereArgs.add(endDate.toIso8601String());
    }
    if (status != null) {
      whereClause += ' AND status = ?';
      whereArgs.add(status);
    }

    final List<Map<String, dynamic>> maps = await db.query(
      'coin_transactions',
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'timestamp DESC',
    );
    return List.generate(maps.length, (i) => CoinTransaction.fromMap(maps[i]));
  }
}

/// Script SQL para criar as novas tabelas
/// 
/// NOTA: Este script deve ser executado via migration do banco de dados
/// para adicionar suporte às novas funcionalidades.
const String migrationScript = '''
-- Tabela de tipos de moeda
CREATE TABLE IF NOT EXISTS coin_types (
  coin_type_id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  description TEXT NOT NULL,
  color TEXT NOT NULL,
  icon TEXT NOT NULL,
  created_at TEXT NOT NULL,
  is_convertible INTEGER NOT NULL DEFAULT 0,
  conversion_rate REAL
);

-- Tabela de itens do marketplace
CREATE TABLE IF NOT EXISTS marketplace_items (
  item_id TEXT PRIMARY KEY,
  seller_id TEXT NOT NULL,
  title TEXT NOT NULL,
  description TEXT NOT NULL,
  category TEXT NOT NULL,
  price REAL NOT NULL,
  coin_type_id TEXT NOT NULL,
  status TEXT NOT NULL,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  tags TEXT NOT NULL,
  buyer_id TEXT,
  image_data TEXT,
  FOREIGN KEY (seller_id) REFERENCES users (user_id),
  FOREIGN KEY (coin_type_id) REFERENCES coin_types (coin_type_id)
);

-- Tabela de redes privadas
CREATE TABLE IF NOT EXISTS private_networks (
  network_id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  description TEXT NOT NULL,
  creator_id TEXT NOT NULL,
  access_key_hash TEXT NOT NULL,
  created_at TEXT NOT NULL,
  max_participants INTEGER NOT NULL DEFAULT 0,
  status TEXT NOT NULL,
  auth_type TEXT NOT NULL,
  qr_code_data TEXT,
  settings TEXT,
  FOREIGN KEY (creator_id) REFERENCES users (user_id)
);

-- Tabela de participantes de redes privadas
CREATE TABLE IF NOT EXISTS network_participants (
  user_id TEXT NOT NULL,
  network_id TEXT NOT NULL,
  joined_at TEXT NOT NULL,
  role TEXT NOT NULL,
  status TEXT NOT NULL,
  PRIMARY KEY (user_id, network_id),
  FOREIGN KEY (user_id) REFERENCES users (user_id),
  FOREIGN KEY (network_id) REFERENCES private_networks (network_id)
);

-- Tabela de eventos de confiança
CREATE TABLE IF NOT EXISTS trust_events (
  event_id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  event_type TEXT NOT NULL,
  impact REAL NOT NULL,
  timestamp TEXT NOT NULL,
  metadata TEXT,
  severity TEXT NOT NULL,
  FOREIGN KEY (user_id) REFERENCES users (user_id)
);

-- Adiciona colunas às tabelas existentes
ALTER TABLE coin_transactions ADD COLUMN coin_type_id TEXT DEFAULT 'default';
ALTER TABLE coin_transactions ADD COLUMN previous_transaction_id TEXT;
ALTER TABLE coin_transactions ADD COLUMN next_transaction_id TEXT;
ALTER TABLE users ADD COLUMN trust_score REAL DEFAULT 0.5;

-- Índices para melhorar performance
CREATE INDEX IF NOT EXISTS idx_marketplace_seller ON marketplace_items(seller_id);
CREATE INDEX IF NOT EXISTS idx_marketplace_status ON marketplace_items(status);
CREATE INDEX IF NOT EXISTS idx_marketplace_category ON marketplace_items(category);
CREATE INDEX IF NOT EXISTS idx_network_participants ON network_participants(network_id);
CREATE INDEX IF NOT EXISTS idx_trust_events_user ON trust_events(user_id);
CREATE INDEX IF NOT EXISTS idx_trust_events_timestamp ON trust_events(timestamp);
CREATE INDEX IF NOT EXISTS idx_transactions_coin_type ON coin_transactions(coin_type_id);
''';
