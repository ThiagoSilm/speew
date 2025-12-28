import '../../models/identity_rotation.dart';
import '../crypto/crypto_service.dart';
import 'package:uuid/uuid.dart';

/// Serviço de Rotação de Identidade
/// Gerencia a rotação periódica de chaves e IDs efêmeros para privacidade
class IdentityRotationService {
  static final IdentityRotationService _instance = IdentityRotationService._internal();
  factory IdentityRotationService() => _instance;
  IdentityRotationService._internal();

  final _crypto = CryptoService();
  final _uuid = const Uuid();
  
  /// Histórico de rotações do usuário local
  final List<IdentityRotation> _rotationHistory = [];
  
  /// Rotação atual ativa
  IdentityRotation? _currentRotation;
  
  /// Mapeamento de IDs efêmeros para IDs originais (privado)
  final Map<String, String> _ephemeralToOriginal = {};
  
  /// Mapeamento de reputação entre rotações
  final Map<String, double> _reputationMapping = {};

  // ==================== CRIAÇÃO DE ROTAÇÃO ====================

  /// Cria a primeira rotação de identidade
  Future<IdentityRotation> createInitialRotation({
    required String originalUserId,
    required String publicKey,
    required String privateKey,
    int validityPeriodDays = 30,
  }) async {
    final ephemeralId = _uuid.v4();
    final rotationTimestamp = DateTime.now();
    final expirationDate = rotationTimestamp.add(Duration(days: validityPeriodDays));
    
    // Assinar com a chave atual
    final signatureData = _getRotationSignatureData(
      rotationId: _uuid.v4(),
      originalUserId: originalUserId,
      currentEphemeralId: ephemeralId,
      currentPublicKey: publicKey,
      rotationSequence: 1,
      rotationTimestamp: rotationTimestamp,
    );
    
    final currentKeySignature = await _crypto.signData(signatureData, privateKey);
    
    final rotation = IdentityRotation(
      rotationId: _uuid.v4(),
      originalUserId: originalUserId,
      previousEphemeralId: null,
      currentEphemeralId: ephemeralId,
      previousPublicKey: null,
      currentPublicKey: publicKey,
      rotationTimestamp: rotationTimestamp,
      previousKeySignature: null,
      currentKeySignature: currentKeySignature,
      rotationSequence: 1,
      validityPeriodDays: validityPeriodDays,
      expirationDate: expirationDate,
      reputationCarryOver: null,
      status: 'active',
      notifiedPeers: [],
    );
    
    _currentRotation = rotation;
    _rotationHistory.add(rotation);
    _ephemeralToOriginal[ephemeralId] = originalUserId;
    
    return rotation;
  }

  /// Rotaciona a identidade (cria nova chave e ID efêmero)
  Future<IdentityRotation> rotateIdentity({
    required IdentityRotation currentRotation,
    required String currentPrivateKey,
    required double currentReputation,
    int validityPeriodDays = 30,
  }) async {
    if (!currentRotation.isActive) {
      throw Exception('Rotação atual não está ativa');
    }
    
    // Gerar novo par de chaves
    final newKeyPair = await _crypto.generateKeyPair();
    final newPublicKey = newKeyPair['publicKey']!;
    final newPrivateKey = newKeyPair['privateKey']!;
    
    // Gerar novo ID efêmero
    final newEphemeralId = _uuid.v4();
    
    final rotationTimestamp = DateTime.now();
    final expirationDate = rotationTimestamp.add(Duration(days: validityPeriodDays));
    
    // Assinar com a chave anterior (prova de continuidade)
    final signatureData = _getRotationSignatureData(
      rotationId: _uuid.v4(),
      originalUserId: currentRotation.originalUserId,
      currentEphemeralId: newEphemeralId,
      currentPublicKey: newPublicKey,
      rotationSequence: currentRotation.rotationSequence + 1,
      rotationTimestamp: rotationTimestamp,
    );
    
    final previousKeySignature = await _crypto.signData(signatureData, currentPrivateKey);
    final currentKeySignature = await _crypto.signData(signatureData, newPrivateKey);
    
    final newRotation = IdentityRotation(
      rotationId: _uuid.v4(),
      originalUserId: currentRotation.originalUserId,
      previousEphemeralId: currentRotation.currentEphemeralId,
      currentEphemeralId: newEphemeralId,
      previousPublicKey: currentRotation.currentPublicKey,
      currentPublicKey: newPublicKey,
      rotationTimestamp: rotationTimestamp,
      previousKeySignature: previousKeySignature,
      currentKeySignature: currentKeySignature,
      rotationSequence: currentRotation.rotationSequence + 1,
      validityPeriodDays: validityPeriodDays,
      expirationDate: expirationDate,
      reputationCarryOver: currentReputation,
      status: 'active',
      notifiedPeers: [],
    );
    
    // Expirar rotação anterior
    final expiredRotation = currentRotation.copyWith(status: 'expired');
    final index = _rotationHistory.indexWhere((r) => r.rotationId == currentRotation.rotationId);
    if (index != -1) {
      _rotationHistory[index] = expiredRotation;
    }
    
    // Adicionar nova rotação
    _currentRotation = newRotation;
    _rotationHistory.add(newRotation);
    _ephemeralToOriginal[newEphemeralId] = currentRotation.originalUserId;
    _reputationMapping[newEphemeralId] = currentReputation;
    
    return newRotation;
  }

  /// Rotaciona automaticamente se necessário
  Future<IdentityRotation?> autoRotateIfNeeded({
    required IdentityRotation currentRotation,
    required String currentPrivateKey,
    required double currentReputation,
  }) async {
    if (currentRotation.needsRotationSoon) {
      return await rotateIdentity(
        currentRotation: currentRotation,
        currentPrivateKey: currentPrivateKey,
        currentReputation: currentReputation,
      );
    }
    return null;
  }

  // ==================== VERIFICAÇÃO ====================

  /// Verifica a assinatura de uma rotação
  Future<bool> verifyRotationSignature({
    required IdentityRotation rotation,
    String? previousPublicKey,
  }) async {
    final signatureData = _getRotationSignatureData(
      rotationId: rotation.rotationId,
      originalUserId: rotation.originalUserId,
      currentEphemeralId: rotation.currentEphemeralId,
      currentPublicKey: rotation.currentPublicKey,
      rotationSequence: rotation.rotationSequence,
      rotationTimestamp: rotation.rotationTimestamp,
    );
    
    // Verificar assinatura da chave atual
    final currentValid = await _crypto.verifySignature(
      signatureData,
      rotation.currentKeySignature,
      rotation.currentPublicKey,
    );
    
    if (!currentValid) return false;
    
    // Se não é a primeira rotação, verificar assinatura da chave anterior
    if (!rotation.isFirstRotation && previousPublicKey != null && rotation.previousKeySignature != null) {
      final previousValid = await _crypto.verifySignature(
        signatureData,
        rotation.previousKeySignature!,
        previousPublicKey,
      );
      
      return previousValid;
    }
    
    return true;
  }

  /// Verifica a cadeia de rotações
  Future<bool> verifyRotationChain(List<IdentityRotation> rotations) async {
    if (rotations.isEmpty) return true;
    
    // Ordenar por sequência
    final sortedRotations = List<IdentityRotation>.from(rotations)
      ..sort((a, b) => a.rotationSequence.compareTo(b.rotationSequence));
    
    // Verificar sequência contínua
    for (int i = 0; i < sortedRotations.length; i++) {
      if (sortedRotations[i].rotationSequence != i + 1) {
        return false;
      }
      
      // Verificar continuidade de IDs efêmeros
      if (i > 0) {
        if (sortedRotations[i].previousEphemeralId != sortedRotations[i - 1].currentEphemeralId) {
          return false;
        }
        
        // Verificar assinatura com chave anterior
        final isValid = await verifyRotationSignature(
          rotation: sortedRotations[i],
          previousPublicKey: sortedRotations[i - 1].currentPublicKey,
        );
        
        if (!isValid) return false;
      }
    }
    
    return true;
  }

  // ==================== MAPEAMENTO ====================

  /// Resolve ID efêmero para ID original (privado)
  String? resolveEphemeralId(String ephemeralId) {
    return _ephemeralToOriginal[ephemeralId];
  }

  /// Obtém reputação mapeada de um ID efêmero
  double? getCarriedReputation(String ephemeralId) {
    return _reputationMapping[ephemeralId];
  }

  /// Adiciona peer notificado a uma rotação
  IdentityRotation addNotifiedPeer(IdentityRotation rotation, String peerId) {
    if (rotation.notifiedPeers.contains(peerId)) {
      return rotation;
    }
    
    final updatedPeers = [...rotation.notifiedPeers, peerId];
    return rotation.copyWith(notifiedPeers: updatedPeers);
  }

  // ==================== CONSULTAS ====================

  /// Obtém a rotação atual
  IdentityRotation? get currentRotation => _currentRotation;

  /// Obtém histórico de rotações
  List<IdentityRotation> get rotationHistory => List.unmodifiable(_rotationHistory);

  /// Obtém rotação por ID efêmero
  IdentityRotation? getRotationByEphemeralId(String ephemeralId) {
    try {
      return _rotationHistory.firstWhere(
        (r) => r.currentEphemeralId == ephemeralId,
      );
    } catch (e) {
      return null;
    }
  }

  /// Obtém todas as rotações de um usuário original
  List<IdentityRotation> getRotationsByOriginalId(String originalUserId) {
    return _rotationHistory
        .where((r) => r.originalUserId == originalUserId)
        .toList();
  }

  /// Verifica se precisa rotacionar em breve
  bool needsRotation() {
    if (_currentRotation == null) return false;
    return _currentRotation!.needsRotationSoon;
  }

  // ==================== FUNÇÕES AUXILIARES ====================

  /// Gera string canônica para assinatura de rotação
  String _getRotationSignatureData({
    required String rotationId,
    required String originalUserId,
    required String currentEphemeralId,
    required String currentPublicKey,
    required int rotationSequence,
    required DateTime rotationTimestamp,
  }) {
    return [
      rotationId,
      originalUserId,
      currentEphemeralId,
      currentPublicKey,
      rotationSequence.toString(),
      rotationTimestamp.toIso8601String(),
    ].join('|');
  }

  /// Reseta o serviço (para testes)
  void reset() {
    _rotationHistory.clear();
    _currentRotation = null;
    _ephemeralToOriginal.clear();
    _reputationMapping.clear();
  }
}
