/// ==================== NOVO MODELO: EVENTO DE CONFIANÇA ====================
/// Modelo de dados para eventos que afetam a confiança entre usuários
/// Usado para rastreamento detalhado de comportamento na rede
///
/// ADICIONADO: Fase 5 - Sistema de Confiança Avançado
class TrustEvent {
  /// Identificador único do evento
  final String eventId;
  
  /// ID do usuário que gerou o evento
  final String userId;
  
  /// Tipo de evento
  /// Valores: message_delivered, message_failed, transaction_accepted,
  /// transaction_rejected, file_shared, file_received, route_success, route_failure
  final String eventType;
  
  /// Impacto no trust score (-1.0 a 1.0)
  final double impact;
  
  /// Timestamp do evento
  final DateTime timestamp;
  
  /// Dados adicionais do evento (JSON)
  final String? metadata;
  
  /// Severidade do evento (low, medium, high, critical)
  final String severity;

  TrustEvent({
    required this.eventId,
    required this.userId,
    required this.eventType,
    required this.impact,
    required this.timestamp,
    this.metadata,
    this.severity = 'medium',
  });

  /// Converte o objeto TrustEvent para Map
  Map<String, dynamic> toMap() {
    return {
      'event_id': eventId,
      'user_id': userId,
      'event_type': eventType,
      'impact': impact,
      'timestamp': timestamp.toIso8601String(),
      'metadata': metadata,
      'severity': severity,
    };
  }

  /// Cria um objeto TrustEvent a partir de um Map
  factory TrustEvent.fromMap(Map<String, dynamic> map) {
    return TrustEvent(
      eventId: map['event_id'] as String,
      userId: map['user_id'] as String,
      eventType: map['event_type'] as String,
      impact: map['impact'] as double,
      timestamp: DateTime.parse(map['timestamp'] as String),
      metadata: map['metadata'] as String?,
      severity: map['severity'] as String? ?? 'medium',
    );
  }

  /// Cria uma cópia do evento com campos atualizados
  TrustEvent copyWith({
    String? eventId,
    String? userId,
    String? eventType,
    double? impact,
    DateTime? timestamp,
    String? metadata,
    String? severity,
  }) {
    return TrustEvent(
      eventId: eventId ?? this.eventId,
      userId: userId ?? this.userId,
      eventType: eventType ?? this.eventType,
      impact: impact ?? this.impact,
      timestamp: timestamp ?? this.timestamp,
      metadata: metadata ?? this.metadata,
      severity: severity ?? this.severity,
    );
  }

  /// Verifica se o evento é positivo
  bool get isPositive => impact > 0;

  /// Verifica se o evento é negativo
  bool get isNegative => impact < 0;

  /// Verifica se o evento é crítico
  bool get isCritical => severity == 'critical';
}
