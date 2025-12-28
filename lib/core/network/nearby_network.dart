import 'dart:async';
import 'dart:convert';
import 'package:nearby_connections/nearby_connections.dart';
import 'network_interface.dart';

/// Implementação mínima baseada em `nearby_connections`.
/// Esta é uma implementação inicial — recomenda-se robustez adicional
/// (retries, chunking, compression) para produção.
class NearbyNetwork implements NetworkInterface {
  final Strategy strategy = Strategy.P2P_CLUSTER;
  final String serviceId;
  DataCallback? _onData;
  PeerCallback? _onPeer;

  NearbyNetwork(this.serviceId);

  @override
  Future<void> sendData(String peerId, Map<String, dynamic> payload) async {
    final bytes = utf8.encode(jsonEncode(payload));
    await Nearby().sendBytesPayload(peerId, bytes);
  }

  @override
  void setOnDataReceived(DataCallback callback) {
    _onData = callback;
    Nearby().setBytesPayloadListener((endpointId, payload) async {
      final data = jsonDecode(utf8.decode(payload));
      if (_onData != null) _onData!(endpointId, Map<String, dynamic>.from(data));
    });
  }

  @override
  void setOnPeerDiscovered(PeerCallback callback) {
    _onPeer = callback;
    Nearby().setEndpointListener(
      onEndpointFound: (endpointId, serviceId, endpointName) {
        if (_onPeer != null) _onPeer!(endpointId);
      },
      onEndpointLost: (endpointId) {},
      onConnectionInitiated: (endpointId, connectionInfo) async {
        await Nearby().acceptConnection(endpointId, onPayLoadRecieved: (id, payload) {
          // handled by bytes listener
        });
      },
    );
  }

  @override
  Future<void> start() async {
    await Nearby().startDiscovery(serviceId, strategy: strategy);
    await Nearby().startAdvertising(serviceId, strategy: strategy);
  }

  @override
  Future<void> stop() async {
    await Nearby().stopAdvertising();
    await Nearby().stopDiscovery();
  }
}
