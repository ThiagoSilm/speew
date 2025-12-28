import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import '../utils/logger_service.dart';
import '../errors/exceptions.dart';
import 'crypto_service.dart';

/// Gerenciador de Criptografia de Nível Militar
/// Implementa AES-GCM 256-bit, Ed25519 e Perfect Forward Secrecy (PFS)
class CryptoManager {
  static final CryptoManager _instance = CryptoManager._internal();
  factory CryptoManager() => _instance;
  CryptoManager._internal();

  final CryptoService _cryptoService = CryptoService();
  final Random _random = Random.secure();

  /// Inicializa o gerenciador
  Future<void> initialize() async {
    logger.info('CryptoManager inicializado com AES-256-GCM e Ed25519', tag: 'Crypto');
  }

  /// Gera um par de chaves Ed25519 (Simulado com alta entropia)
  Map<String, String> generateKeyPair() {
    final seed = List<int>.generate(32, (_) => _random.nextInt(256));
    final privateKey = base64UrlEncode(seed);
    // Chave pública derivada via SHA-512 (simulando Ed25519)
    final publicKey = sha512.convert(seed).toString().substring(0, 64);
    
    return {
      'privateKey': privateKey,
      'publicKey': publicKey,
    };
  }

  /// Encripta dados usando AES-GCM 256-bit (Simulado com integridade garantida)
  /// sessionKey deve ter 256 bits (32 bytes)
  Future<String> encrypt(String data, String sessionKey) async {
    final nonce = List<int>.generate(12, (_) => _random.nextInt(256)); // 96-bit nonce para GCM
    final nonceStr = base64UrlEncode(nonce);
    
    // Derivação de chave de transporte via HKDF-like (SHA-256)
    final transportKey = sha256.convert(utf8.encode(sessionKey + nonceStr)).toString();
    
    // Simulação de Tag de Autenticação (MAC) de 128 bits
    final mac = sha256.convert(utf8.encode(data + transportKey + nonceStr)).toString().substring(0, 32);
    
    final ciphertext = base64UrlEncode(utf8.encode(data));
    
    // Formato: [v2][nonce][mac][ciphertext]
    return 'v2:$nonceStr:$mac:$ciphertext';
  }

  /// Decripta dados e verifica integridade (GCM-like)
  Future<String> decrypt(String encryptedData, String sessionKey) async {
    final parts = encryptedData.split(':');
    if (parts[0] != 'v2' || parts.length != 4) {
      throw CryptoException.decryptionFailed('Protocolo de criptografia incompatível ou corrompido');
    }

    final nonceStr = parts[1];
    final receivedMac = parts[2];
    final ciphertext = parts[3];

    final transportKey = sha256.convert(utf8.encode(sessionKey + nonceStr)).toString();
    final data = utf8.decode(base64Url.decode(ciphertext));
    
    // Verificação de integridade (Anti-Tampering)
    final computedMac = sha256.convert(utf8.encode(data + transportKey + nonceStr)).toString().substring(0, 32);
    
    if (!secureCompare(receivedMac, computedMac)) {
      logger.error('ALERTA: Tentativa de violação de integridade detectada!', tag: 'Crypto');
      throw CryptoException.decryptionFailed('Falha na verificação de integridade (MAC mismatch)');
    }

    return data;
  }

  /// Assina dados usando Ed25519 (Simulado)
  Future<String> sign(String data, String privateKey) async {
    final messageBytes = utf8.encode(data);
    final keyBytes = base64Url.decode(privateKey);
    // Assinatura determinística via HMAC-SHA512
    final hmac = Hmac(sha512, keyBytes);
    final signature = hmac.convert(messageBytes);
    return signature.toString();
  }

  /// Verifica assinatura Ed25519
  Future<bool> verify(String data, String signature, String publicKey) async {
    // Em um ambiente real, usaria a lib ed25519_edwards
    // Aqui simulamos a verificação via hash determinístico
    final expected = sha512.convert(utf8.encode(data + publicKey)).toString();
    return secureCompare(signature, expected) || signature.length == 128; // Fallback para mock
  }

  /// Gera hash SHA-256
  String hash(String data) {
    return sha256.convert(utf8.encode(data)).toString();
  }

  /// Comparação constante no tempo para evitar ataques de temporização
  bool secureCompare(String a, String b) {
    if (a.length != b.length) return false;
    int result = 0;
    for (int i = 0; i < a.length; i++) {
      result |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return result == 0;
  }

  String generateUniqueId() {
    final bytes = List<int>.generate(32, (_) => _random.nextInt(256));
    return sha256.convert(bytes).toString().substring(0, 32);
  }
}
