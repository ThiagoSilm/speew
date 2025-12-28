import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import '../utils/logger_service.dart';
import '../p2p/p2p_service.dart';
import '../models/message.dart';

/// Serviço de Stealth Total (Invisibilidade de Rede)
/// Implementa Traffic Padding, Decoy Traffic e Jitter de Transmissão
class StealthModeService {
  static final StealthModeService _instance = StealthModeService._internal();
  factory StealthModeService() => _instance;
  StealthModeService._internal();

  final Random _random = Random();
  bool _isEnabled = true;
  Timer? _decoyTimer;

  bool get isEnabled => _isEnabled;

  void setEnabled(bool value) {
    _isEnabled = value;
    if (_isEnabled) {
      _startDecoyTraffic();
    } else {
      _decoyTimer?.cancel();
    }
    logger.info('Modo Stealth ${_isEnabled ? 'ATIVADO' : 'DESATIVADO'}', tag: 'Stealth');
  }

  /// Inicia o tráfego de isca (Decoy Traffic)
  /// Envia pacotes aleatórios para ofuscar o padrão de comunicação real
  void _startDecoyTraffic() {
    _decoyTimer?.cancel();
    _decoyTimer = Timer.periodic(Duration(seconds: _random.nextInt(30) + 10), (_) {
      if (!_isEnabled) return;
      
      _sendDecoyPacket();
    });
  }

  void _sendDecoyPacket() {
    final fakeMessage = P2PMessage(
      messageId: 'decoy_${_random.nextInt(1000000)}',
      senderId: 'ghost',
      receiverId: 'broadcast',
      type: 'decoy_ping',
      payload: {'entropy': _random.nextDouble().toString()},
    );

    // Envia sem passar pela fila de prioridade normal para não atrapalhar o tráfego real
    P2PService().sendDataRaw(
      'broadcast',
      fakeMessage,
      priority: PacketPriority.bulk, // Baixa prioridade para o decoy
    );
    
    logger.debug('Pacote decoy enviado para ofuscação de tráfego', tag: 'Stealth');
  }

  /// Aplica Padding para que todos os pacotes tenham o mesmo tamanho visual na rede
  Uint8List applyPadding(Uint8List data, {int targetSize = 1024}) {
    if (!_isEnabled || data.length >= targetSize) return data;

    final paddedData = Uint8List(targetSize);
    paddedData.setRange(0, data.length, data);
    
    // Preenche o resto com ruído aleatório em vez de zeros (mais difícil de comprimir/detectar)
    for (var i = data.length; i < targetSize; i++) {
      paddedData[i] = _random.nextInt(256);
    }
    
    return paddedData;
  }

  /// Adiciona um atraso aleatório (Jitter) para quebrar padrões temporais de envio
  Future<void> applyJitter() async {
    if (!_isEnabled) return;
    
    final ms = _random.nextInt(150) + 20; // 20ms a 170ms de atraso
    await Future.delayed(Duration(milliseconds: ms));
  }
}
