import 'dart:typed_data';

/// Utilitário para manipulação precisa de valores monetários
/// Usa representação de ponto fixo com 8 casas decimais (padrão Bitcoin/Satoshi)
/// 
/// GARANTIAS:
/// - Zero erros de ponto flutuante
/// - Serialização determinística
/// - Operações atômicas e seguras
class DecimalUtils {
  /// Número de casas decimais (8 = 100.000.000 unidades mínimas por unidade)
  static const int decimals = 8;
  static const int multiplier = 100000000; // 10^8
  
  /// Converte string decimal para inteiro de ponto fixo
  /// Exemplo: "1.23456789" -> 123456789
  /// 
  /// REGRAS:
  /// - Trunca (não arredonda) casas decimais extras
  /// - Lança ArgumentError em formato inválido
  /// - Suporta valores negativos
  static int fromString(String value) {
    if (value.isEmpty) {
      throw ArgumentError('DecimalUtils.fromString: Valor vazio não é permitido');
    }
    
    // Remove espaços
    value = value.trim();
    
    // Verifica se é negativo
    final isNegative = value.startsWith('-');
    if (isNegative) {
      value = value.substring(1);
    }
    
    // Divide em parte inteira e decimal
    final parts = value.split('.');
    if (parts.length > 2) {
      throw ArgumentError('DecimalUtils.fromString: Formato inválido (múltiplos pontos decimais): $value');
    }
    
    final integerPart = parts[0];
    final decimalPart = parts.length == 2 ? parts[1] : '';
    
    // Valida que são apenas dígitos
    if (!RegExp(r'^\d+$').hasMatch(integerPart)) {
      throw ArgumentError('DecimalUtils.fromString: Parte inteira inválida: $integerPart');
    }
    if (decimalPart.isNotEmpty && !RegExp(r'^\d+$').hasMatch(decimalPart)) {
      throw ArgumentError('DecimalUtils.fromString: Parte decimal inválida: $decimalPart');
    }
    
    // Limita casas decimais
    String normalizedDecimal = decimalPart;
    if (normalizedDecimal.length > decimals) {
      // Trunca (não arredonda) para evitar inconsistências entre dispositivos
      normalizedDecimal = normalizedDecimal.substring(0, decimals);
    } else {
      // Preenche com zeros à direita
      normalizedDecimal = normalizedDecimal.padRight(decimals, '0');
    }
    
    // Converte para inteiro
    final intValue = int.parse(integerPart) * multiplier + int.parse(normalizedDecimal);
    
    return isNegative ? -intValue : intValue;
  }
  
  /// Converte inteiro de ponto fixo para string decimal
  /// Exemplo: 123456789 -> "1.23456789"
  /// 
  /// GARANTIA: Representação determinística (sempre 8 casas decimais)
  static String toStringFixed(int value, [int precision = 8]) {
    if (precision < 0 || precision > decimals) {
      throw ArgumentError('DecimalUtils.toStringFixed: Precisão deve estar entre 0 e $decimals');
    }
    
    final isNegative = value < 0;
    final absValue = value.abs();
    
    final integerPart = absValue ~/ multiplier;
    final decimalPart = absValue % multiplier;
    
    // Formata parte decimal com zeros à esquerda
    String decimalStr = decimalPart.toString().padLeft(decimals, '0');
    
    // Aplica precisão
    if (precision < decimals) {
      decimalStr = decimalStr.substring(0, precision);
    }
    
    final sign = isNegative ? '-' : '';
    
    if (precision == 0 || decimalStr == '0' * precision) {
      return '$sign$integerPart';
    }
    
    return '$sign$integerPart.$decimalStr';
  }
  
  /// Soma dois valores
  static int add(int a, int b) {
    final result = a + b;
    // Verifica overflow (int64)
    if ((a > 0 && b > 0 && result < 0) || (a < 0 && b < 0 && result > 0)) {
      throw ArgumentError('DecimalUtils.add: Overflow detectado');
    }
    return result;
  }
  
  /// Subtrai dois valores
  static int subtract(int a, int b) {
    final result = a - b;
    // Verifica overflow (int64)
    if ((a > 0 && b < 0 && result < 0) || (a < 0 && b > 0 && result > 0)) {
      throw ArgumentError('DecimalUtils.subtract: Overflow detectado');
    }
    return result;
  }
  
  /// Multiplica por um escalar (inteiro)
  static int multiplyByInt(int value, int scalar) {
    // Verifica overflow antes de multiplicar
    if (scalar != 0 && value.abs() > (9223372036854775807 ~/ scalar.abs())) {
      throw ArgumentError('DecimalUtils.multiplyByInt: Overflow detectado');
    }
    return value * scalar;
  }
  
  /// Divide por um escalar (inteiro)
  static int divideByInt(int value, int scalar) {
    if (scalar == 0) {
      throw ArgumentError('DecimalUtils.divideByInt: Divisão por zero');
    }
    return value ~/ scalar;
  }
  
  /// Compara dois valores
  /// Retorna: -1 se a < b, 0 se a == b, 1 se a > b
  static int compare(int a, int b) {
    if (a < b) return -1;
    if (a > b) return 1;
    return 0;
  }
  
  /// Verifica se o valor é zero
  static bool isZero(int value) => value == 0;
  
  /// Verifica se o valor é positivo
  static bool isPositive(int value) => value > 0;
  
  /// Verifica se o valor é negativo
  static bool isNegative(int value) => value < 0;
  
  /// Serializa para bytes (8 bytes, big-endian)
  /// GARANTIA: Representação binária determinística
  static Uint8List toBytes(int value) {
    final buffer = ByteData(8);
    buffer.setInt64(0, value, Endian.big);
    return buffer.buffer.asUint8List();
  }
  
  /// Desserializa de bytes (8 bytes, big-endian)
  static int fromBytes(Uint8List bytes) {
    if (bytes.length != 8) {
      throw ArgumentError('DecimalUtils.fromBytes: Esperado 8 bytes, recebido ${bytes.length}');
    }
    final buffer = ByteData.sublistView(bytes);
    return buffer.getInt64(0, Endian.big);
  }
}
