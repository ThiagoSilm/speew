/// Modelo de Grupo para chat em grupo na rede P2P
class Group {
  final String groupId;
  final String name;
  final String description;
  final List<String> memberIds; // IDs dos membros
  final String creatorId;
  final DateTime createdAt;
  final String? avatarUrl;

  Group({
    required this.groupId,
    required this.name,
    required this.description,
    required this.memberIds,
    required this.creatorId,
    required this.createdAt,
    this.avatarUrl,
  });

  /// Cria um Group a partir de um Map
  factory Group.fromMap(Map<String, dynamic> map) {
    return Group(
      groupId: map['groupId'] as String,
      name: map['name'] as String,
      description: map['description'] as String? ?? '',
      memberIds: (map['memberIds'] as List<dynamic>).cast<String>(),
      creatorId: map['creatorId'] as String,
      createdAt: DateTime.parse(map['createdAt'] as String),
      avatarUrl: map['avatarUrl'] as String?,
    );
  }

  /// Converte o Group para um Map
  Map<String, dynamic> toMap() {
    return {
      'groupId': groupId,
      'name': name,
      'description': description,
      'memberIds': memberIds,
      'creatorId': creatorId,
      'createdAt': createdAt.toIso8601String(),
      'avatarUrl': avatarUrl,
    };
  }

  /// Cria uma cópia do Group com campos atualizados
  Group copyWith({
    String? groupId,
    String? name,
    String? description,
    List<String>? memberIds,
    String? creatorId,
    DateTime? createdAt,
    String? avatarUrl,
  }) {
    return Group(
      groupId: groupId ?? this.groupId,
      name: name ?? this.name,
      description: description ?? this.description,
      memberIds: memberIds ?? this.memberIds,
      creatorId: creatorId ?? this.creatorId,
      createdAt: createdAt ?? this.createdAt,
      avatarUrl: avatarUrl ?? this.avatarUrl,
    );
  }

  /// Verifica se um usuário é membro do grupo
  bool isMember(String userId) {
    return memberIds.contains(userId);
  }

  /// Verifica se um usuário é o criador do grupo
  bool isCreator(String userId) {
    return creatorId == userId;
  }

  @override
  String toString() {
    return 'Group(groupId: $groupId, name: $name, members: ${memberIds.length})';
  }
}
