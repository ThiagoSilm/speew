import 'dart:async';
import 'dart:convert';

import 'package:speew/core/network/network_interface.dart';
import 'package:speew/core/mesh/mesh_block.dart';
import 'package:speew/core/mesh/mesh_ledger_service.dart';
import 'package:speew/core/db/database_service.dart';
import 'package:speew/core/utils/logger_service.dart';

import 'package:speew/core/power/energy_manager.dart';

class GossipPropagationService {
  final MeshLedgerService _ledger;
  final NetworkInterface _network;
  final DatabaseService _db;
  final EnergyManager _energyManager = EnergyManager();
  
  Timer? _gossipTimer;
  EnergyProfile _currentProfile = EnergyProfile.balancedMode;

  GossipPropagationService(this._ledger, this._network, this._db) {
    _network.setOnPeerDiscovered(_onPeerDiscovered);
    _network.setOnDataReceived(_handleIncomingData);
    
    // Escuta mudanças no perfil de energia para ajustar o ritmo do Gossip
    _energyManager.currentProfile.listen((profile) {
      _currentProfile = profile;
      _adjustGossipInterval();
    });
  }

  void _adjustGossipInterval() {
    _gossipTimer?.cancel();
    
    Duration interval;
    switch (_currentProfile) {
      case EnergyProfile.highPerformanceMesh:
        interval = const Duration(seconds: 2); // Rápido
        break;
      case EnergyProfile.balancedMode:
        interval = const Duration(seconds: 10); // Normal
        break;
      case EnergyProfile.lowBatteryMode:
        interval = const Duration(seconds: 60); // Lento para poupar bateria
        break;
      case EnergyProfile.deepBackgroundRelayMode:
        interval = const Duration(minutes: 5); // Mínimo possível
        break;
    }
    
    _gossipTimer = Timer.periodic(interval, (_) => _performGossipCycle());
    logger.info('Intervalo de Gossip ajustado para ${interval.inSeconds}s (Perfil: ${_currentProfile.name})', tag: 'Gossip');
  }

  void _performGossipCycle() async {
    final peer = await _db.getRandomPeer();
    if (peer != null) {
      _onPeerDiscovered(peer.peerId);
    }
  }

  Future<void> start() async {
    await _network.start();
  }

  Future<void> stop() async {
    await _network.stop();
  }

  void _onPeerDiscovered(String peerId) {
    try {
      final lastIndex = _ledger.chain.last.index;
      _network.sendData(peerId, {'type': 'LEDGER_INVENTORY', 'last_index': lastIndex});
    } catch (e, st) {
      logger.logCritical('Error in onPeerDiscovered: $e', st);
    }
  }

  void _handleIncomingData(String senderId, Map<String, dynamic> data) async {
    try {
      final type = data['type'] as String?;
      if (type == 'LEDGER_INVENTORY') {
        final remoteIndex = (data['last_index'] as num).toInt();
        final localIndex = _ledger.chain.last.index;
        if (localIndex > remoteIndex) {
          _sendMissingBlocks(senderId, remoteIndex + 1);
        }
      } else if (type == 'BLOCK_DATA') {
        final blockJson = Map<String, dynamic>.from(data['block'] as Map);
        final newBlock = MeshBlock.fromJson(blockJson);

        // Validate previous hash matches our latest or is future (we only accept next index)
        final expectedIndex = _ledger.chain.last.index + 1;
        if (newBlock.index != expectedIndex) {
          logger.logCritical('Received out-of-order block from $senderId: expected $expectedIndex got ${newBlock.index}', StackTrace.current);
          return;
        }

        final added = await _ledger.addBlock(newBlock);
        if (added) {
          // persist atomically
          await _db.persistMeshBlockAtomic(newBlock.toMap());
        } else {
          logger.logCritical('Rejected block from $senderId (validation failed): ${newBlock.hash}', StackTrace.current);
        }
      }
    } catch (e, st) {
      logger.logCritical('Error handling incoming gossip data: $e', st);
    }
  }

  void _sendMissingBlocks(String receiverId, int startIndex) {
    for (var i = startIndex; i < _ledger.chain.length; i++) {
      final block = _ledger.chain[i];
      _network.sendData(receiverId, {'type': 'BLOCK_DATA', 'block': block.toJson()});
    }
  }
}
