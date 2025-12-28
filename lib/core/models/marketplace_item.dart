/// ==================== NOVO MODELO: ITEM DE MARKETPLACE ====================
/// Modelo de dados para itens no marketplace offline P2P
/// Permite trocas de bens e serviços usando moeda simbólica
///
/// ADICIONADO: Fase 4 - Expansão da economia simbólica
class MarketplaceItem {
  /// Identificador único do item
  final String itemId;
  
  /// ID do usuário que oferece o item
  final String sellerId;
  
  /// Título do item
  final String title;
  
  /// Descrição detalhada
  final String description;
  
  /// Categoria do item (service, good, knowledge, etc)
  final String category;
  
  /// Preço em moeda simbólica
  final double price;
  
  /// Tipo de moeda aceita
  final String coinTypeId;
  
  /// Status do item (available, sold, reserved, cancelled)
  final String status;
  
  /// Timestamp de criação
  final DateTime createdAt;
  
  /// Timestamp de atualização
  final DateTime updatedAt;
  
  /// Tags para busca
  final List<String> tags;
  
  /// ID do comprador (se vendido ou reservado)
  final String? buyerId;
  
  /// Imagem do item (base64 ou path)
  final String? imageData;

  MarketplaceItem({
    required this.itemId,
    required this.sellerId,
    required this.title,
    required this.description,
    required this.category,
    required this.price,
    required this.coinTypeId,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.tags,
    this.buyerId,
    this.imageData,
  });

  /// Converte o objeto MarketplaceItem para Map
  Map<String, dynamic> toMap() {
    return {
      'item_id': itemId,
      'seller_id': sellerId,
      'title': title,
      'description': description,
      'category': category,
      'price': price,
      'coin_type_id': coinTypeId,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'tags': tags.join(','),
      'buyer_id': buyerId,
      'image_data': imageData,
    };
  }

  /// Cria um objeto MarketplaceItem a partir de um Map
  factory MarketplaceItem.fromMap(Map<String, dynamic> map) {
    return MarketplaceItem(
      itemId: map['item_id'] as String,
      sellerId: map['seller_id'] as String,
      title: map['title'] as String,
      description: map['description'] as String,
      category: map['category'] as String,
      price: map['price'] as double,
      coinTypeId: map['coin_type_id'] as String,
      status: map['status'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      tags: (map['tags'] as String).split(','),
      buyerId: map['buyer_id'] as String?,
      imageData: map['image_data'] as String?,
    );
  }

  /// Cria uma cópia do item com campos atualizados
  MarketplaceItem copyWith({
    String? itemId,
    String? sellerId,
    String? title,
    String? description,
    String? category,
    double? price,
    String? coinTypeId,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<String>? tags,
    String? buyerId,
    String? imageData,
  }) {
    return MarketplaceItem(
      itemId: itemId ?? this.itemId,
      sellerId: sellerId ?? this.sellerId,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      price: price ?? this.price,
      coinTypeId: coinTypeId ?? this.coinTypeId,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      tags: tags ?? this.tags,
      buyerId: buyerId ?? this.buyerId,
      imageData: imageData ?? this.imageData,
    );
  }

  /// Verifica se o item está disponível
  bool get isAvailable => status == 'available';

  /// Verifica se o item está vendido
  bool get isSold => status == 'sold';

  /// Verifica se o item está reservado
  bool get isReserved => status == 'reserved';
}
