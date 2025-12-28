import 'package:flutter/material.dart';
import 'economy_exceptions.dart';

/// Exceção base para todas as exceções customizadas do app
abstract class AppException implements Exception {
  final String message;
  final String? code;
  final dynamic originalError;
  final StackTrace? stackTrace;

  AppException(
    this.message, {
    this.code,
    this.originalError,
    this.stackTrace,
  });

  @override
  String toString() {
    final codeStr = code != null ? '[$code] ' : '';
    return '$runtimeType: $codeStr$message';
  }
}

/// Exceção relacionada à rede P2P
class P2PException extends AppException {
  P2PException(
    super.message, {
    super.code,
    super.originalError,
    super.stackTrace,
  });

  /// Erro de conexão
  factory P2PException.connectionFailed(String reason, {Object? error}) {
    return P2PException(
      'Falha na conexão P2P: $reason',
      code: 'P2P_CONNECTION_FAILED',
      originalError: error,
    );
  }

  /// Erro de timeout
  factory P2PException.timeout(String operation) {
    return P2PException(
      'Timeout na operação P2P: $operation',
      code: 'P2P_TIMEOUT',
    );
  }

  /// Peer não encontrado
  factory P2PException.peerNotFound(String peerId) {
    return P2PException(
      'Peer não encontrado: $peerId',
      code: 'P2P_PEER_NOT_FOUND',
    );
  }
}

/// Exceção relacionada ao mesh network
class MeshException extends AppException {
  MeshException(
    super.message, {
    super.code,
    super.originalError,
    super.stackTrace,
  });

  /// Rota não encontrada
  factory MeshException.routeNotFound(String destination) {
    return MeshException(
      'Nenhuma rota encontrada para: $destination',
      code: 'MESH_ROUTE_NOT_FOUND',
    );
  }

  /// Máximo de hops excedido
  factory MeshException.maxHopsExceeded(int hops) {
    return MeshException(
      'Máximo de hops excedido: $hops',
      code: 'MESH_MAX_HOPS_EXCEEDED',
    );
  }

  /// Falha na propagação
  factory MeshException.propagationFailed(String reason) {
    return MeshException(
      'Falha na propagação mesh: $reason',
      code: 'MESH_PROPAGATION_FAILED',
    );
  }
}

/// Exceção relacionada à criptografia
class CryptoException extends AppException {
  CryptoException(
    super.message, {
    super.code,
    super.originalError,
    super.stackTrace,
  });

  /// Erro de encriptação
  factory CryptoException.encryptionFailed(String reason, {Object? error}) {
    return CryptoException(
      'Falha na encriptação: $reason',
      code: 'CRYPTO_ENCRYPTION_FAILED',
      originalError: error,
    );
  }

  /// Erro de decriptação
  factory CryptoException.decryptionFailed(String reason, {Object? error}) {
    return CryptoException(
      'Falha na decriptação: $reason',
      code: 'CRYPTO_DECRYPTION_FAILED',
      originalError: error,
    );
  }

  /// Assinatura inválida
  factory CryptoException.invalidSignature(String details) {
    return CryptoException(
      'Assinatura inválida: $details',
      code: 'CRYPTO_INVALID_SIGNATURE',
    );
  }

  /// Chave inválida
  factory CryptoException.invalidKey(String keyType) {
    return CryptoException(
      'Chave inválida: $keyType',
      code: 'CRYPTO_INVALID_KEY',
    );
  }

  /// Erro na rotação de chaves
  factory CryptoException.keyRotationFailed(String reason) {
    return CryptoException(
      'Falha na rotação de chaves: $reason',
      code: 'CRYPTO_KEY_ROTATION_FAILED',
    );
  }
}

/// Exceção relacionada à integridade de dados
class IntegrityException extends AppException {
  IntegrityException(
    super.message, {
    super.code,
    super.originalError,
    super.stackTrace,
  });

  /// Checksum inválido
  factory IntegrityException.invalidChecksum(String itemId) {
    return IntegrityException(
      'Checksum inválido para: $itemId',
      code: 'INTEGRITY_INVALID_CHECKSUM',
    );
  }

  /// Dados corrompidos
  factory IntegrityException.corruptedData(String dataType) {
    return IntegrityException(
      'Dados corrompidos: $dataType',
      code: 'INTEGRITY_CORRUPTED_DATA',
    );
  }

  /// Conflito de versão
  factory IntegrityException.versionConflict(String itemId, int expected, int actual) {
    return IntegrityException(
      'Conflito de versão em $itemId: esperado $expected, recebido $actual',
      code: 'INTEGRITY_VERSION_CONFLICT',
    );
  }
}

/// Exceção relacionada à sincronização
class SyncException extends AppException {
  SyncException(
    super.message, {
    super.code,
    super.originalError,
    super.stackTrace,
  });

  /// Falha na sincronização
  factory SyncException.syncFailed(String reason, {Object? error}) {
    return SyncException(
      'Falha na sincronização: $reason',
      code: 'SYNC_FAILED',
      originalError: error,
    );
  }

  /// Conflito de merge
  factory SyncException.mergeConflict(String itemId) {
    return SyncException(
      'Conflito de merge detectado: $itemId',
      code: 'SYNC_MERGE_CONFLICT',
    );
  }

  /// Estado inconsistente
  factory SyncException.inconsistentState(String details) {
    return SyncException(
      'Estado inconsistente detectado: $details',
      code: 'SYNC_INCONSISTENT_STATE',
    );
  }
}

/// Exceção relacionada ao storage/database
class StorageException extends AppException {
  StorageException(
    super.message, {
    super.code,
    super.originalError,
    super.stackTrace,
  });

  /// Erro de leitura
  factory StorageException.readFailed(String item, {Object? error}) {
    return StorageException(
      'Falha ao ler: $item',
      code: 'STORAGE_READ_FAILED',
      originalError: error,
    );
  }

  /// Erro de escrita
  factory StorageException.writeFailed(String item, {Object? error}) {
    return StorageException(
      'Falha ao escrever: $item',
      code: 'STORAGE_WRITE_FAILED',
      originalError: error,
    );
  }

  /// Database não inicializado
  factory StorageException.notInitialized() {
    return StorageException(
      'Database não foi inicializado',
      code: 'STORAGE_NOT_INITIALIZED',
    );
  }
}

/// Exceção relacionada à wallet
class WalletException extends AppException {
  WalletException(
    super.message, {
    super.code,
    super.originalError,
    super.stackTrace,
  });

  /// Saldo insuficiente
  factory WalletException.insufficientBalance(double required, double available) {
    return WalletException(
      'Saldo insuficiente: necessário $required, disponível $available',
      code: 'WALLET_INSUFFICIENT_BALANCE',
    );
  }

  /// Transação inválida
  factory WalletException.invalidTransaction(String reason) {
    return WalletException(
      'Transação inválida: $reason',
      code: 'WALLET_INVALID_TRANSACTION',
    );
  }

  /// Transação não encontrada
  factory WalletException.transactionNotFound(String txId) {
    return WalletException(
      'Transação não encontrada: $txId',
      code: 'WALLET_TRANSACTION_NOT_FOUND',
    );
  }
}

/// Exceção relacionada à reputação
class ReputationException extends AppException {
  ReputationException(
    super.message, {
    super.code,
    super.originalError,
    super.stackTrace,
  });

  /// Reputação insuficiente
  factory ReputationException.insufficientReputation(String userId, double required, double actual) {
    return ReputationException(
      'Reputação insuficiente para $userId: necessário $required, atual $actual',
      code: 'REPUTATION_INSUFFICIENT',
    );
  }

  /// Evento de confiança inválido
  factory ReputationException.invalidTrustEvent(String reason) {
    return ReputationException(
      'Evento de confiança inválido: $reason',
      code: 'REPUTATION_INVALID_TRUST_EVENT',
    );
  }
}
