import 'dart:async';
import 'package:rede_p2p_refactored/core/utils/logger_service.dart';

enum RotationTrigger { time, volume, event }

/// Serviço de Rotação Dinâmica de Chaves (DKR) para sessões P2P.
class KeyRotationService {
  final LoggerService _logger = LoggerService('KeyRotationService');
  
  // Regras de Rotação
  static const Duration _timeTrigger = Duration(minutes: 60);
  static const int _volumeTrigger = 100; // Pacotes
  
  // Estado
  final String _sessionId;
  int _packetsSent = 0;
  Timer? _rotationTimer;
  
  // Callback para a rotação real da chave
  final Future<void> Function() _onRotateKey;

  KeyRotationService(this._sessionId, this._onRotateKey) {
    _startTimer();
  }

  void _startTimer() {
    _rotationTimer?.cancel();
    _rotationTimer = Timer.periodic(_timeTrigger, (timer) {
      _logger.info('Gatilho de Tempo acionado. Rotacionando chave para sessão $_sessionId.', tag: 'DKR');
      _rotateKey(RotationTrigger.time);
    });
  }

  /// Registra o envio de um pacote e verifica o gatilho de volume.
  void recordPacketSent() {
    _packetsSent++;
    if (_packetsSent >= _volumeTrigger) {
      _logger.info('Gatilho de Volume acionado. Rotacionando chave para sessão $_sessionId.', tag: 'DKR');
      _rotateKey(RotationTrigger.volume);
    }
  }

  /// Força a rotação da chave por um evento externo (ex: falha de roteamento).
  Future<void> forceRotation(RotationTrigger trigger) async {
    if (trigger == RotationTrigger.time || trigger == RotationTrigger.volume) {
      _logger.warning('Tentativa de forçar rotação com gatilho inválido: $trigger');
      return;
    }
    _logger.info('Gatilho de Evento acionado. Forçando rotação de chave para sessão $_sessionId.', tag: 'DKR');
    await _rotateKey(trigger);
  }

  Future<void> _rotateKey(RotationTrigger trigger) async {
    try {
      await _onRotateKey();
      _logger.success('Rotação de chave concluída com sucesso. Gatilho: $trigger', tag: 'DKR');
      // Resetar contadores
      _packetsSent = 0;
      // Reiniciar o timer para o próximo ciclo
      _startTimer();
    } catch (e) {
      _logger.error('Falha na rotação de chave para sessão $_sessionId: $e', tag: 'DKR');
      // Tentar novamente após um curto período ou notificar o FailoverController
    }
  }

  // Status para UI
  Map<String, dynamic> getStatus() {
    return {
      'sessionId': _sessionId,
      'packetsSent': _packetsSent,
      'timeTrigger': _timeTrigger.inMinutes,
      'volumeTrigger': _volumeTrigger,
      'nextRotationIn': _rotationTimer?.tick ?? 'N/A',
    };
  }

  void dispose() {
    _rotationTimer?.cancel();
  }
}
