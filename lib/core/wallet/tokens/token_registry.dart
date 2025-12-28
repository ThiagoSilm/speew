import 'package:flutter/material.dart';
import 'token_model.dart';

/// Registro global de todos os tokens simbólicos da rede.
class TokenRegistry {
  // Tokens implementados
  static final TokenModel MESH = TokenModel(
    id: 'mesh_token',
    symbol: 'MESH',
    name: 'Mesh Coin',
    supply: 1000000.0,
    icon: Icons.hub,
    dynamicProperties: {'description': 'Moeda principal da rede, usada para transações e taxas.'},
  );

  static final TokenModel HOP = TokenModel(
    id: 'hop_token',
    symbol: 'HOP',
    name: 'Hop Reward',
    supply: 500000.0,
    icon: Icons.alt_route,
    dynamicProperties: {'description': 'Recompensa por retransmissão de pacotes e manutenção da rede mesh.'},
  );

  static final TokenModel REP = TokenModel(
    id: 'rep_token',
    symbol: 'REP',
    name: 'Reputation Token',
    supply: 100000.0,
    icon: Icons.verified_user,
    dynamicProperties: {'description': 'Token lastreado na reputação do usuário. Não transferível.'},
  );

  static final TokenModel WORK = TokenModel(
    id: 'work_token',
    symbol: 'WORK',
    name: 'Work Credit',
    supply: 200000.0,
    icon: Icons.work,
    dynamicProperties: {'description': 'Crédito usado para microtarefas e transações no marketplace.'},
  );

  // Mapa de registro
  static final Map<String, TokenModel> _registry = {
    MESH.id: MESH,
    HOP.id: HOP,
    REP.id: REP,
    WORK.id: WORK,
  };

  /// Retorna todos os tokens registrados.
  static List<TokenModel> getAllTokens() {
    return _registry.values.toList();
  }

  /// Retorna um token pelo seu ID.
  static TokenModel? getTokenById(String id) {
    return _registry[id];
  }

  /// Retorna um token pelo seu símbolo.
  static TokenModel? getTokenBySymbol(String symbol) {
    return _registry.values.firstWhere(
      (token) => token.symbol == symbol,
      orElse: () => throw Exception('Token with symbol $symbol not found'),
    );
  }

  /// Atualiza as propriedades dinâmicas de um token (ex: supply).
  static void updateToken(TokenModel updatedToken) {
    if (_registry.containsKey(updatedToken.id)) {
      _registry[updatedToken.id] = updatedToken;
    } else {
      throw Exception('Token with ID ${updatedToken.id} not found in registry.');
    }
  }
}
