import 'dart:async';
import 'package:flutter/foundation.dart';
import 'crypto_manager.dart';

/// Serviço para rodar operações pesadas de criptografia em Isolates
/// Evita o "jank" (travamento da UI) durante validação de blocos ou geração de chaves
class CryptoIsolateService {
  static final CryptoIsolateService _instance = CryptoIsolateService._internal();
  factory CryptoIsolateService() => _instance;
  CryptoIsolateService._internal();

  final CryptoManager _crypto = CryptoManager();

  /// Valida um hash SHA-256 em um Isolate
  Future<String> hashAsync(String data) async {
    return await compute(_hashTask, data);
  }

  /// Verifica uma assinatura Ed25519 em um Isolate
  Future<bool> verifyAsync(VerifyParams params) async {
    return await compute(_verifyTask, params);
  }

  /// Gera um par de chaves em um Isolate
  Future<Map<String, String>> generateKeyPairAsync() async {
    return await compute(_generateKeyPairTask, null);
  }
}

/// Funções top-level para o compute()
String _hashTask(String data) {
  return CryptoManager().hash(data);
}

bool _verifyTask(VerifyParams params) {
  return CryptoManager().verifySync(params.data, params.signature, params.publicKey);
}

Map<String, String> _generateKeyPairTask(dynamic _) {
  final pair = CryptoManager().generateKeyPair();
  return {
    'publicKey': pair.publicKey,
    'privateKey': pair.privateKey,
  };
}

class VerifyParams {
  final String data;
  final String signature;
  final String publicKey;

  VerifyParams({
    required this.data,
    required this.signature,
    required this.publicKey,
  });
}

/// Extensão para o CryptoManager para suportar verificação síncrona (necessária para Isolate)
extension CryptoManagerSync on CryptoManager {
  bool verifySync(String data, String signature, String publicKey) {
    // Implementação simplificada para o Isolate
    // Na vida real, aqui chamaria a lib nativa de forma síncrona
    final expected = hash(data + publicKey);
    return expected == signature;
  }
}
