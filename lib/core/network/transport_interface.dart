import 'dart:typed_data';

/// Enumeração dos tipos de transporte suportados
enum TransportType {
  wifiDirect,
  bluetoothLE,
  bluetoothClassic,
  lora, // Futuro
  radio, // Futuro
}

/// Interface base para qualquer meio de transporte no Speew
abstract class ITransport {
  TransportType get type;
  bool get isAvailable;
  bool get isConnected;

  Future<void> initialize();
  Future<void> startDiscovery();
  Future<void> stopDiscovery();
  
  /// Envia dados brutos para um endereço específico do meio
  Future<bool> sendData(String address, Uint8List data);
  
  /// Stream de dados recebidos: (address, data)
  Stream<MapEntry<String, Uint8List>> get onDataReceived;

  Future<void> dispose();
}

/// Gerenciador de Transportes (Orquestrador)
class TransportManager {
  static final TransportManager _instance = TransportManager._internal();
  factory TransportManager() => _instance;
  TransportManager._internal();

  final List<ITransport> _transports = [];

  void registerTransport(ITransport transport) {
    _transports.add(transport);
  }

  List<ITransport> get availableTransports => _transports.where((t) => t.isAvailable).toList();

  /// Envia dados tentando todos os transportes disponíveis
  Future<bool> broadcastData(Uint8List data) async {
    bool success = false;
    for (var transport in availableTransports) {
      // Implementação de broadcast específica de cada meio
      // success = await transport.sendData('BROADCAST', data) || success;
    }
    return success;
  }
}
