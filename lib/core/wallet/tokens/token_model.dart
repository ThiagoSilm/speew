import 'package:flutter/material.dart';

/// Modelo de dados para representar um token simbólico.
class TokenModel {
  final String id;
  final String symbol;
  final String name;
  final double supply;
  final int decimals;
  final IconData icon;
  final Map<String, dynamic> dynamicProperties;

  TokenModel({
    required this.id,
    required this.symbol,
    required this.name,
    required this.supply,
    this.decimals = 2,
    required this.icon,
    this.dynamicProperties = const {},
  });

  // Factory para criar a partir de JSON
  factory TokenModel.fromJson(Map<String, dynamic> json) {
    return TokenModel(
      id: json['id'] as String,
      symbol: json['symbol'] as String,
      name: json['name'] as String,
      supply: json['supply'] as double,
      decimals: json['decimals'] as int,
      icon: IconData(json['iconCodePoint'] as int, fontFamily: 'MaterialIcons'),
      dynamicProperties: json['dynamicProperties'] as Map<String, dynamic>,
    );
  }

  // Converte para JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'symbol': symbol,
      'name': name,
      'supply': supply,
      'decimals': decimals,
      'iconCodePoint': icon.codePoint,
      'dynamicProperties': dynamicProperties,
    };
  }

  // Método para atualizar propriedades dinâmicas
  TokenModel copyWith({
    double? supply,
    Map<String, dynamic>? dynamicProperties,
  }) {
    return TokenModel(
      id: id,
      symbol: symbol,
      name: name,
      supply: supply ?? this.supply,
      decimals: decimals,
      icon: icon,
      dynamicProperties: dynamicProperties ?? this.dynamicProperties,
    );
  }
}
