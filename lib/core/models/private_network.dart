/// ==================== NOVO MODELO: REDE PRIVADA ====================
/// Modelo de dados para redes privadas com chave de acesso
/// Permite criar "salas" privadas onde apenas peers com a chave correta podem participar
///
/// ADICIONADO: Fase 7 - Redes Privadas
class PrivateNetwork {
  /// Identificador único da rede privada
  final String networkId;
  
  /// Nome da rede privada
  final String name;
  
  /// Descrição da rede
  final String description;
  
  /// ID do criador da rede
  final String creatorId;
  
  /// Hash da chave de acesso (não armazena a chave em texto claro)
  final String accessKeyHash;
  
  /// Timestamp de criação
  final DateTime createdAt;
  
  /// Número máximo de participantes (0 = ilimitado)
  final int maxParticipants;
  
  /// Status da rede (active, closed, archived)
  final String status;
  
  /// Tipo de autenticação (password, qr_code, nfc)
  final String authType;
  
  /// Dados do QR Code (se authType = qr_code)
  final String? qrCodeData;
  
  /// Configurações adicionais (JSON)
  final String? settings;

  PrivateNetwork({
    required this.networkId,
    required this.name,
    required this.description,
    required this.creatorId,
    required this.accessKeyHash,
    required this.createdAt,
    this.maxParticipants = 0,
    this.status = 'active',
    this.authType = 'password',
    this.qrCodeData,
    this.settings,
  });

  /// Converte o objeto PrivateNetwork para Map
  Map<String, dynamic> toMap() {
    return {
      'network_id': networkId,
      'name': name,
      'description': description,
      'creator_id': creatorId,
      'access_key_hash': accessKeyHash,
      'created_at': createdAt.toIso8601String(),
      'max_participants': maxParticipants,
      'status': status,
      'auth_type': authType,
      'qr_code_data': qrCodeData,
      'settings': settings,
    };
  }

  /// Cria um objeto PrivateNetwork a partir de um Map
  factory PrivateNetwork.fromMap(Map<String, dynamic> map) {
    return PrivateNetwork(
      networkId: map['network_id'] as String,
      name: map['name'] as String,
      description: map['description'] as String,
      creatorId: map['creator_id'] as String,
      accessKeyHash: map['access_key_hash'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      maxParticipants: map['max_participants'] as int? ?? 0,
      status: map['status'] as String? ?? 'active',
      authType: map['auth_type'] as String? ?? 'password',
      qrCodeData: map['qr_code_data'] as String?,
      settings: map['settings'] as String?,
    );
  }

  /// Cria uma cópia da rede com campos atualizados
  PrivateNetwork copyWith({
    String? networkId,
    String? name,
    String? description,
    String? creatorId,
    String? accessKeyHash,
    DateTime? createdAt,
    int? maxParticipants,
    String? status,
    String? authType,
    String? qrCodeData,
    String? settings,
  }) {
    return PrivateNetwork(
      networkId: networkId ?? this.networkId,
      name: name ?? this.name,
      description: description ?? this.description,
      creatorId: creatorId ?? this.creatorId,
      accessKeyHash: accessKeyHash ?? this.accessKeyHash,
      createdAt: createdAt ?? this.createdAt,
      maxParticipants: maxParticipants ?? this.maxParticipants,
      status: status ?? this.status,
      authType: authType ?? this.authType,
      qrCodeData: qrCodeData ?? this.qrCodeData,
      settings: settings ?? this.settings,
    );
  }

  /// Verifica se a rede está ativa
  bool get isActive => status == 'active';

  /// Verifica se a rede tem limite de participantes
  bool get hasParticipantLimit => maxParticipants > 0;
}

/// Modelo de participante de rede privada
class NetworkParticipant {
  /// ID do usuário
  final String userId;
  
  /// ID da rede privada
  final String networkId;
  
  /// Timestamp de entrada na rede
  final DateTime joinedAt;
  
  /// Role do participante (admin, member, guest)
  final String role;
  
  /// Status do participante (active, banned, left)
  final String status;

  NetworkParticipant({
    required this.userId,
    required this.networkId,
    required this.joinedAt,
    this.role = 'member',
    this.status = 'active',
  });

  /// Converte o objeto NetworkParticipant para Map
  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'network_id': networkId,
      'joined_at': joinedAt.toIso8601String(),
      'role': role,
      'status': status,
    };
  }

  /// Cria um objeto NetworkParticipant a partir de um Map
  factory NetworkParticipant.fromMap(Map<String, dynamic> map) {
    return NetworkParticipant(
      userId: map['user_id'] as String,
      networkId: map['network_id'] as String,
      joinedAt: DateTime.parse(map['joined_at'] as String),
      role: map['role'] as String? ?? 'member',
      status: map['status'] as String? ?? 'active',
    );
  }

  /// Cria uma cópia do participante com campos atualizados
  NetworkParticipant copyWith({
    String? userId,
    String? networkId,
    DateTime? joinedAt,
    String? role,
    String? status,
  }) {
    return NetworkParticipant(
      userId: userId ?? this.userId,
      networkId: networkId ?? this.networkId,
      joinedAt: joinedAt ?? this.joinedAt,
      role: role ?? this.role,
      status: status ?? this.status,
    );
  }

  /// Verifica se o participante é admin
  bool get isAdmin => role == 'admin';

  /// Verifica se o participante está ativo
  bool get isActive => status == 'active';
}
