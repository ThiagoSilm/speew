import 'dart:async';
import 'dart:typed_data';
import 'package:rede_p2p_refactored/core/crypto/crypto_manager.dart';
import 'package:rede_p2p_refactored/core/models/message.dart'; // Assumindo que MeshPacket é um tipo de Message
import 'package:rede_p2p_refactored/core/reputation/reputation_core.dart';
import 'package:rede_p2p_refactored/core/utils/logger_service.dart';

// Modelo simplificado para um Fixed Node
class FixedNode {
  final String id;
  final String address;
  final int port;
  double reputationScore;
  Duration latency;
  bool isConnected;

  FixedNode({
    required this.id,
    required this.address,
    required this.port,
    this.reputationScore = 0.0,
    this.latency = const Duration(milliseconds: -1),
    this.isConnected = false,
  });
}

class FixedNodeClient {
  final LoggerService _logger = LoggerService('FixedNodeClient');
  final CryptoManager _cryptoManager;
  final ReputationCore _reputationCore;
  FixedNode? _activeNode;
  StreamController<Uint8List> _packetStreamController = StreamController.broadcast();

  Stream<Uint8List> get incomingPackets => _packetStreamController.stream;

  FixedNodeClient(this._cryptoManager, this._reputationCore);

  // 1. Estabelecer e manter uma conexão persistente e criptografada
  Future<bool> connect(FixedNode node) async {
    _logger.info('Tentando conectar ao Fixed Node: ${node.address}:${node.port}');
    
    // Lógica de conexão simulada (TLS/TCP/UDP)
    try {
      // 1. Autenticação do nó local (usando chaves existentes)
      final authPayload = _cryptoManager.signData(Uint8List.fromList('AUTH_REQUEST'.codeUnits));
      
      // Simulação de handshake e estabelecimento de túnel seguro
      await Future.delayed(const Duration(milliseconds: 200)); 
      
      // 2. Verificar reputação mínima
      if (node.reputationScore < 0.95) {
        _logger.warning('FN ${node.id} rejeitado: Reputação (${node.reputationScore}) abaixo do mínimo (0.95).');
        return false;
      }

      _activeNode = node;
      _activeNode!.isConnected = true;
      _logger.success('Conexão estabelecida com sucesso com FN: ${node.id}');
      _startMonitoring();
      return true;
    } catch (e) {
      _logger.error('Falha ao conectar ao FN: $e');
      return false;
    }
  }

  void disconnect() {
    if (_activeNode != null) {
      _logger.info('Desconectando do Fixed Node: ${_activeNode!.id}');
      _activeNode!.isConnected = false;
      _activeNode = null;
      // Lógica de fechamento de socket
    }
  }

  // 2. Encapsular pacotes do protocolo Mesh em um túnel seguro
  Future<bool> sendPacket(Message meshPacket) async {
    if (_activeNode == null || !_activeNode!.isConnected) {
      _logger.warning('Não há Fixed Node ativo para enviar o pacote.');
      return false;
    }

    // 3. Tunelamento seguro (End-to-End Encrypted Tunneling)
    final encryptedPayload = _cryptoManager.encryptData(meshPacket.serialize(), _activeNode!.id);
    
    // Adicionar cabeçalho de tunelamento (simulado)
    final tunneledPacket = _addTunnelHeader(encryptedPayload);

    // Lógica de envio via Internet (TCP/UDP)
    _logger.debug('Enviando ${tunneledPacket.length} bytes via FN ${_activeNode!.id}');
    
    // Simulação de envio
    await Future.delayed(const Duration(milliseconds: 50)); 
    
    // Simulação de recebimento de ACK
    _reputationCore.recordTrustEvent(_activeNode!.id, TrustEvent.relaySuccess);
    return true;
  }

  Uint8List _addTunnelHeader(Uint8List payload) {
    // Implementação real incluiria metadados do túnel, como ID do FN, checksum, etc.
    return Uint8List.fromList([0xAA, 0xBB, ...payload]); 
  }

  // 4. Monitorar a latência e o uptime do FN
  void _startMonitoring() {
    Timer.periodic(const Duration(seconds: 10), (timer) async {
      if (_activeNode == null) {
        timer.cancel();
        return;
      }
      
      final stopwatch = Stopwatch()..start();
      // Simulação de ping/keep-alive
      await Future.delayed(const Duration(milliseconds: 50)); 
      stopwatch.stop();
      
      _activeNode!.latency = stopwatch.elapsed;
      _activeNode!.reputationScore = _reputationCore.getReputationScore(_activeNode!.id);
      
      _logger.debug('FN ${_activeNode!.id} - Latência: ${_activeNode!.latency.inMilliseconds}ms, Reputação: ${_activeNode!.reputationScore.toStringAsFixed(2)}');

      // Lógica de desconexão se o uptime falhar ou a latência for muito alta
      if (stopwatch.elapsed > const Duration(seconds: 5)) {
        _logger.warning('FN ${_activeNode!.id} com latência muito alta. Desconectando.');
        disconnect();
      }
    });
  }
}
