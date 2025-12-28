/// Modelo de dados para representar um usuário na rede P2P
/// Cada usuário possui uma identidade única baseada em UUID e chaves criptográficas
class User {
  /// Identificador único universal do usuário
  final String userId;
  
  /// Chave pública Ed25519 para verificação de assinaturas
  final String publicKey;
  
  /// Nome de exibição escolhido pelo usuário
  final String displayName;
  
  /// Pontuação de reputação calculada (0.0 a 1.0)
  /// Fórmula: transações aceitas / total de interações
  final double reputationScore;
  
  /// Timestamp da última vez que o usuário foi visto online
  final DateTime lastSeen;

  User({
    required this.userId,
    required this.publicKey,
    required this.displayName,
    required this.reputationScore,
    required this.lastSeen,
  });

  /// Converte o objeto User para Map (para salvar no banco de dados)
  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'public_key': publicKey,
      'display_name': displayName,
      'reputation_score': reputationScore,
      'last_seen': lastSeen.toIso8601String(),
    };
  }

  /// Cria um objeto User a partir de um Map (leitura do banco de dados)
  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      userId: map['user_id'] as String,
      publicKey: map['public_key'] as String,
      displayName: map['display_name'] as String,
      reputationScore: map['reputation_score'] as double,
      lastSeen: DateTime.parse(map['last_seen'] as String),
    );
  }

  /// Cria uma cópia do usuário com campos atualizados
  User copyWith({
    String? userId,
    String? publicKey,
    String? displayName,
    double? reputationScore,
    DateTime? lastSeen,
  }) {
    return User(
      userId: userId ?? this.userId,
      publicKey: publicKey ?? this.publicKey,
      displayName: displayName ?? this.displayName,
      reputationScore: reputationScore ?? this.reputationScore,
      lastSeen: lastSeen ?? this.lastSeen,
    );
  }
}
