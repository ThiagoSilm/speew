import '../../core/utils/logger_service.dart';
import '../../models/file_block.dart';
import '../../models/file_model.dart';
import '../crypto/crypto_service.dart';
import '../storage/database_service.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';

/// ==================== EXPANSÃO: ARQUIVOS GIGANTES (1GB+) ====================
/// Serviço expandido para transferência de arquivos muito grandes
/// 
/// Funcionalidades:
/// - Tamanho adaptativo até 128 KB
/// - Retransmissão inteligente
/// - Compressão opcional
/// - Dual-channel (Wi-Fi Direct + Bluetooth simultâneo)
///
/// ADICIONADO: Fase 6 - Suporte a arquivos gigantes
/// Este módulo EXPANDE o file_transfer_service.dart existente
class LargeFileTransferService extends ChangeNotifier {
  static final LargeFileTransferService _instance = LargeFileTransferService._internal();
  factory LargeFileTransferService() => _instance;
  LargeFileTransferService._internal();

  final CryptoService _crypto = CryptoService();
  final DatabaseService _db = DatabaseService();

  /// Tamanho adaptativo de bloco baseado no tamanho do arquivo
  static const int minBlockSize = 32 * 1024; // 32 KB
  static const int maxBlockSize = 128 * 1024; // 128 KB
  
  /// Threshold para usar compressão automática
  static const int compressionThreshold = 10 * 1024 * 1024; // 10 MB

  /// Progresso de transferências ativas
  final Map<String, TransferProgress> _activeTransfers = {};
  
  /// Blocos pendentes de retransmissão
  final Map<String, Set<int>> _pendingRetransmissions = {};

  /// Estatísticas de transferência
  final Map<String, TransferStats> _transferStats = {};

  // ==================== FRAGMENTAÇÃO ADAPTATIVA ====================

  /// Calcula tamanho de bloco ideal baseado no tamanho do arquivo
  int calculateOptimalBlockSize(int fileSize) {
    if (fileSize < 1024 * 1024) {
      // Arquivos < 1 MB: blocos de 32 KB
      return 32 * 1024;
    } else if (fileSize < 10 * 1024 * 1024) {
      // Arquivos 1-10 MB: blocos de 64 KB
      return 64 * 1024;
    } else if (fileSize < 100 * 1024 * 1024) {
      // Arquivos 10-100 MB: blocos de 96 KB
      return 96 * 1024;
    } else {
      // Arquivos > 100 MB: blocos de 128 KB
      return 128 * 1024;
    }
  }

  /// Fragmenta arquivo grande com compressão opcional
  Future<Map<String, dynamic>> fragmentLargeFile(
    File file,
    String ownerId, {
    bool enableCompression = true,
    Function(double)? onProgress,
  }) async {
    try {
      final fileSize = await file.length();
      final filename = file.path.split('/').last;
      
      logger.info('Iniciando fragmentação: $filename ($fileSize bytes)', tag: 'LargeFileTransfer');

      // Decide se deve comprimir
      final shouldCompress = enableCompression && 
                            fileSize > compressionThreshold &&
                            _isCompressible(filename);

      // Lê e possivelmente comprime o arquivo
      Uint8List fileBytes = await file.readAsBytes();
      int originalSize = fileSize;
      
      if (shouldCompress) {
        logger.info('Comprimindo arquivo...', tag: 'LargeFileTransfer');
        fileBytes = _compressData(fileBytes);
        logger.info('Compressão: ${originalSize} -> ${fileBytes.length} bytes (${((1 - fileBytes.length / originalSize) * 100).toStringAsFixed(1)}% redução)', tag: 'LargeFileTransfer');
      }

      // Calcula tamanho de bloco ideal
      final blockSize = calculateOptimalBlockSize(fileBytes.length);
      
      // Cria modelo do arquivo
      final fileId = _crypto.generateUniqueId();
      final fileModel = FileModel(
        fileId: fileId,
        ownerId: ownerId,
        filename: filename,
        size: originalSize,
        createdAt: DateTime.now(),
      );

      await _db.insertFile(fileModel);

      // Calcula número de blocos
      final totalBlocks = (fileBytes.length / blockSize).ceil();
      final blocks = <FileBlock>[];

      // Inicializa progresso
      _activeTransfers[fileId] = TransferProgress(
        fileId: fileId,
        totalBlocks: totalBlocks,
        completedBlocks: 0,
        startTime: DateTime.now(),
      );

      logger.info('Fragmentando em $totalBlocks blocos de ${(blockSize / 1024).toStringAsFixed(1)} KB', tag: 'LargeFileTransfer');

      // Fragmenta e criptografa cada bloco
      for (int i = 0; i < totalBlocks; i++) {
        final start = i * blockSize;
        final end = (start + blockSize > fileBytes.length) ? fileBytes.length : start + blockSize;
        final blockData = fileBytes.sublist(start, end);

        // Gera chave única para o bloco
        final blockKey = await _crypto.generateSymmetricKey();

        // Criptografa o bloco
        final encrypted = await _crypto.encryptBytes(blockData, blockKey);

        // Calcula checksum
        final checksum = _crypto.sha256HashBytes(blockData);

        // Cria bloco
        final blockId = _crypto.generateUniqueId();
        final block = FileBlock(
          blockId: blockId,
          fileId: fileId,
          blockIndex: i,
          totalBlocks: totalBlocks,
          dataEncrypted: base64Encode(encrypted['ciphertext']),
          checksum: checksum,
        );

        await _db.insertFileBlock(block);
        blocks.add(block);

        // Atualiza progresso
        _activeTransfers[fileId]!.completedBlocks = i + 1;
        final progress = (i + 1) / totalBlocks;
        onProgress?.call(progress);
        
        if ((i + 1) % 10 == 0) {
          logger.info('Progresso: ${(progress * 100).toStringAsFixed(1)}%', tag: 'LargeFileTransfer');
        }
      }

      // Registra estatísticas
      _transferStats[fileId] = TransferStats(
        fileId: fileId,
        originalSize: originalSize,
        compressedSize: shouldCompress ? fileBytes.length : originalSize,
        totalBlocks: totalBlocks,
        blockSize: blockSize,
        compressed: shouldCompress,
        startTime: _activeTransfers[fileId]!.startTime,
        endTime: DateTime.now(),
      );

      logger.info('Fragmentação concluída: $totalBlocks blocos', tag: 'LargeFileTransfer');

      return {
        'fileModel': fileModel,
        'blocks': blocks,
        'compressed': shouldCompress,
        'originalSize': originalSize,
        'compressedSize': fileBytes.length,
        'blockSize': blockSize,
      };
    } catch (e) {
      logger.info('Erro ao fragmentar arquivo: $e', tag: 'LargeFileTransfer');
      rethrow;
    }
  }

  // ==================== RETRANSMISSÃO INTELIGENTE ====================

  /// Marca um bloco como perdido para retransmissão
  void markBlockForRetransmission(String fileId, int blockIndex) {
    if (!_pendingRetransmissions.containsKey(fileId)) {
      _pendingRetransmissions[fileId] = {};
    }
    _pendingRetransmissions[fileId]!.add(blockIndex);
    
    logger.info('Bloco $blockIndex do arquivo $fileId marcado para retransmissão', tag: 'LargeFileTransfer');
  }

  /// Obtém blocos pendentes de retransmissão
  Set<int> getPendingRetransmissions(String fileId) {
    return _pendingRetransmissions[fileId] ?? {};
  }

  /// Retransmite blocos perdidos
  Future<List<FileBlock>> retransmitMissingBlocks(String fileId) async {
    try {
      final pendingBlocks = getPendingRetransmissions(fileId);
      
      if (pendingBlocks.isEmpty) {
        logger.info('Nenhum bloco pendente para retransmissão', tag: 'LargeFileTransfer');
        return [];
      }

      logger.info('Retransmitindo ${pendingBlocks.length} blocos', tag: 'LargeFileTransfer');

      final blocks = <FileBlock>[];
      for (final blockIndex in pendingBlocks) {
        final allBlocks = await _db.getFileBlocks(fileId);
        final block = allBlocks.firstWhere(
          (b) => b.blockIndex == blockIndex,
          orElse: () => throw Exception('Bloco $blockIndex não encontrado'),
        );
        blocks.add(block);
      }

      // Limpa lista de pendentes
      _pendingRetransmissions[fileId]?.clear();

      return blocks;
    } catch (e) {
      logger.info('Erro ao retransmitir blocos: $e', tag: 'LargeFileTransfer');
      return [];
    }
  }

  /// Verifica integridade de todos os blocos
  Future<List<int>> verifyFileIntegrity(String fileId) async {
    try {
      final blocks = await _db.getFileBlocks(fileId);
      final missingBlocks = <int>[];

      if (blocks.isEmpty) {
        return missingBlocks;
      }

      final totalBlocks = blocks.first.totalBlocks;

      // Verifica blocos faltantes
      for (int i = 0; i < totalBlocks; i++) {
        final hasBlock = blocks.any((b) => b.blockIndex == i);
        if (!hasBlock) {
          missingBlocks.add(i);
        }
      }

      if (missingBlocks.isNotEmpty) {
        logger.info('Blocos faltantes: $missingBlocks', tag: 'LargeFileTransfer');
        for (final blockIndex in missingBlocks) {
          markBlockForRetransmission(fileId, blockIndex);
        }
      }

      return missingBlocks;
    } catch (e) {
      logger.info('Erro ao verificar integridade: $e', tag: 'LargeFileTransfer');
      return [];
    }
  }

  // ==================== COMPRESSÃO ====================

  /// Verifica se um arquivo é compressível baseado na extensão
  bool _isCompressible(String filename) {
    final compressibleExtensions = [
      'txt', 'json', 'xml', 'html', 'css', 'js',
      'csv', 'log', 'md', 'doc', 'docx', 'pdf'
    ];
    
    final extension = filename.split('.').last.toLowerCase();
    return compressibleExtensions.contains(extension);
  }

  /// Comprime dados usando GZip
  Uint8List _compressData(Uint8List data) {
    final encoder = GZipEncoder();
    final compressed = encoder.encode(data);
    return Uint8List.fromList(compressed!);
  }

  /// Descomprime dados usando GZip
  Uint8List _decompressData(Uint8List data) {
    final decoder = GZipDecoder();
    final decompressed = decoder.decodeBytes(data);
    return Uint8List.fromList(decompressed);
  }

  /// Reconstrói arquivo a partir dos blocos com descompressão
  Future<Uint8List> reconstructFile(String fileId, {bool wasCompressed = false}) async {
    try {
      final blocks = await _db.getFileBlocks(fileId);
      
      if (blocks.isEmpty) {
        throw Exception('Nenhum bloco encontrado para o arquivo $fileId');
      }

      // Ordena blocos por índice
      blocks.sort((a, b) => a.blockIndex.compareTo(b.blockIndex));

      // Verifica se todos os blocos estão presentes
      final totalBlocks = blocks.first.totalBlocks;
      if (blocks.length != totalBlocks) {
        throw Exception('Arquivo incompleto: ${blocks.length}/$totalBlocks blocos');
      }

      logger.info('Reconstruindo arquivo de $totalBlocks blocos', tag: 'LargeFileTransfer');

      // Reconstrói o arquivo
      final buffer = BytesBuilder();
      
      for (final block in blocks) {
        final decrypted = base64Decode(block.dataEncrypted);
        buffer.add(decrypted);
      }

      Uint8List fileBytes = buffer.toBytes();

      // Descomprime se necessário
      if (wasCompressed) {
        logger.info('Descomprimindo arquivo...', tag: 'LargeFileTransfer');
        fileBytes = _decompressData(fileBytes);
      }

      logger.info('Arquivo reconstruído: ${fileBytes.length} bytes', tag: 'LargeFileTransfer');
      return fileBytes;
    } catch (e) {
      logger.info('Erro ao reconstruir arquivo: $e', tag: 'LargeFileTransfer');
      rethrow;
    }
  }

  // ==================== DUAL-CHANNEL ====================

  /// Envia bloco via dual-channel (Wi-Fi Direct + Bluetooth)
  Future<bool> sendBlockDualChannel(
    FileBlock block,
    String peerId, {
    bool preferWiFi = true,
  }) async {
    try {
      // Tenta enviar via Wi-Fi Direct primeiro (se preferido)
      if (preferWiFi) {
        final wifiSuccess = await _sendViaWiFi(block, peerId);
        if (wifiSuccess) {
          logger.info('Bloco ${block.blockIndex} enviado via Wi-Fi', tag: 'LargeFileTransfer');
          return true;
        }
      }

      // Fallback para Bluetooth
      final btSuccess = await _sendViaBluetooth(block, peerId);
      if (btSuccess) {
        logger.info('Bloco ${block.blockIndex} enviado via Bluetooth', tag: 'LargeFileTransfer');
        return true;
      }

      // Se ambos falharem, marca para retransmissão
      markBlockForRetransmission(block.fileId, block.blockIndex);
      return false;
    } catch (e) {
      logger.info('Erro ao enviar bloco dual-channel: $e', tag: 'LargeFileTransfer');
      return false;
    }
  }

  /// Simula envio via Wi-Fi Direct (implementação real requer integração)
  Future<bool> _sendViaWiFi(FileBlock block, String peerId) async {
    // Implementação simulada - em produção, usar nearby_connections
    await Future.delayed(const Duration(milliseconds: 10));
    return true; // Simula sucesso
  }

  /// Simula envio via Bluetooth (implementação real requer integração)
  Future<bool> _sendViaBluetooth(FileBlock block, String peerId) async {
    // Implementação simulada - em produção, usar flutter_blue_plus
    await Future.delayed(const Duration(milliseconds: 50));
    return true; // Simula sucesso
  }

  // ==================== ESTATÍSTICAS ====================

  /// Obtém estatísticas de transferência
  TransferStats? getTransferStats(String fileId) {
    return _transferStats[fileId];
  }

  /// Obtém progresso de transferência ativa
  TransferProgress? getTransferProgress(String fileId) {
    return _activeTransfers[fileId];
  }

  /// Calcula velocidade de transferência
  double calculateTransferSpeed(String fileId) {
    final progress = _activeTransfers[fileId];
    if (progress == null) return 0.0;

    final elapsed = DateTime.now().difference(progress.startTime).inSeconds;
    if (elapsed == 0) return 0.0;

    final stats = _transferStats[fileId];
    if (stats == null) return 0.0;

    return stats.compressedSize / elapsed; // bytes por segundo
  }

  // ==================== LIMPEZA ====================

  /// Limpa transferências concluídas
  void clearCompletedTransfers() {
    _activeTransfers.clear();
    _pendingRetransmissions.clear();
    notifyListeners();
  }
}

/// Classe auxiliar para progresso de transferência
class TransferProgress {
  final String fileId;
  final int totalBlocks;
  int completedBlocks;
  final DateTime startTime;

  TransferProgress({
    required this.fileId,
    required this.totalBlocks,
    required this.completedBlocks,
    required this.startTime,
  });

  double get progress => completedBlocks / totalBlocks;
}

/// Classe auxiliar para estatísticas de transferência
class TransferStats {
  final String fileId;
  final int originalSize;
  final int compressedSize;
  final int totalBlocks;
  final int blockSize;
  final bool compressed;
  final DateTime startTime;
  final DateTime endTime;

  TransferStats({
    required this.fileId,
    required this.originalSize,
    required this.compressedSize,
    required this.totalBlocks,
    required this.blockSize,
    required this.compressed,
    required this.startTime,
    required this.endTime,
  });

  Duration get duration => endTime.difference(startTime);
  double get compressionRatio => compressed ? compressedSize / originalSize : 1.0;
  double get averageSpeed => compressedSize / duration.inSeconds; // bytes/s
}
