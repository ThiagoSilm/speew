import 'dart:convert';
import 'dart:typed_data';
import 'package:pointycastle/export.dart';
import 'package:pointycastle/ecc/api.dart';
import 'package:pointycastle/ecc/curves/curve25519.dart';
import 'package:pointycastle/api.dart';
import '../../core/crypto/crypto_service.dart';

/// Serviço de Handshake Criptográfico P2P (ECDH-P2P)
/// Responsável por estabelecer um túnel seguro (TLS-like) usando ECDH e Ed25519.
class SecureChannelService {
  static final SecureChannelService _instance = SecureChannelService._internal();
  factory SecureChannelService() => _instance;
  SecureChannelService._internal();

  final _crypto = CryptoService();
  final _ecdh = ECDHBasicAgreement();
  final _curve = ECCurve_curve25519(); // Curva padrão para ECDH (Curve25519)
  
  // Simulação de chaves de longo prazo do nó local
  final String _localPeerId = 'LOCAL_PEER_ID_A';
  final String _localPrivateKey = '0000000000000000000000000000000000000000000000000000000000000001'; // Exemplo
  final String _localPublicKey = 'PUBLIC_KEY_A'; // Exemplo

  // ==================== PASSO 1: GERAÇÃO DE CHAVES EFÊMERAS ====================

  /// Gera um par de chaves ECDH efêmeras (Curve25519)
  AsymmetricKeyPair<ECPublicKey, ECPrivateKey> _generateEphemeralKeyPair() {
    final keyGen = ECKeyPairGenerator('EC');
    
    final secureRandom = SecureRandom('Fortuna')
      ..seed(KeyParameter(Uint8List.fromList(List.generate(32, (_) => DateTime.now().microsecondsSinceEpoch % 256))));
      
    final keyParams = ECKeyGeneratorParameters(_curve);
    keyGen.init(ParametersWithRandom(keyParams, secureRandom));
    
    return keyGen.generateKeyPair();
  }

  // ==================== PASSO 2-5: HANDSHAKE (CLIENTE) ====================

  /// Inicia o Handshake como cliente (quem se conecta)
  Future<Map<String, dynamic>> initiateHandshake() async {
    // 1. Geração de chaves efêmeras
    final ephemeralKeyPair = _generateEphemeralKeyPair();
    final ephemeralPublicKey = ephemeralKeyPair.publicKey as ECPublicKey;
    final ephemeralPrivateKey = ephemeralKeyPair.privateKey as ECPrivateKey;
    
    // 2. Assinatura da chave pública efêmera com a chave de longo prazo (Identidade)
    final ephemeralPubKeyBytes = ephemeralPublicKey.Q!.getEncodedPoint(false);
    final signature = await _crypto.signData(base64Encode(ephemeralPubKeyBytes), _localPrivateKey);
    
    // 3. Payload de Handshake (Passo 1)
    final handshakePayload = {
      'step': 1,
      'peerId': _localPeerId,
      'ephemeralPubKey': base64Encode(ephemeralPubKeyBytes),
      'signature': signature,
      'longTermPubKey': _localPublicKey,
    };
    
    // Simulação: Enviar payload e receber resposta do peer
    // Na vida real, isso seria enviado pelo socket e a resposta lida
    final remotePayload = await _simulateP2PExchange(json.encode(handshakePayload));
    
    if (remotePayload == null) {
      throw Exception('Handshake falhou: Nenhuma resposta do peer.');
    }
    
    final remoteHandshake = json.decode(remotePayload);
    
    // 4. Processar resposta do peer (Passo 2)
    final remoteEphemeralPubKeyBytes = base64Decode(remoteHandshake['ephemeralPubKey']);
    final remoteSignature = remoteHandshake['signature'] as String;
    final remoteLongTermPubKey = remoteHandshake['longTermPubKey'] as String;
    
    // 5. Verificação de Identidade Remota
    final isVerified = await _crypto.verifySignature(
      base64Encode(remoteEphemeralPubKeyBytes), 
      remoteSignature, 
      remoteLongTermPubKey
    );
    
    if (!isVerified) {
      throw Exception('Handshake falhou: Assinatura de identidade remota inválida.');
    }
    
    // 6. Cálculo do Segredo Compartilhado (ECDH)
    final remoteEphemeralPoint = _curve.curve.decodePoint(remoteEphemeralPubKeyBytes);
    final remoteEphemeralPublicKey = ECPublicKey(remoteEphemeralPoint, _curve);
    
    _ecdh.init(ephemeralPrivateKey);
    final sharedSecret = _ecdh.calculateAgreement(remoteEphemeralPublicKey);
    
    // 7. Derivação da Chave de Sessão (AES-256)
    final sessionKey = _deriveSessionKey(sharedSecret);
    
    return {
      'sessionKey': sessionKey,
      'remotePeerId': remoteHandshake['peerId'],
    };
  }

  // ==================== PASSO 2-5: HANDSHAKE (SERVIDOR) ====================

  /// Responde ao Handshake como servidor (quem aceita a conexão)
  Future<String> respondToHandshake(String incomingPayload) async {
    final incomingHandshake = json.decode(incomingPayload);
    
    // 1. Processar requisição do peer (Passo 1)
    final remoteEphemeralPubKeyBytes = base64Decode(incomingHandshake['ephemeralPubKey']);
    final remoteSignature = incomingHandshake['signature'] as String;
    final remoteLongTermPubKey = incomingHandshake['longTermPubKey'] as String;
    
    // 2. Verificação de Identidade Remota
    final isVerified = await _crypto.verifySignature(
      base64Encode(remoteEphemeralPubKeyBytes), 
      remoteSignature, 
      remoteLongTermPubKey
    );
    
    if (!isVerified) {
      throw Exception('Handshake falhou: Assinatura de identidade remota inválida.');
    }
    
    // 3. Geração de chaves efêmeras locais
    final ephemeralKeyPair = _generateEphemeralKeyPair();
    final ephemeralPublicKey = ephemeralKeyPair.publicKey as ECPublicKey;
    final ephemeralPrivateKey = ephemeralKeyPair.privateKey as ECPrivateKey;
    
    // 4. Assinatura da chave pública efêmera com a chave de longo prazo (Identidade)
    final ephemeralPubKeyBytes = ephemeralPublicKey.Q!.getEncodedPoint(false);
    final signature = await _crypto.signData(base64Encode(ephemeralPubKeyBytes), _localPrivateKey);
    
    // 5. Cálculo do Segredo Compartilhado (ECDH)
    final remoteEphemeralPoint = _curve.curve.decodePoint(remoteEphemeralPubKeyBytes);
    final remoteEphemeralPublicKey = ECPublicKey(remoteEphemeralPoint, _curve);
    
    _ecdh.init(ephemeralPrivateKey);
    final sharedSecret = _ecdh.calculateAgreement(remoteEphemeralPublicKey);
    
    // 6. Derivação da Chave de Sessão (AES-256)
    final sessionKey = _deriveSessionKey(sharedSecret);
    
    // 7. Payload de Resposta (Passo 2)
    final responsePayload = {
      'step': 2,
      'peerId': _localPeerId,
      'ephemeralPubKey': base64Encode(ephemeralPubKeyBytes),
      'signature': signature,
      'longTermPubKey': _localPublicKey,
      'sessionKey': base64Encode(sessionKey), // Apenas para simulação/debug
    };
    
    return json.encode(responsePayload);
  }

  // ==================== DERIVAÇÃO DE CHAVE ====================

  /// Deriva a chave de sessão simétrica (AES-256) a partir do segredo compartilhado
  Uint8List _deriveSessionKey(BigInt sharedSecret) {
    // Usar KDF (Key Derivation Function) como HKDF ou simplesmente SHA-256
    final secretBytes = Uint8List.fromList(sharedSecret.toByteArray());
    final digest = SHA256Digest().process(secretBytes);
    
    // Retorna os primeiros 32 bytes (256 bits) para AES-256
    return digest.sublist(0, 32);
  }

  // ==================== SIMULAÇÃO DE COMUNICAÇÃO P2P ====================

  /// Simula a troca de mensagens P2P (na vida real, seria o socket)
  Future<String?> _simulateP2PExchange(String payload) async {
    // Simulação de resposta do peer remoto (que seria o servidor)
    await Future.delayed(Duration(milliseconds: 100));
    return respondToHandshake(payload);
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
