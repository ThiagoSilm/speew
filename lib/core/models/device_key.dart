/// Modelo para representar a chave de um dispositivo associado a um usuário
class DeviceKey {
  final String deviceId;
  final String userId;
  final String publicKey;
  final DateTime lastSeen;
  final bool isCurrentDevice;

  DeviceKey({
    required this.deviceId,
    required this.userId,
    required this.publicKey,
    required this.lastSeen,
    required this.isCurrentDevice,
  });

  /// Cria um DeviceKey a partir de um Map
  factory DeviceKey.fromMap(Map<String, dynamic> map) {
    return DeviceKey(
      deviceId: map['deviceId'] as String,
      userId: map['userId'] as String,
      publicKey: map['publicKey'] as String,
      lastSeen: DateTime.parse(map['lastSeen'] as String),
      isCurrentDevice: map['isCurrentDevice'] == 1,
    );
  }

  /// Converte o DeviceKey para um Map
  Map<String, dynamic> toMap() {
    return {
      'deviceId': deviceId,
      'userId': userId,
      'publicKey': publicKey,
      'lastSeen': lastSeen.toIso8601String(),
      'isCurrentDevice': isCurrentDevice ? 1 : 0,
    };
  }
}
