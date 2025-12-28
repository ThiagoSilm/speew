import 'dart:typed_data';
import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Utilitário para Bloom Filters - estrutura de dados probabilística
/// Usado para representar listas grandes de IDs de forma compacta
/// 
/// ECONOMIA:
/// - 1000 IDs (36 bytes cada) = 36 KB
/// - Bloom Filter (1% false positive) = ~1.2 KB
/// - Redução: 97% de economia de dados
/// 
/// TRADE-OFF:
/// - False positives: Possível (configurável)
/// - False negatives: Impossível (garantido)
class BloomFilterUtils {
  /// Cria um Bloom Filter a partir de uma lista de strings
  /// 
  /// Parâmetros:
  /// - items: Lista de strings a serem adicionadas
  /// - falsePositiveRate: Taxa de falso positivo desejada (0.01 = 1%)
  /// 
  /// Retorna: Uint8List contendo o filtro compactado
  static Uint8List createFilter(List<String> items, {double falsePositiveRate = 0.01}) {
    if (items.isEmpty) {
      return Uint8List(0);
    }
    
    final n = items.length;
    
    // Calcula tamanho ótimo do filtro (em bits)
    // m = -(n * ln(p)) / (ln(2)^2)
    final m = (-(n * _ln(falsePositiveRate)) / (_ln(2) * _ln(2))).ceil();
    
    // Calcula número ótimo de funções hash
    // k = (m / n) * ln(2)
    final k = ((m / n) * _ln(2)).ceil();
    
    // Tamanho em bytes (arredonda para cima)
    final sizeInBytes = (m / 8).ceil();
    
    // Cria array de bits
    final filter = Uint8List(sizeInBytes);
    
    // Adiciona cada item ao filtro
    for (final item in items) {
      final hashes = _getHashes(item, k, m);
      for (final hash in hashes) {
        final byteIndex = hash ~/ 8;
        final bitIndex = hash % 8;
        filter[byteIndex] |= (1 << bitIndex);
      }
    }
    
    return filter;
  }
  
  /// Verifica se um item pode estar no filtro
  /// 
  /// Retorna:
  /// - true: Item PODE estar no filtro (ou falso positivo)
  /// - false: Item DEFINITIVAMENTE NÃO está no filtro
  static bool mightContain(Uint8List filter, String item, int numHashFunctions) {
    if (filter.isEmpty) {
      return false;
    }
    
    final m = filter.length * 8;
    final hashes = _getHashes(item, numHashFunctions, m);
    
    for (final hash in hashes) {
      final byteIndex = hash ~/ 8;
      final bitIndex = hash % 8;
      
      if (byteIndex >= filter.length) {
        return false;
      }
      
      if ((filter[byteIndex] & (1 << bitIndex)) == 0) {
        return false; // Bit não está setado = item definitivamente não está
      }
    }
    
    return true; // Todos os bits estão setados = item pode estar
  }
  
  /// Gera k hashes para um item
  /// Usa double hashing: h_i(x) = (h1(x) + i * h2(x)) mod m
  static List<int> _getHashes(String item, int k, int m) {
    final bytes = utf8.encode(item);
    
    // Hash 1: SHA-256
    final hash1Bytes = sha256.convert(bytes).bytes;
    final hash1 = _bytesToInt(hash1Bytes);
    
    // Hash 2: SHA-256 do hash1
    final hash2Bytes = sha256.convert(hash1Bytes).bytes;
    final hash2 = _bytesToInt(hash2Bytes);
    
    final hashes = <int>[];
    for (var i = 0; i < k; i++) {
      final combinedHash = (hash1 + i * hash2) % m;
      hashes.add(combinedHash.abs());
    }
    
    return hashes;
  }
  
  /// Converte bytes para int (usa primeiros 8 bytes)
  static int _bytesToInt(List<int> bytes) {
    var result = 0;
    for (var i = 0; i < 8 && i < bytes.length; i++) {
      result = (result << 8) | bytes[i];
    }
    return result;
  }
  
  /// Logaritmo natural
  static double _ln(double x) {
    if (x <= 0) {
      throw ArgumentError('ln: x deve ser positivo');
    }
    return _log(x) / _log(_e);
  }
  
  /// Logaritmo base 10 (aproximação)
  static double _log(double x) {
    if (x <= 0) {
      throw ArgumentError('log: x deve ser positivo');
    }
    // Aproximação usando série de Taylor
    var result = 0.0;
    var term = (x - 1) / (x + 1);
    var term2 = term * term;
    var numerator = term;
    
    for (var i = 0; i < 100; i++) {
      result += numerator / (2 * i + 1);
      numerator *= term2;
      if (numerator.abs() < 1e-10) break;
    }
    
    return 2 * result;
  }
  
  static const double _e = 2.718281828459045;
  
  /// Serializa filtro com metadados
  /// Formato: [numHashFunctions (1 byte)][filterLength (4 bytes)][filterData]
  static Uint8List serialize(Uint8List filter, int numHashFunctions) {
    final result = ByteData(1 + 4 + filter.length);
    result.setUint8(0, numHashFunctions);
    result.setUint32(1, filter.length, Endian.big);
    
    final resultList = result.buffer.asUint8List();
    resultList.setRange(5, 5 + filter.length, filter);
    
    return resultList;
  }
  
  /// Desserializa filtro com metadados
  /// Retorna: Map com 'filter' e 'numHashFunctions'
  static Map<String, dynamic> deserialize(Uint8List data) {
    if (data.length < 5) {
      throw ArgumentError('BloomFilterUtils.deserialize: Dados insuficientes');
    }
    
    final buffer = ByteData.sublistView(data);
    final numHashFunctions = buffer.getUint8(0);
    final filterLength = buffer.getUint32(1, Endian.big);
    
    if (data.length < 5 + filterLength) {
      throw ArgumentError('BloomFilterUtils.deserialize: Comprimento de filtro inválido');
    }
    
    final filter = data.sublist(5, 5 + filterLength);
    
    return {
      'filter': filter,
      'numHashFunctions': numHashFunctions,
    };
  }
  
  /// Calcula taxa de falso positivo real
  /// p = (1 - e^(-kn/m))^k
  static double calculateFalsePositiveRate(int numItems, int filterSizeInBits, int numHashFunctions) {
    if (numItems == 0 || filterSizeInBits == 0) {
      return 0.0;
    }
    
    final k = numHashFunctions.toDouble();
    final n = numItems.toDouble();
    final m = filterSizeInBits.toDouble();
    
    // p = (1 - e^(-kn/m))^k
    final exponent = -(k * n) / m;
    final base = 1 - _exp(exponent);
    
    return _pow(base, k);
  }
  
  /// Exponencial (aproximação)
  static double _exp(double x) {
    var result = 1.0;
    var term = 1.0;
    
    for (var i = 1; i < 100; i++) {
      term *= x / i;
      result += term;
      if (term.abs() < 1e-10) break;
    }
    
    return result;
  }
  
  /// Potência (aproximação)
  static double _pow(double base, double exponent) {
    if (base == 0) return 0;
    if (exponent == 0) return 1;
    
    // x^y = e^(y * ln(x))
    return _exp(exponent * _ln(base));
  }
}
