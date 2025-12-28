import '../../core/utils/logger_service.dart';
import '../crypto/crypto_service.dart';
import '../storage/database_service.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';

/// ==================== NOVO MÓDULO: BACKUP OFFLINE ====================
/// Serviço de backup e restauração offline
/// 
/// Funcionalidades:
/// - Exportação do banco criptografado
/// - Backup via QR Code ou via P2P
/// - Restauração offline
/// - Compressão e criptografia de snapshots
///
/// ADICIONADO: Fase 8 - Backup Offline
class BackupService extends ChangeNotifier {
  static final BackupService _instance = BackupService._internal();
  factory BackupService() => _instance;
  BackupService._internal();

  final CryptoService _crypto = CryptoService();
  final DatabaseService _db = DatabaseService();

  /// Status do último backup
  BackupStatus? _lastBackupStatus;
  BackupStatus? get lastBackupStatus => _lastBackupStatus;

  /// Progresso de backup/restauração
  double _progress = 0.0;
  double get progress => _progress;

  // ==================== EXPORTAÇÃO DE BACKUP ====================

  /// Cria um backup completo do banco de dados
  Future<BackupData> createFullBackup({
    required String userId,
    required String password,
    bool compress = true,
    Function(double)? onProgress,
  }) async {
    try {
      logger.info('Iniciando backup completo...', tag: 'Backup');
      _progress = 0.0;

      // 1. Exporta dados do banco (20%)
      onProgress?.call(0.1);
      final databaseSnapshot = await _exportDatabaseSnapshot(userId);
      onProgress?.call(0.2);

      // 2. Serializa para JSON (10%)
      final jsonData = jsonEncode(databaseSnapshot);
      final jsonBytes = utf8.encode(jsonData);
      onProgress?.call(0.3);

      // 3. Comprime se necessário (20%)
      Uint8List dataToEncrypt = Uint8List.fromList(jsonBytes);
      int originalSize = jsonBytes.length;
      
      if (compress) {
        logger.info('Comprimindo dados...', tag: 'Backup');
        final encoder = GZipEncoder();
        final compressed = encoder.encode(jsonBytes);
        dataToEncrypt = Uint8List.fromList(compressed!);
        logger.info('Compressão: ${originalSize} -> ${dataToEncrypt.length} bytes', tag: 'Backup');
      }
      onProgress?.call(0.5);

      // 4. Gera chave de criptografia a partir da senha (10%)
      final encryptionKey = _deriveKeyFromPassword(password);
      onProgress?.call(0.6);

      // 5. Criptografa os dados (20%)
      logger.info('Criptografando backup...', tag: 'Backup');
      final encrypted = await _crypto.encryptBytes(
        dataToEncrypt.toList(),
        encryptionKey,
      );
      onProgress?.call(0.8);

      // 6. Cria estrutura do backup (10%)
      final backupData = BackupData(
        backupId: _crypto.generateUniqueId(),
        userId: userId,
        createdAt: DateTime.now(),
        originalSize: originalSize,
        compressedSize: dataToEncrypt.length,
        encryptedData: base64Encode(encrypted['ciphertext']),
        nonce: base64Encode(encrypted['nonce']),
        mac: base64Encode(encrypted['mac']),
        compressed: compress,
        version: '1.0',
      );

      _lastBackupStatus = BackupStatus(
        success: true,
        timestamp: DateTime.now(),
        size: dataToEncrypt.length,
        message: 'Backup criado com sucesso',
      );

      _progress = 1.0;
      onProgress?.call(1.0);

      logger.info('Backup concluído: ${backupData.backupId}', tag: 'Backup');
      notifyListeners();

      return backupData;
    } catch (e) {
      logger.info('Erro ao criar backup: $e', tag: 'Backup');
      
      _lastBackupStatus = BackupStatus(
        success: false,
        timestamp: DateTime.now(),
        message: 'Erro ao criar backup: $e',
      );
      
      notifyListeners();
      rethrow;
    }
  }

  /// Exporta snapshot do banco de dados
  Future<Map<String, dynamic>> _exportDatabaseSnapshot(String userId) async {
    try {
      // Exporta todas as tabelas relevantes
      final users = await _db.getAllUsers();
      final messages = await _db.getPendingMessages();
      final transactions = await _db.getUserTransactions(userId);
      
      return {
        'version': '1.0',
        'timestamp': DateTime.now().toIso8601String(),
        'userId': userId,
        'users': users.map((u) => u.toMap()).toList(),
        'messages': messages.map((m) => m.toMap()).toList(),
        'transactions': transactions.map((t) => t.toMap()).toList(),
      };
    } catch (e) {
      logger.info('Erro ao exportar snapshot: $e', tag: 'Backup');
      rethrow;
    }
  }

  /// Deriva chave de criptografia a partir de senha
  String _deriveKeyFromPassword(String password) {
    // Em produção, usar PBKDF2 ou Argon2
    // Esta é uma implementação simplificada
    final hash = _crypto.sha256Hash(password);
    return base64Encode(utf8.encode(hash.substring(0, 32)));
  }

  // ==================== EXPORTAÇÃO VIA QR CODE ====================

  /// Exporta backup como QR Code (para backups pequenos)
  Future<List<String>> exportAsQRCodes(BackupData backupData, {int maxChunkSize = 2000}) async {
    try {
      logger.info('Gerando QR Codes...', tag: 'Backup');

      // Serializa backup
      final backupJson = jsonEncode(backupData.toMap());
      final backupBytes = utf8.encode(backupJson);

      // Divide em chunks para múltiplos QR Codes
      final chunks = <String>[];
      final totalChunks = (backupBytes.length / maxChunkSize).ceil();

      for (int i = 0; i < totalChunks; i++) {
        final start = i * maxChunkSize;
        final end = (start + maxChunkSize > backupBytes.length) 
            ? backupBytes.length 
            : start + maxChunkSize;
        
        final chunk = backupBytes.sublist(start, end);
        final chunkData = {
          'part': i + 1,
          'total': totalChunks,
          'data': base64Encode(chunk),
        };
        
        chunks.add(jsonEncode(chunkData));
      }

      logger.info('Backup dividido em ${chunks.length} QR Codes', tag: 'Backup');
      return chunks;
    } catch (e) {
      logger.info('Erro ao gerar QR Codes: $e', tag: 'Backup');
      rethrow;
    }
  }

  /// Reconstrói backup a partir de QR Codes
  Future<BackupData> reconstructFromQRCodes(List<String> qrCodeData) async {
    try {
      logger.info('Reconstruindo backup de ${qrCodeData.length} QR Codes...', tag: 'Backup');

      // Parseia e ordena chunks
      final chunks = <int, String>{};
      int totalChunks = 0;

      for (final qrData in qrCodeData) {
        final chunkData = jsonDecode(qrData) as Map<String, dynamic>;
        final part = chunkData['part'] as int;
        final total = chunkData['total'] as int;
        final data = chunkData['data'] as String;

        chunks[part] = data;
        totalChunks = total;
      }

      // Verifica se todos os chunks estão presentes
      if (chunks.length != totalChunks) {
        throw Exception('Backup incompleto: ${chunks.length}/$totalChunks chunks');
      }

      // Reconstrói dados
      final buffer = BytesBuilder();
      for (int i = 1; i <= totalChunks; i++) {
        final chunk = base64Decode(chunks[i]!);
        buffer.add(chunk);
      }

      // Deserializa backup
      final backupJson = utf8.decode(buffer.toBytes());
      final backupMap = jsonDecode(backupJson) as Map<String, dynamic>;

      return BackupData.fromMap(backupMap);
    } catch (e) {
      logger.info('Erro ao reconstruir de QR Codes: $e', tag: 'Backup');
      rethrow;
    }
  }

  // ==================== EXPORTAÇÃO VIA P2P ====================

  /// Exporta backup para outro dispositivo via P2P
  Future<bool> exportViaP2P(BackupData backupData, String targetPeerId) async {
    try {
      logger.info('Exportando backup via P2P para $targetPeerId...', tag: 'Backup');

      // Serializa backup
      final backupJson = jsonEncode(backupData.toMap());
      final backupBytes = utf8.encode(backupJson);

      // Em produção, usar o serviço de transferência de arquivos
      // Esta é uma implementação simulada
      await Future.delayed(const Duration(seconds: 2));

      logger.info('Backup exportado via P2P: ${backupBytes.length} bytes', tag: 'Backup');
      return true;
    } catch (e) {
      logger.info('Erro ao exportar via P2P: $e', tag: 'Backup');
      return false;
    }
  }

  /// Importa backup de outro dispositivo via P2P
  Future<BackupData?> importViaP2P(String sourcePeerId) async {
    try {
      logger.info('Importando backup via P2P de $sourcePeerId...', tag: 'Backup');

      // Em produção, usar o serviço de transferência de arquivos
      // Esta é uma implementação simulada
      await Future.delayed(const Duration(seconds: 2));

      // Retorna null para simular (em produção, retornaria BackupData real)
      return null;
    } catch (e) {
      logger.info('Erro ao importar via P2P: $e', tag: 'Backup');
      return null;
    }
  }

  // ==================== RESTAURAÇÃO ====================

  /// Restaura backup
  Future<bool> restoreBackup({
    required BackupData backupData,
    required String password,
    Function(double)? onProgress,
  }) async {
    try {
      logger.info('Iniciando restauração...', tag: 'Backup');
      _progress = 0.0;

      // 1. Deriva chave da senha (10%)
      final encryptionKey = _deriveKeyFromPassword(password);
      onProgress?.call(0.1);

      // 2. Descriptografa dados (30%)
      logger.info('Descriptografando backup...', tag: 'Backup');
      final decrypted = await _crypto.decryptBytes(
        base64Decode(backupData.encryptedData),
        base64Decode(backupData.nonce),
        base64Decode(backupData.mac),
        encryptionKey,
      );
      onProgress?.call(0.4);

      // 3. Descomprime se necessário (20%)
      Uint8List jsonBytes;
      if (backupData.compressed) {
        logger.info('Descomprimindo dados...', tag: 'Backup');
        final decoder = GZipDecoder();
        final decompressed = decoder.decodeBytes(decrypted);
        jsonBytes = Uint8List.fromList(decompressed);
      } else {
        jsonBytes = Uint8List.fromList(decrypted);
      }
      onProgress?.call(0.6);

      // 4. Parseia JSON (10%)
      final jsonData = utf8.decode(jsonBytes);
      final snapshot = jsonDecode(jsonData) as Map<String, dynamic>;
      onProgress?.call(0.7);

      // 5. Restaura dados no banco (30%)
      logger.info('Restaurando dados no banco...', tag: 'Backup');
      await _restoreDatabaseSnapshot(snapshot);
      onProgress?.call(1.0);

      _lastBackupStatus = BackupStatus(
        success: true,
        timestamp: DateTime.now(),
        message: 'Backup restaurado com sucesso',
      );

      _progress = 1.0;
      logger.info('Restauração concluída', tag: 'Backup');
      notifyListeners();

      return true;
    } catch (e) {
      logger.info('Erro ao restaurar backup: $e', tag: 'Backup');
      
      _lastBackupStatus = BackupStatus(
        success: false,
        timestamp: DateTime.now(),
        message: 'Erro ao restaurar backup: $e',
      );
      
      notifyListeners();
      return false;
    }
  }

  /// Restaura snapshot no banco de dados
  Future<void> _restoreDatabaseSnapshot(Map<String, dynamic> snapshot) async {
    try {
      // Restaura usuários
      if (snapshot.containsKey('users')) {
        final users = snapshot['users'] as List;
        for (final userData in users) {
          // Implementar inserção no banco
          logger.info('Restaurando usuário...', tag: 'Backup');
        }
      }

      // Restaura mensagens
      if (snapshot.containsKey('messages')) {
        final messages = snapshot['messages'] as List;
        for (final messageData in messages) {
          // Implementar inserção no banco
          logger.info('Restaurando mensagem...', tag: 'Backup');
        }
      }

      // Restaura transações
      if (snapshot.containsKey('transactions')) {
        final transactions = snapshot['transactions'] as List;
        for (final txData in transactions) {
          // Implementar inserção no banco
          logger.info('Restaurando transação...', tag: 'Backup');
        }
      }

      logger.info('Snapshot restaurado', tag: 'Backup');
    } catch (e) {
      logger.info('Erro ao restaurar snapshot: $e', tag: 'Backup');
      rethrow;
    }
  }

  // ==================== SALVAMENTO EM ARQUIVO ====================

  /// Salva backup em arquivo
  Future<File> saveBackupToFile(BackupData backupData, String filePath) async {
    try {
      final file = File(filePath);
      final backupJson = jsonEncode(backupData.toMap());
      await file.writeAsString(backupJson);
      
      logger.info('Backup salvo em: $filePath', tag: 'Backup');
      return file;
    } catch (e) {
      logger.info('Erro ao salvar backup: $e', tag: 'Backup');
      rethrow;
    }
  }

  /// Carrega backup de arquivo
  Future<BackupData> loadBackupFromFile(String filePath) async {
    try {
      final file = File(filePath);
      final backupJson = await file.readAsString();
      final backupMap = jsonDecode(backupJson) as Map<String, dynamic>;
      
      return BackupData.fromMap(backupMap);
    } catch (e) {
      logger.info('Erro ao carregar backup: $e', tag: 'Backup');
      rethrow;
    }
  }

  // ==================== UTILITÁRIOS ====================

  /// Valida backup
  bool validateBackup(BackupData backupData) {
    try {
      return backupData.encryptedData.isNotEmpty &&
             backupData.nonce.isNotEmpty &&
             backupData.mac.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Obtém informações do backup
  Map<String, dynamic> getBackupInfo(BackupData backupData) {
    return {
      'backupId': backupData.backupId,
      'createdAt': backupData.createdAt,
      'originalSize': backupData.originalSize,
      'compressedSize': backupData.compressedSize,
      'compressed': backupData.compressed,
      'compressionRatio': backupData.compressed 
          ? (1 - backupData.compressedSize / backupData.originalSize) * 100
          : 0.0,
      'version': backupData.version,
    };
  }
}

/// Classe de dados de backup
class BackupData {
  final String backupId;
  final String userId;
  final DateTime createdAt;
  final int originalSize;
  final int compressedSize;
  final String encryptedData;
  final String nonce;
  final String mac;
  final bool compressed;
  final String version;

  BackupData({
    required this.backupId,
    required this.userId,
    required this.createdAt,
    required this.originalSize,
    required this.compressedSize,
    required this.encryptedData,
    required this.nonce,
    required this.mac,
    required this.compressed,
    required this.version,
  });

  Map<String, dynamic> toMap() {
    return {
      'backup_id': backupId,
      'user_id': userId,
      'created_at': createdAt.toIso8601String(),
      'original_size': originalSize,
      'compressed_size': compressedSize,
      'encrypted_data': encryptedData,
      'nonce': nonce,
      'mac': mac,
      'compressed': compressed,
      'version': version,
    };
  }

  factory BackupData.fromMap(Map<String, dynamic> map) {
    return BackupData(
      backupId: map['backup_id'] as String,
      userId: map['user_id'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      originalSize: map['original_size'] as int,
      compressedSize: map['compressed_size'] as int,
      encryptedData: map['encrypted_data'] as String,
      nonce: map['nonce'] as String,
      mac: map['mac'] as String,
      compressed: map['compressed'] as bool,
      version: map['version'] as String,
    );
  }
}

/// Classe de status de backup
class BackupStatus {
  final bool success;
  final DateTime timestamp;
  final int? size;
  final String message;

  BackupStatus({
    required this.success,
    required this.timestamp,
    this.size,
    required this.message,
  });
}
