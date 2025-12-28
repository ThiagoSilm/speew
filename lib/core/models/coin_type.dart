/// ==================== NOVO MODELO: TIPO DE MOEDA ====================
/// Modelo de dados para diferentes tipos de moedas simbólicas
/// Permite múltiplos tipos de créditos na economia P2P
///
/// ADICIONADO: Fase 4 - Expansão da economia simbólica
class CoinType {
  /// Identificador único do tipo de moeda
  final String coinTypeId;
  
  /// Nome do tipo de moeda (ex: "Crédito de Ajuda", "Moeda de Serviço")
  final String name;
  
  /// Descrição do propósito deste tipo de moeda
  final String description;
  
  /// Cor associada ao tipo de moeda (hex)
  final String color;
  
  /// Ícone associado ao tipo de moeda
  final String icon;
  
  /// Timestamp de criação
  final DateTime createdAt;
  
  /// Se este tipo de moeda pode ser convertido para outros tipos
  final bool isConvertible;
  
  /// Taxa de conversão base (se conversível)
  final double? conversionRate;

  CoinType({
    required this.coinTypeId,
    required this.name,
    required this.description,
    required this.color,
    required this.icon,
    required this.createdAt,
    this.isConvertible = false,
    this.conversionRate,
  });

  /// Converte o objeto CoinType para Map
  Map<String, dynamic> toMap() {
    return {
      'coin_type_id': coinTypeId,
      'name': name,
      'description': description,
      'color': color,
      'icon': icon,
      'created_at': createdAt.toIso8601String(),
      'is_convertible': isConvertible ? 1 : 0,
      'conversion_rate': conversionRate,
    };
  }

  /// Cria um objeto CoinType a partir de um Map
  factory CoinType.fromMap(Map<String, dynamic> map) {
    return CoinType(
      coinTypeId: map['coin_type_id'] as String,
      name: map['name'] as String,
      description: map['description'] as String,
      color: map['color'] as String,
      icon: map['icon'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      isConvertible: (map['is_convertible'] as int) == 1,
      conversionRate: map['conversion_rate'] as double?,
    );
  }

  /// Cria uma cópia do tipo de moeda com campos atualizados
  CoinType copyWith({
    String? coinTypeId,
    String? name,
    String? description,
    String? color,
    String? icon,
    DateTime? createdAt,
    bool? isConvertible,
    double? conversionRate,
  }) {
    return CoinType(
      coinTypeId: coinTypeId ?? this.coinTypeId,
      name: name ?? this.name,
      description: description ?? this.description,
      color: color ?? this.color,
      icon: icon ?? this.icon,
      createdAt: createdAt ?? this.createdAt,
      isConvertible: isConvertible ?? this.isConvertible,
      conversionRate: conversionRate ?? this.conversionRate,
    );
  }

  /// Tipos de moeda padrão
  static CoinType get helpCredits => CoinType(
    coinTypeId: 'help_credits',
    name: 'Créditos de Ajuda',
    description: 'Moeda para trocas de ajuda e favores',
    color: '#4CAF50',
    icon: '🤝',
    createdAt: DateTime.now(),
    isConvertible: true,
    conversionRate: 1.0,
  );

  static CoinType get serviceCoins => CoinType(
    coinTypeId: 'service_coins',
    name: 'Moedas de Serviço',
    description: 'Moeda para serviços prestados',
    color: '#2196F3',
    icon: '⚙️',
    createdAt: DateTime.now(),
    isConvertible: true,
    conversionRate: 1.5,
  );

  static CoinType get knowledgePoints => CoinType(
    coinTypeId: 'knowledge_points',
    name: 'Pontos de Conhecimento',
    description: 'Moeda para compartilhamento de conhecimento',
    color: '#FF9800',
    icon: '📚',
    createdAt: DateTime.now(),
    isConvertible: true,
    conversionRate: 2.0,
  );

  static CoinType get gratitudeTokens => CoinType(
    coinTypeId: 'gratitude_tokens',
    name: 'Tokens de Gratidão',
    description: 'Moeda para expressar gratidão',
    color: '#E91E63',
    icon: '❤️',
    createdAt: DateTime.now(),
    isConvertible: false,
  );
}
