import 'package:rede_p2p_refactored/core/reputation/reputation_core.dart';
import 'package:rede_p2p_refactored/core/utils/logger_service.dart';
import 'package:rede_p2p_refactored/lib/services/ledger/distributed_ledger_service.dart'; // Assumindo este caminho

/// Serviço de Validação de Certificados Mesh (Chaves Públicas de Longo Prazo).
class CertificateValidationService {
  final LoggerService _logger = LoggerService('CertValidationService');
  final ReputationCore _reputationCore;
  final DistributedLedgerService _ledgerService;

  // Cache de chaves revogadas
  final Set<String> _revokedKeys = {};

  CertificateValidationService(this._reputationCore, this._ledgerService);

  /// Valida a chave pública de longo prazo de um peer.
  Future<bool> validatePeerKey(String peerId, String publicKey) async {
    _logger.debug('Validando chave pública para $peerId...');

    // 1. Checar Revogação Local
    if (_revokedKeys.contains(publicKey)) {
      _logger.warning('Chave de $peerId revogada localmente.');
      return false;
    }

    // 2. Validação de Assinaturas (Simulação: Checar no Ledger)
    final isRegistered = await _ledgerService.isKeyRegistered(publicKey);
    if (!isRegistered) {
      _logger.warning('Chave de $peerId não registrada no Ledger.');
      return false;
    }

    // 3. Checar Reputação (Validação de Longo Prazo)
    final rs = _reputationCore.getReputationScore(peerId);
    if (rs <= 0.0) {
      _logger.error('Reputation Score de $peerId é 0%. Revogação obrigatória.');
      await revokePeerKey(peerId, publicKey, 'Reputation Score Zero');
      return false;
    }

    _logger.success('Chave de $peerId validada com sucesso. RS: ${rs.toStringAsFixed(2)}');
    return true;
  }

  /// Revoga o certificado mesh de um nó.
  Future<void> revokePeerKey(String peerId, String publicKey, String reason) async {
    _logger.critical('REVOGAÇÃO DE CHAVE: $peerId. Motivo: $reason');
    
    // 1. Adicionar ao cache local de revogação
    _revokedKeys.add(publicKey);

    // 2. Notificar o Ledger (mecanismo de revogação distribuído)
    await _ledgerService.recordKeyRevocation(publicKey, reason);

    // 3. Notificar o Reputation AI para garantir que o RS permaneça em 0%
    _reputationCore.forceSlashing(peerId, 'Revogação de Certificado');
  }

  /// Implementar um mecanismo para invalidar (revogar) o certificado mesh de um nó
  /// que tenha atingido um Reputation Score (RS) de 0% ou cometido uma Critical Offense.
  void checkAndRevokeByReputation(String peerId) {
    final rs = _reputationCore.getReputationScore(peerId);
    if (rs <= 0.0) {
      // Simulação: Obter a chave pública do peer (em um sistema real, seria do P2PService)
      final publicKey = 'KEY_OF_$peerId'; 
      revokePeerKey(peerId, publicKey, 'Reputation Score Zero (RS <= 0.0)');
    }
  }
}

// Mocks necessários para compilação
class DistributedLedgerService {
  Future<bool> isKeyRegistered(String publicKey) async => true;
  Future<void> recordKeyRevocation(String publicKey, String reason) async {}
}
