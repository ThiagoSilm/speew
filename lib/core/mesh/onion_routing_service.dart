import 'dart:convert';
import 'dart:typed_data';
import '../crypto/crypto_service.dart';
import '../utils/logger_service.dart';

/// Modelo de Camada de Cebola (Onion Layer)
class OnionLayer {
  final String nextHopId; // Próximo nó na rota
  final String encryptedPayload; // Payload criptografado para o próximo nó
  
  OnionLayer({required this.nextHopId, required this.encryptedPayload});

  Map<String, dynamic> toJson() => {
    'next': nextHopId,
    'data': encryptedPayload,
  };
}

/// Serviço de Onion Routing para a Missão Beta
/// Garante que nós intermediários não conheçam a origem ou o destino final
class OnionRoutingService {
  static final OnionRoutingService _instance = OnionRoutingService._internal();
  factory OnionRoutingService() => _instance;
  OnionRoutingService._internal();

  final CryptoService _crypto = CryptoService();

  /// Cria um pacote de cebola (Onion Packet)
  /// [finalDestinationId]: O destino final da mensagem
  /// [message]: A mensagem original
  /// [route]: Lista de IDs dos nós intermediários (hops)
  /// [keys]: Mapa de chaves públicas de cada nó na rota
  Future<String> createOnionPacket({
    required String finalDestinationId,
    required String message,
    required List<String> route,
    required Map<String, Uint8List> nodeKeys,
  }) async {
    try {
      logger.info('Iniciando construção de Onion Packet (Hops: ${route.length})', tag: 'Onion');
      
      // 1. Começamos pelo núcleo (a mensagem para o destino final)
      String currentPayload = jsonEncode({
        'dest': finalDestinationId,
        'msg': message,
        'type': 'FINAL_DESTINATION',
      });

      // 2. Envolvemos em camadas de trás para frente (do destino para a origem)
      // A rota deve ser invertida para o encapsulamento
      final reversedRoute = route.reversed.toList();
      
      for (int i = 0; i < reversedRoute.length; i++) {
        final currentNodeId = reversedRoute[i];
        final nextHopId = (i == 0) ? finalDestinationId : reversedRoute[i-1];
        final nodeKey = nodeKeys[currentNodeId];

        if (nodeKey == null) throw Exception('Chave não encontrada para o nó: $currentNodeId');

        // Criptografa o payload atual para o nó atual
        final nonce = _crypto.generateNonce();
        final encrypted = _crypto.encrypt(currentPayload, nodeKey, nonce);
        
        // Constrói a nova camada
        currentPayload = jsonEncode({
          'next': nextHopId,
          'payload': encrypted['cipherText'],
          'tag': encrypted['tag'],
          'nonce': base64Encode(nonce),
        });
      }

      logger.info('Onion Packet construído com sucesso', tag: 'Onion');
      return currentPayload;
    } catch (e) {
      logger.error('Erro ao criar Onion Packet', tag: 'Onion', error: e);
      rethrow;
    }
  }

  /// Desembrulha uma camada da cebola (Peel Layer)
  /// Retorna o próximo destino e o payload para o próximo nó
  Future<Map<String, dynamic>?> peelLayer(String onionPacket, Uint8List myPrivateKey) async {
    try {
      final data = jsonDecode(onionPacket);
      
      final String encryptedPayload = data['payload'];
      final String tag = data['tag'];
      final Uint8List nonce = base64Decode(data['nonce']);
      final String nextHopId = data['next'];

      // Descriptografa a camada usando minha chave privada
      // NOTA: Em uma implementação real, usaríamos ECDH para derivar a chave AES
      final decrypted = _crypto.decrypt(encryptedPayload, tag, myPrivateKey, nonce);
      
      if (decrypted == null) {
        logger.error('Falha ao descriptografar camada de cebola. Chave inválida ou pacote corrompido.', tag: 'Onion');
        return null;
      }

      final decryptedData = jsonDecode(decrypted);
      
      return {
        'next': nextHopId,
        'payload': decrypted, // O payload descriptografado que contém a próxima camada ou a mensagem final
      };
    } catch (e) {
      logger.error('Erro ao processar camada de cebola', tag: 'Onion', error: e);
      return null;
    }
  }
}
