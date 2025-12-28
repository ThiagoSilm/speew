/// Modelo de dados para mensagens trocadas na rede P2P
/// Suporta mensagens de texto, arquivos e transações de moeda
class Message {
  /// Identificador único da mensagem
  final String messageId;
  
  /// ID do usuário que enviou a mensagem
  final String senderId;
  
  /// ID do usuário destinatário
  final String receiverId;
  
  /// Conteúdo da mensagem criptografado com XChaCha20-Poly1305
  final String contentEncrypted;
  
  /// Timestamp de criação da mensagem
  final DateTime timestamp;
  
  /// Status da entrega: pending, delivered, read
  final String status;
  
  /// Tipo da mensagem: text, file, transaction
  final String type;

  Message({
    required this.messageId,
    required this.senderId,
    required this.receiverId,
    required this.contentEncrypted,
    required this.timestamp,
    required this.status,
    required this.type,
  });

  /// Converte o objeto Message para Map
  Map<String, dynamic> toMap() {
    return {
      'message_id': messageId,
      'sender_id': senderId,
      'receiver_id': receiverId,
      'content_encrypted': contentEncrypted,
      'timestamp': timestamp.toIso8601String(),
      'status': status,
      'type': type,
    };
  }

  /// Cria um objeto Message a partir de um Map
  factory Message.fromMap(Map<String, dynamic> map) {
    return Message(
      messageId: map['message_id'] as String,
      senderId: map['sender_id'] as String,
      receiverId: map['receiver_id'] as String,
      contentEncrypted: map['content_encrypted'] as String,
      timestamp: DateTime.parse(map['timestamp'] as String),
      status: map['status'] as String,
      type: map['type'] as String,
    );
  }

  /// Cria uma cópia da mensagem com campos atualizados
  Message copyWith({
    String? messageId,
    String? senderId,
    String? receiverId,
    String? contentEncrypted,
    DateTime? timestamp,
    String? status,
    String? type,
  }) {
    return Message(
      messageId: messageId ?? this.messageId,
      senderId: senderId ?? this.senderId,
      receiverId: receiverId ?? this.receiverId,
      contentEncrypted: contentEncrypted ?? this.contentEncrypted,
      timestamp: timestamp ?? this.timestamp,
      status: status ?? this.status,
      type: type ?? this.type,
    );
  }
}
