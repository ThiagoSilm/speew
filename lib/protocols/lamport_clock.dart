/// Implementação de Lamport Clock para ordenação causal de eventos em sistemas distribuídos
/// Usado para resolver conflitos e manter consistência temporal sem sincronização de relógio
class LamportClock {
  /// Contador lógico atual
  int _counter;
  
  /// ID do nó (dispositivo) que possui este relógio
  final String nodeId;

  LamportClock({
    required this.nodeId,
    int initialCounter = 0,
  }) : _counter = initialCounter;

  /// Retorna o valor atual do contador
  int get counter => _counter;

  /// Incrementa o contador antes de enviar uma mensagem
  int tick() {
    _counter++;
    return _counter;
  }

  /// Atualiza o contador ao receber uma mensagem
  /// Regra: counter = max(local_counter, received_counter) + 1
  void update(int receivedCounter) {
    _counter = (_counter > receivedCounter ? _counter : receivedCounter) + 1;
  }

  /// Compara dois timestamps Lamport
  /// Retorna:
  ///   -1 se este timestamp é anterior
  ///    0 se são concorrentes (usa nodeId como desempate)
  ///    1 se este timestamp é posterior
  int compareTo(LamportClock other) {
    if (_counter < other._counter) {
      return -1;
    } else if (_counter > other._counter) {
      return 1;
    } else {
      // Contadores iguais: usar nodeId como desempate
      return nodeId.compareTo(other.nodeId);
    }
  }

  /// Cria um timestamp Lamport com o contador atual
  LamportTimestamp createTimestamp() {
    return LamportTimestamp(
      counter: _counter,
      nodeId: nodeId,
      wallClockTime: DateTime.now(),
    );
  }

  /// Converte para Map
  Map<String, dynamic> toMap() {
    return {
      'counter': _counter,
      'node_id': nodeId,
    };
  }

  /// Cria a partir de Map
  factory LamportClock.fromMap(Map<String, dynamic> map) {
    return LamportClock(
      nodeId: map['node_id'] as String,
      initialCounter: map['counter'] as int,
    );
  }
}

/// Representa um timestamp Lamport específico (imutável)
class LamportTimestamp {
  /// Valor do contador lógico
  final int counter;
  
  /// ID do nó que criou este timestamp
  final String nodeId;
  
  /// Timestamp de relógio de parede (para referência humana)
  final DateTime wallClockTime;

  LamportTimestamp({
    required this.counter,
    required this.nodeId,
    required this.wallClockTime,
  });

  /// Compara dois timestamps
  int compareTo(LamportTimestamp other) {
    if (counter < other.counter) {
      return -1;
    } else if (counter > other.counter) {
      return 1;
    } else {
      // Contadores iguais: usar nodeId como desempate
      return nodeId.compareTo(other.nodeId);
    }
  }

  /// Verifica se este timestamp é anterior ao outro
  bool isBefore(LamportTimestamp other) {
    return compareTo(other) < 0;
  }

  /// Verifica se este timestamp é posterior ao outro
  bool isAfter(LamportTimestamp other) {
    return compareTo(other) > 0;
  }

  /// Verifica se os timestamps são concorrentes
  bool isConcurrentWith(LamportTimestamp other) {
    return compareTo(other) == 0;
  }

  /// Converte para Map (Serialização Compacta)
  Map<String, dynamic> toMap() {
    return {
      // I.1: Nomes curtos e timestamp Unix
      'c': counter,
      'nid': nodeId,
      'wct': wallClockTime.millisecondsSinceEpoch,
    };
  }

  /// Cria a partir de Map (Deserialização Compacta)
  factory LamportTimestamp.fromMap(Map<String, dynamic> map) {
    return LamportTimestamp(
      // I.1: Nomes curtos e timestamp Unix
      counter: map['c'] as int,
      nodeId: map['nid'] as String,
      wallClockTime: DateTime.fromMillisecondsSinceEpoch(map['wct'] as int),
    );
  }

  /// Converte para string legível
  @override
  String toString() {
    return 'LamportTimestamp(counter: $counter, nodeId: $nodeId, time: ${wallClockTime.toIso8601String()})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LamportTimestamp &&
        other.counter == counter &&
        other.nodeId == nodeId;
  }

  @override
  int get hashCode => counter.hashCode ^ nodeId.hashCode;
}
