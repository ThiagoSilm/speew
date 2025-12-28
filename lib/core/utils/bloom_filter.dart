import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';

/// Implementação de Bloom Filter para otimização de coleções distribuídas (I.2).
/// Usado para verificar a pertença de um elemento a um conjunto com economia de dados.
/// Possui uma taxa de falso positivo, mas nunca falso negativo.
class BloomFilter {
  final int size; // Tamanho do array de bits (m)
  final int numHashes; // Número de funções de hash (k)
  final Uint8List _bitArray;

  /// Construtor para criar um novo Bloom Filter.
  /// size: Tamanho do array de bits.
  /// numHashes: Número de funções de hash.
  BloomFilter({required this.size, required this.numHashes})
      : _bitArray = Uint8List((size / 8).ceil());

  /// Construtor para recriar um Bloom Filter a partir de um array de bytes.
  BloomFilter.fromBytes({required this.size, required this.numHashes, required Uint8List bytes})
      : _bitArray = bytes;

  /// Gera os índices de hash para um dado elemento.
  List<int> _getHashes(String element) {
    final bytes = utf8.encode(element);
    final hashes = <int>[];
    
    // Usamos uma combinação de 3 hashes para simular k funções de hash
    // Otimização: Usar apenas 2 hashes e gerar os demais linearmente (Kirsch & Mitzenmacher)
    final h1 = sha256.convert(bytes).bytes;
    final h2 = sha512.convert(bytes).bytes;

    for (int i = 0; i < numHashes; i++) {
      // Combinação linear: g_i(x) = (h1(x) + i * h2(x)) mod m
      // Convertemos os hashes para BigInt para evitar overflow, depois para int
      final hash1 = ByteData.view(Uint8List.fromList(h1).buffer).getUint64(0);
      final hash2 = ByteData.view(Uint8List.fromList(h2).buffer).getUint64(0);
      
      final index = (hash1 + i * hash2) % size;
      hashes.add(index.toInt());
    }
    return hashes;
  }

  /// Adiciona um elemento ao Bloom Filter.
  void add(String element) {
    for (final index in _getHashes(element)) {
      final byteIndex = (index / 8).floor();
      final bitIndex = index % 8;
      
      // Define o bit na posição
      _bitArray[byteIndex] |= (1 << bitIndex);
    }
  }

  /// Verifica se um elemento pode pertencer ao conjunto.
  /// Retorna true se o elemento *pode* estar presente (possível falso positivo).
  /// Retorna false se o elemento *definitivamente não* está presente.
  bool mightContain(String element) {
    for (final index in _getHashes(element)) {
      final byteIndex = (index / 8).floor();
      final bitIndex = index % 8;
      
      // Verifica se o bit está definido
      if ((_bitArray[byteIndex] & (1 << bitIndex)) == 0) {
        return false; // Bit não definido, definitivamente não está presente
      }
    }
    return true; // Todos os bits definidos, pode estar presente
  }

  /// Retorna o array de bytes do Bloom Filter para serialização.
  Uint8List toBytes() => _bitArray;
  
  /// Converte o array de bytes para Base64 para serialização em JSON/Map.
  String toBase64() => base64Encode(_bitArray);
  
  /// Cria um Bloom Filter a partir de uma string Base64.
  static BloomFilter fromBase64({required int size, required int numHashes, required String base64String}) {
    final bytes = base64Decode(base64String);
    return BloomFilter.fromBytes(size: size, numHashes: numHashes, bytes: bytes);
  }
}
