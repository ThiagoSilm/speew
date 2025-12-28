typedef DataCallback = void Function(String senderId, Map<String, dynamic> data);
typedef PeerCallback = void Function(String peerId);

/// Abstração mínima de interface de rede para Gossip (BT/Wi-Fi)
abstract class NetworkInterface {
  /// Envia um payload (map) serializável para um peer específico
  Future<void> sendData(String peerId, Map<String, dynamic> payload);

  /// Callback quando dados são recebidos
  void setOnDataReceived(DataCallback callback);

  /// Callback quando um peer é descoberto
  void setOnPeerDiscovered(PeerCallback callback);

  /// Starts the underlying discovery/advertising
  Future<void> start();

  /// Stops discovery/advertising
  Future<void> stop();
}
