/// Modelo de dados para arquivos compartilhados na rede P2P
/// Arquivos são fragmentados em blocos para transmissão eficiente
class FileModel {
  /// Identificador único do arquivo
  final String fileId;
  
  /// ID do usuário proprietário do arquivo
  final String ownerId;
  
  /// Nome original do arquivo
  final String filename;
  
  /// Tamanho total do arquivo em bytes
  final int size;
  
  /// Timestamp de criação do arquivo
  final DateTime createdAt;

  FileModel({
    required this.fileId,
    required this.ownerId,
    required this.filename,
    required this.size,
    required this.createdAt,
  });

  /// Converte o objeto FileModel para Map
  Map<String, dynamic> toMap() {
    return {
      'file_id': fileId,
      'owner_id': ownerId,
      'filename': filename,
      'size': size,
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// Cria um objeto FileModel a partir de um Map
  factory FileModel.fromMap(Map<String, dynamic> map) {
    return FileModel(
      fileId: map['file_id'] as String,
      ownerId: map['owner_id'] as String,
      filename: map['filename'] as String,
      size: map['size'] as int,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  /// Cria uma cópia do arquivo com campos atualizados
  FileModel copyWith({
    String? fileId,
    String? ownerId,
    String? filename,
    int? size,
    DateTime? createdAt,
  }) {
    return FileModel(
      fileId: fileId ?? this.fileId,
      ownerId: ownerId ?? this.ownerId,
      filename: filename ?? this.filename,
      size: size ?? this.size,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
