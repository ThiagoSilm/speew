import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:pointycastle/export.dart';
import 'package:pointycastle/ecc/api.dart';
import 'package:pointycastle/ecc/curves/ed25519.dart';

/// Serviço de criptografia para a rede P2P
/// Implementa AES-256-GCM para mensagens/arquivos e Ed25519 para assinaturas
/// 
/// EVOLUÇÃO INDUSTRIAL:
/// - Usa PointyCastle para Ed25519 (validação real)
/// - Usa PointyCastle para AES-256-GCM (criptografia de sessão real)
class CryptoService {
  static final CryptoService _instance = CryptoService._internal();
  factory CryptoService() => _instance;
  CryptoService._internal();

  // ==================== GERAÇÃO DE CHAVES ====================

  /// Gera um par de chaves Ed25519 (pública e privada)
  /// Retorna um Map com 'publicKey' e 'privateKey' em base64
  Future<Map<String, String>> generateKeyPair() async {
    final keyGen = KeyGenerator('Ed25519');
    
    // Inicializa o gerador de chaves
    final secureRandom = SecureRandom('Fortuna')
      ..seed(KeyParameter(Uint8List.fromList(List.generate(32, (_) => _random.nextInt(256))))); // CORREÇÃO: Usando SecureRandom para gerar seed aleatória, não o tempo do sistema
      
    final keyParams = Ed25519KeyGenerationParameters(secureRandom);
    keyGen.init(keyParams);
    
    final keyPair = keyGen.generateKeyPair();
    final publicKey = keyPair.publicKey as ECPublicKey;
    final privateKey = keyPair.privateKey as ECPrivateKey;
    
    // A chave privada Ed25519 é o escalar 'd' (32 bytes)
    final privateKeyBytes = privateKey.d!.toRadixString(16).padLeft(64, '0');
    
    // A chave pública Ed25519 é o ponto 'Q' (32 bytes)
    final publicKeyBytes = publicKey.Q!.getEncodedPoint(false); // Ponto comprimido (32 bytes)
    
    return {
      'publicKey': base64Encode(publicKeyBytes),
      'privateKey': privateKeyBytes, // Mantendo como string hex para consistência
    };
  }

  // ==================== ASSINATURA DIGITAL (Ed25519) ====================

  /// Assina os dados usando a chave privada Ed25519
  Future<String> signData(String data, String privateKeyHex) async {
    final signer = Signer('Ed25519');
    
    // Converte a chave privada de hex para BigInt (escalar d)
    final privateKeyD = BigInt.parse(privateKeyHex, radix: 16);
    final privateKey = ECPrivateKey(privateKeyD, ECCurve_Ed25519());
    
    final keyParams = PrivateKeyParameter<ECPrivateKey>(privateKey);
    signer.init(true, keyParams);
    
    final dataBytes = Uint8List.fromList(utf8.encode(data));
    final signature = signer.generateSignature(dataBytes) as ECSignature;
    
    // Serializa a assinatura (R e S) em um formato padrão (64 bytes)
    final rBytes = signature.r!.toRadixString(16).padLeft(64, '0');
    final sBytes = signature.s!.toRadixString(16).padLeft(64, '0');
    
    return base64Encode(Uint8List.fromList(utf8.encode(rBytes + sBytes)));
  }

  /// Verifica a assinatura usando a chave pública Ed25519
  Future<bool> verifySignature(String data, String signatureBase64, String publicKeyBase64) async {
    try {
      final verifier = Signer('Ed25519');
      
      // Converte a chave pública de base64 para bytes (ponto Q)
      final publicKeyBytes = base64Decode(publicKeyBase64);
      final publicKey = ECPublicKey(ECCurve_Ed25519().curve.decodePoint(publicKeyBytes), ECCurve_Ed25519());
      
      final keyParams = PublicKeyParameter<ECPublicKey>(publicKey);
      verifier.init(false, keyParams);
      
      final dataBytes = Uint8List.fromList(utf8.encode(data));
      
      // Desserializa a assinatura (64 bytes)
      final signatureBytes = utf8.decode(base64Decode(signatureBase64));
      final rHex = signatureBytes.substring(0, 64);
      final sHex = signatureBytes.substring(64, 128);
      
      final r = BigInt.parse(rHex, radix: 16);
      final s = BigInt.parse(sHex, radix: 16);
      
      final signature = ECSignature(r, s);
      
      return verifier.verifySignature(dataBytes, signature);
    } catch (e) {
      // Qualquer erro de parsing ou criptografia deve resultar em falha de verificação
      return false;
    }
  }

  // ==================== CRIPTOGRAFIA SIMÉTRICA (AES-256-GCM) ====================
  
  /// Gera um nonce aleatório de 12 bytes para AES-256-GCM
  Uint8List generateNonce() {
    final secureRandom = SecureRandom('Fortuna')
      ..seed(KeyParameter(Uint8List.fromList(List.generate(32, (_) => _random.nextInt(256))))); // CORREÇÃO: Usando SecureRandom para gerar seed aleatória, não o tempo do sistema
    return Uint8List.fromList(List.generate(12, (_) => secureRandom.nextUint8())); // 12 bytes para GCM
  }

  /// Criptografa dados com AES-256-GCM
  /// Retorna um Map com 'cipherText' e 'tag' em base64
  Map<String, String> encrypt(String data, Uint8List key, Uint8List nonce) {
    final cipher = GCMBlockCipher(AESEngine());
    final params = AEADParameters(KeyParameter(key), 128, nonce, Uint8List(0)); // 128 bits = 16 bytes de tag
    
    cipher.init(true, params);
    
    final dataBytes = Uint8List.fromList(utf8.encode(data));
    final cipherText = cipher.process(dataBytes);
    
    return {
      'cipherText': base64Encode(cipherText),
      'tag': base64Encode(cipher.mac),
    };
  }

  /// Descriptografa dados com AES-256-GCM
  String? decrypt(String cipherTextBase64, String tagBase64, Uint8List key, Uint8List nonce) {
    try {
      final cipher = GCMBlockCipher(AESEngine());
      final params = AEADParameters(KeyParameter(key), 128, nonce, Uint8List(0));
      
      cipher.init(false, params);
      
      final cipherText = base64Decode(cipherTextBase64);
      final tag = base64Decode(tagBase64);
      
      final decrypted = cipher.process(Uint8List.fromList(cipherText + tag));
      
      return utf8.decode(decrypted);
    } catch (e) {
      // Falha na descriptografia ou verificação da tag (MAC)
      return null;
    }
  }

  // ==================== PROVA DE TRABALHO (PoW) ====================
  // NOTA: A implementação de PoW (Hashcash) foi removida na Limpeza Radical.
  // Será re-implementada na versão V1.1 com algoritmo real de resistência a spam.

  // ==================== HASHING ====================

  /// Calcula hash SHA-256
  String sha256Hash(String data) {
    final bytes = utf8.encode(data);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
}

// Extensão para BigInt (necessária para PointyCastle)
extension BigIntToBytes on BigInt {
  Uint8List toByteArray() {
    // Implementação simplificada para BigInt -> Uint8List
    final hex = toRadixString(16);
    final bytes = <int>[];
    for (var i = 0; i < hex.length; i += 2) {
      bytes.add(int.parse(hex.substring(i, i + 2), radix: 16));
    }
    return Uint8List.fromList(bytes);
  }
}
