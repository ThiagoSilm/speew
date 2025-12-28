// lib/core/storage/mesh/mesh_state_storage.dart

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

// Modelo de dados para o estado da mesh
class MeshState {
  final List<String> knownPeers;
  final String lastCalculatedRoute;
  final DateTime lastSyncTime;
  final List<String> pendingRetransmissionQueue;

  MeshState({
    required this.knownPeers,
    required this.lastCalculatedRoute,
    required this.lastSyncTime,
    required this.pendingRetransmissionQueue,
  });

  // Converte o objeto MeshState para um mapa JSON
  Map<String, dynamic> toJson() => {
        'knownPeers': knownPeers,
        'lastCalculatedRoute': lastCalculatedRoute,
        'lastSyncTime': lastSyncTime.toIso8601String(),
        'pendingRetransmissionQueue': pendingRetransmissionQueue,
      };

  // Cria um objeto MeshState a partir de um mapa JSON
  factory MeshState.fromJson(Map<String, dynamic> json) {
    return MeshState(
      knownPeers: List<String>.from(json['knownPeers'] ?? []),
      lastCalculatedRoute: json['lastCalculatedRoute'] ?? '',
      lastSyncTime: DateTime.tryParse(json['lastSyncTime'] ?? '') ?? DateTime.now(),
      pendingRetransmissionQueue: List<String>.from(json['pendingRetransmissionQueue'] ?? []),
    );
  }

  // Estado inicial vazio
  static MeshState empty() => MeshState(
        knownPeers: [],
        lastCalculatedRoute: '',
        lastSyncTime: DateTime.fromMillisecondsSinceEpoch(0),
        pendingRetransmissionQueue: [],
      );
}

// Serviço de armazenamento para o estado da mesh
class MeshStateStorage {
  static const _key = 'mesh_state';

  // Salva o estado da mesh no armazenamento persistente
  Future<void> saveState(MeshState state) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = jsonEncode(state.toJson());
      await prefs.setString(_key, jsonString);
      if (kDebugMode) {
        print('MeshStateStorage: Estado da Mesh salvo com sucesso.');
      }
    } catch (e) {
      if (kDebugMode) {
        print('MeshStateStorage: Erro ao salvar estado da Mesh: $e');
      }
    }
  }

  // Carrega o estado da mesh do armazenamento persistente
  Future<MeshState> loadState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_key);
      if (jsonString != null) {
        final jsonMap = jsonDecode(jsonString);
        if (kDebugMode) {
          print('MeshStateStorage: Estado da Mesh carregado com sucesso.');
        }
        return MeshState.fromJson(jsonMap);
      }
    } catch (e) {
      if (kDebugMode) {
        print('MeshStateStorage: Erro ao carregar estado da Mesh: $e');
      }
    }
    return MeshState.empty();
  }
}
