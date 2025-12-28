import 'dart:async';
import 'package:rede_p2p_refactored/core/cloud/fixed_node_client.dart';
import 'package:rede_p2p_refactored/core/cloud/fn_discovery_service.dart';
import 'package:rede_p2p_refactored/core/mesh/multipath_engine.dart';
import 'package:rede_p2p_refactored/core/models/message.dart';
import 'package:rede_p2p_refactored/core/utils/logger_service.dart';

enum ConnectionStatus { meshLocal, fixedNodeFallback, standalone }

class FailoverController {
  final LoggerService _logger = LoggerService('FailoverController');
  final MultiPathEngine _multiPathEngine;
  final FixedNodeClient _fixedNodeClient;
  final FNDiscoveryService _fnDiscoveryService;
  
  ConnectionStatus _status = ConnectionStatus.standalone;
  bool _isFallbackEnabled = true; // Toggle Manual: "Usar Fixed Nodes como Fallback"
  Timer? _meshTimeoutTimer;

  ConnectionStatus get status => _status;
  bool get isFallbackEnabled => _isFallbackEnabled;

  FailoverController(this._multiPathEngine, this._fixedNodeClient, this._fnDiscoveryService);

  void setFallbackEnabled(bool enabled) {
    _isFallbackEnabled = enabled;
    _logger.info('Fallback para Fixed Nodes ${enabled ? 'ativado' : 'desativado'}.');
    if (!enabled && _status == ConnectionStatus.fixedNodeFallback) {
      _fixedNodeClient.disconnect();
      _updateStatus(ConnectionStatus.standalone);
    }
  }

  void _updateStatus(ConnectionStatus newStatus) {
    if (_status != newStatus) {
      _status = newStatus;
      _logger.info('Status de Conexão Atualizado: $_status');
      // Notificar UI ou outros serviços sobre a mudança de status
    }
  }

  // Lógica Central: Preferência, Fallback, Transparência e Healing
  Future<bool> routePacket(Message packet) async {
    // 1. Preferência: Sempre tentar a rota Mesh Local primeiro.
    _logger.debug('Tentando rota Mesh Local...');
    
    // Inicia o timer de timeout para o Mesh Turbo Engine
    _meshTimeoutTimer?.cancel();
    _meshTimeoutTimer = Timer(const Duration(milliseconds: 500), () {
      // 2. Fallback: Se o Mesh Turbo Engine determinar que nenhuma rota local foi encontrada após 500ms
      if (_status != ConnectionStatus.meshLocal && _isFallbackEnabled) {
        _logger.warning('Timeout de 500ms para Mesh Local. Acionando Fallback para Fixed Node.');
        _attemptFixedNodeFallback(packet);
      }
    });

    // Simulação de tentativa de envio via Mesh
    final meshSuccess = await _multiPathEngine.tryRoute(packet);
    _meshTimeoutTimer?.cancel(); // Cancela o timer se a rota Mesh for encontrada rapidamente

    if (meshSuccess) {
      _updateStatus(ConnectionStatus.meshLocal);
      return true;
    }

    // Se a rota Mesh falhou imediatamente (ex: sem peers), tenta o fallback
    if (_isFallbackEnabled) {
      return _attemptFixedNodeFallback(packet);
    }

    _updateStatus(ConnectionStatus.standalone);
    _logger.error('Falha ao rotear pacote. Sem rota Mesh e Fallback desativado.');
    return false;
  }

  Future<bool> _attemptFixedNodeFallback(Message packet) async {
    if (_fixedNodeClient._activeNode == null || !_fixedNodeClient._activeNode!.isConnected) {
      _logger.info('Buscando Fixed Node de alta reputação para conexão...');
      final availableFNs = _fnDiscoveryService.getAvailableFixedNodes();
      
      if (availableFNs.isEmpty) {
        _logger.error('Nenhum Fixed Node disponível com reputação suficiente.');
        _updateStatus(ConnectionStatus.standalone);
        return false;
      }

      // Tenta conectar ao FN de maior reputação
      final selectedFN = availableFNs.first;
      final connected = await _fixedNodeClient.connect(selectedFN);
      
      if (!connected) {
        _logger.error('Falha ao conectar ao FN ${selectedFN.id}.');
        _updateStatus(ConnectionStatus.standalone);
        return false;
      }
    }

    // 3. Transparência: O Multi-Path Router trata o FN como um peer de altíssima reputação
    // O pacote é enviado via FixedNodeClient, que encapsula e envia pela Internet.
    final fnSuccess = await _fixedNodeClient.sendPacket(packet);

    if (fnSuccess) {
      _updateStatus(ConnectionStatus.fixedNodeFallback);
      return true;
    } else {
      _logger.error('Falha ao enviar pacote via Fixed Node.');
      _fixedNodeClient.disconnect();
      _updateStatus(ConnectionStatus.standalone);
      return false;
    }
  }

  // 4. Healing: Se o FixedNodeClient estiver ativo e a rede mesh local detectar novos peers próximos
  void checkMeshHealing(int nearbyPeersCount) {
    if (_status == ConnectionStatus.fixedNodeFallback && nearbyPeersCount > 0) {
      _logger.info('Mesh Healing detectado: $nearbyPeersCount peers próximos. Tentando reverter para Mesh Local.');
      
      // Simulação de verificação de qualidade da rota Mesh
      if (_multiPathEngine.canFindLocalRoute()) {
        _fixedNodeClient.disconnect();
        _updateStatus(ConnectionStatus.meshLocal);
        _logger.success('Reversão para Mesh Local bem-sucedida. Fixed Node desconectado.');
      } else {
        _logger.debug('Mesh Healing: Rota local ainda não ideal. Mantendo Fallback.');
      }
    }
  }
}

// Mocks necessários para compilação
class MultiPathEngine {
  Future<bool> tryRoute(Message packet) async {
    // Simulação: 70% de chance de falha para testar o fallback
    await Future.delayed(const Duration(milliseconds: 100));
    return false; // Simula falha inicial para acionar o timer/fallback
  }
  bool canFindLocalRoute() => true; // Simula que a rota local está disponível após o healing
}

class Message {
  final String content;
  Message(this.content);
  Uint8List serialize() => Uint8List.fromList(content.codeUnits);
}
