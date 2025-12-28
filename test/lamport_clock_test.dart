import 'package:flutter_test/flutter_test.dart';
import 'package:rede_p2p_offline/models/lamport_clock.dart';

void main() {
  group('LamportClock - Operações Básicas', () {
    test('Deve inicializar com contador zero', () {
      final clock = LamportClock(nodeId: 'node1');
      expect(clock.counter, equals(0));
      expect(clock.nodeId, equals('node1'));
    });

    test('Deve incrementar contador ao fazer tick', () {
      final clock = LamportClock(nodeId: 'node1');
      final timestamp1 = clock.tick();
      expect(timestamp1.counter, equals(1));
      expect(timestamp1.nodeId, equals('node1'));

      final timestamp2 = clock.tick();
      expect(timestamp2.counter, equals(2));
    });

    test('Deve atualizar ao receber mensagem', () {
      final clock1 = LamportClock(nodeId: 'node1');
      final clock2 = LamportClock(nodeId: 'node2');

      // Node1 faz 3 ticks
      clock1.tick();
      clock1.tick();
      final ts = clock1.tick(); // counter = 3

      // Node2 recebe mensagem de Node1
      clock2.update(ts);
      expect(clock2.counter, equals(4)); // max(0, 3) + 1
    });

    test('Deve manter contador maior ao receber mensagem antiga', () {
      final clock1 = LamportClock(nodeId: 'node1');
      final clock2 = LamportClock(nodeId: 'node2');

      // Node2 avança muito
      for (int i = 0; i < 10; i++) {
        clock2.tick();
      }
      expect(clock2.counter, equals(10));

      // Node1 envia mensagem com contador baixo
      final ts = clock1.tick(); // counter = 1

      // Node2 recebe
      clock2.update(ts);
      expect(clock2.counter, equals(11)); // max(10, 1) + 1
    });
  });

  group('LamportTimestamp - Comparação', () {
    test('Deve comparar timestamps corretamente por contador', () {
      final ts1 = LamportTimestamp(counter: 5, nodeId: 'node1');
      final ts2 = LamportTimestamp(counter: 10, nodeId: 'node2');

      expect(ts1.compareTo(ts2), lessThan(0)); // ts1 < ts2
      expect(ts2.compareTo(ts1), greaterThan(0)); // ts2 > ts1
    });

    test('Deve usar nodeId como desempate', () {
      final ts1 = LamportTimestamp(counter: 5, nodeId: 'nodeA');
      final ts2 = LamportTimestamp(counter: 5, nodeId: 'nodeB');

      expect(ts1.compareTo(ts2), lessThan(0)); // 'nodeA' < 'nodeB'
      expect(ts2.compareTo(ts1), greaterThan(0));
    });

    test('Deve considerar timestamps iguais', () {
      final ts1 = LamportTimestamp(counter: 5, nodeId: 'node1');
      final ts2 = LamportTimestamp(counter: 5, nodeId: 'node1');

      expect(ts1.compareTo(ts2), equals(0));
      expect(ts1 == ts2, isTrue);
    });

    test('Deve detectar concorrência', () {
      final ts1 = LamportTimestamp(counter: 5, nodeId: 'node1');
      final ts2 = LamportTimestamp(counter: 5, nodeId: 'node2');

      // Timestamps com mesmo contador mas nós diferentes são concorrentes
      expect(ts1.isConcurrentWith(ts2), isTrue);
    });

    test('Deve detectar ordem causal', () {
      final ts1 = LamportTimestamp(counter: 5, nodeId: 'node1');
      final ts2 = LamportTimestamp(counter: 10, nodeId: 'node1');

      // ts1 aconteceu antes de ts2
      expect(ts1.isConcurrentWith(ts2), isFalse);
      expect(ts1.compareTo(ts2), lessThan(0));
    });
  });

  group('LamportClock - Serialização', () {
    test('Deve serializar e desserializar corretamente', () {
      final clock = LamportClock(nodeId: 'node1');
      clock.tick();
      clock.tick();
      clock.tick();

      final json = clock.toMap();
      expect(json['counter'], equals(3));
      expect(json['nodeId'], equals('node1'));

      final restored = LamportClock.fromMap(json);
      expect(restored.counter, equals(3));
      expect(restored.nodeId, equals('node1'));
    });

    test('Deve serializar timestamp corretamente', () {
      final ts = LamportTimestamp(counter: 42, nodeId: 'test-node');
      final json = ts.toMap();

      expect(json['counter'], equals(42));
      expect(json['nodeId'], equals('test-node'));

      final restored = LamportTimestamp.fromMap(json);
      expect(restored.counter, equals(42));
      expect(restored.nodeId, equals('test-node'));
    });
  });

  group('LamportClock - Cenários Distribuídos', () {
    test('Deve manter ordem causal em rede de 3 nós', () {
      final node1 = LamportClock(nodeId: 'node1');
      final node2 = LamportClock(nodeId: 'node2');
      final node3 = LamportClock(nodeId: 'node3');

      // Node1 envia para Node2
      final ts1 = node1.tick();
      node2.update(ts1);

      // Node2 envia para Node3
      final ts2 = node2.tick();
      node3.update(ts2);

      // Verificar ordem causal
      expect(ts1.compareTo(ts2), lessThan(0)); // ts1 < ts2
      expect(node3.counter, greaterThan(node2.counter));
      expect(node3.counter, greaterThan(node1.counter));
    });

    test('Deve detectar eventos concorrentes', () {
      final node1 = LamportClock(nodeId: 'node1');
      final node2 = LamportClock(nodeId: 'node2');

      // Ambos fazem eventos locais sem comunicação
      final ts1 = node1.tick();
      final ts2 = node2.tick();

      // Eventos são concorrentes (não há relação causal)
      expect(ts1.isConcurrentWith(ts2), isTrue);
    });

    test('Deve resolver conflitos deterministicamente', () {
      final ts1 = LamportTimestamp(counter: 5, nodeId: 'alice');
      final ts2 = LamportTimestamp(counter: 5, nodeId: 'bob');

      // Sempre escolhe o mesmo vencedor (ordem alfabética)
      expect(ts1.compareTo(ts2), lessThan(0));
      expect(ts2.compareTo(ts1), greaterThan(0));

      // Múltiplas comparações devem ser consistentes
      for (int i = 0; i < 100; i++) {
        expect(ts1.compareTo(ts2), lessThan(0));
      }
    });
  });
}
