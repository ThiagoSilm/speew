import 'dart:convert';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import '../utils/logger_service.dart';

/// Serviço de Handshake ECDH para estabelecer segredos compartilhados
/// Implementa o protocolo de troca de chaves Elliptic Curve Diffie-Hellman
/// 
/// PROTOCOLO:
/// 1. Cada peer gera um par de chaves ECDH (pública/privada)
/// 2. Peers trocam chaves públicas via payload IDENTITY_EXCHANGE
/// 3. Cada peer calcula o shared secret usando sua chave privada e a chave pública do outro
/// 4. O shared secret é usado como chave AES-256 para criptografia de sessão
class EcdhHandshakeService {
  static final EcdhHandshakeService _instance = EcdhHandshakeService._internal();
  factory EcdhHandshakeService() => _instance;
  EcdhHandshakeService._internal();

  final _algorithm = X25519();
  
  // Armazena pares de chaves locais por sessão
  final Map<String, SimpleKeyPair> _localKeyPairs = {};
  
  // Armazena shared secrets calculados por peer
  final Map<String, SecretKey> _sharedSecrets = {};
  
  // CORREÇÃO: Controle de expiração de chaves (PFS)
  final Map<String, DateTime> _keyCreationTimes = {};
  static const Duration _keyRotationInterval = Duration(hours: 1); // Rotação a cada 1 hora

  // ==================== GERAÇÃO DE CHAVES ====================

  /// Gera um novo par de chaves ECDH para uma sessão
  /// Retorna a chave pública em base64
  Future<String> generateKeyPair(String sessionId) async {
    try {
      final keyPair = await _algorithm.newKeyPair();
      _localKeyPairs[sessionId] = keyPair;
      
      final publicKey = await keyPair.extractPublicKey();
      final publicKeyBytes = publicKey.bytes;
      
      logger.info('Par de chaves ECDH gerado para sessão: $sessionId', tag: 'ECDH');
      return base64Encode(publicKeyBytes);
    } catch (e) {
      logger.error('Erro ao gerar par de chaves ECDH', tag: 'ECDH', error: e);
      rethrow;
    }
  }

  // ==================== CÁLCULO DE SHARED SECRET ====================

  /// Calcula o shared secret usando a chave pública do peer remoto
  /// O shared secret é armazenado internamente e pode ser usado para criptografia
  Future<void> computeSharedSecret(
    String sessionId,
    String peerId,
    String remotePeerPublicKeyBase64,
  ) async {
    try {
      // Recuperar par de chaves local
      final localKeyPair = _localKeyPairs[sessionId];
      if (localKeyPair == null) {
        throw Exception('Par de chaves local não encontrado para sessão: $sessionId');
      }

      // Decodificar chave pública remota
      final remotePeerPublicKeyBytes = base64Decode(remotePeerPublicKeyBase64);
      final remotePeerPublicKey = SimplePublicKey(
        remotePeerPublicKeyBytes,
        type: KeyPairType.x25519,
      );

      // Calcular shared secret
      final sharedSecret = await _algorithm.sharedSecretKey(
        keyPair: localKeyPair,
        remotePublicKey: remotePeerPublicKey,
      );

      // Armazenar shared secret e timestamp de criação
      _sharedSecrets[peerId] = sharedSecret;
      _keyCreationTimes[peerId] = DateTime.now();
      
      logger.info('Shared secret calculado para peer: $peerId (PFS Ativo)', tag: 'ECDH');
    } catch (e) {
      logger.error('Erro ao calcular shared secret', tag: 'ECDH', error: e);
      rethrow;
    }
  }

  // ==================== RECUPERAÇÃO DE SHARED SECRET ====================

  /// Recupera o shared secret para um peer específico
  /// Retorna null se o shared secret não foi calculado ou se expirou (PFS)
  SecretKey? getSharedSecret(String peerId) {
    if (_isKeyExpired(peerId)) {
      _cleanupKey(peerId);
      return null;
    }
    return _sharedSecrets[peerId];
  }

  bool _isKeyExpired(String peerId) {
    final creationTime = _keyCreationTimes[peerId];
    if (creationTime == null) return true;
    return DateTime.now().difference(creationTime) > _keyRotationInterval;
  }

  void _cleanupKey(String peerId) {
    _sharedSecrets.remove(peerId);
    _keyCreationTimes.remove(peerId);
    logger.warn('Chave expirada e removida para peer: $peerId (PFS Rotation)', tag: 'ECDH');
  }

  /// Recupera o shared secret como bytes (para uso com AES-GCM)
  /// Retorna null se o shared secret não foi calculado ainda
  Future<Uint8List?> getSharedSecretBytes(String peerId) async {
    final sharedSecret = _sharedSecrets[peerId];
    if (sharedSecret == null) return null;
    
    final bytes = await sharedSecret.extractBytes();
    return Uint8List.fromList(bytes);
  }

  // ==================== LIMPEZA ====================

  /// Remove dados de sessão quando a conexão é encerrada
  void cleanupSession(String sessionId, String peerId) {
    _localKeyPairs.remove(sessionId);
    _sharedSecrets.remove(peerId);
    logger.info('Sessão ECDH limpa: $sessionId (peer: $peerId)', tag: 'ECDH');
  }

  /// Limpa todos os dados de sessão (útil para reset completo)
  void cleanupAll() {
    _localKeyPairs.clear();
    _sharedSecrets.clear();
    logger.info('Todas as sessões ECDH limpas', tag: 'ECDH');
  }

  // ==================== UTILITÁRIOS ====================

  /// Verifica se um shared secret existe para um peer
  bool hasSharedSecret(String peerId) {
    return _sharedSecrets.containsKey(peerId);
  }

  /// Retorna o número de sessões ativas
  int get activeSessionsCount => _localKeyPairs.length;

  /// Retorna o número de shared secrets calculados
  int get sharedSecretsCount => _sharedSecrets.length;
}

// ==================== MODELOS DE PAYLOAD ====================

/// Payload para troca de identidade (IDENTITY_EXCHANGE)
class IdentityExchangePayload {
  final String type = 'IDENTITY_EXCHANGE';
  final String publicKey;
  final String timestamp;
  final String? displayName;

  IdentityExchangePayload({
    required this.publicKey,
    required this.timestamp,
    this.displayName,
  });

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'publicKey': publicKey,
      'timestamp': timestamp,
      if (displayName != null) 'displayName': displayName,
    };
  }

  factory IdentityExchangePayload.fromJson(Map<String, dynamic> json) {
    return IdentityExchangePayload(
      publicKey: json['publicKey'] as String,
      timestamp: json['timestamp'] as String,
      displayName: json['displayName'] as String?,
    );
  }

  String toJsonString() => jsonEncode(toJson());

  factory IdentityExchangePayload.fromJsonString(String jsonString) {
    return IdentityExchangePayload.fromJson(jsonDecode(jsonString));
  }
}
