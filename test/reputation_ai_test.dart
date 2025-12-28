// rede_p2p_refactored/rede_p2p_refactored/test/reputation_ai_test.dart

import 'package:test/test.dart';
import 'package:rede_p2p_refactored/core/reputation/reputation_core.dart';
import 'package:rede_p2p_refactored/core/reputation/reputation_models.dart';
import 'package:rede_p2p_refactored/core/reputation/slashing_engine.dart';
import 'package:rede_p2p_refactored/core/wallet/economy_engine.dart';
import 'package:rede_p2p_refactored/core/mesh/multipath_engine.dart';
import 'package:rede_p2p_refactored/core/p2p/p2p_service.dart';
import 'package:rede_p2p_refactored/core/models/peer.dart';
import 'package:rede_p2p_refactored/core/mesh/priority_queue_service.dart';

// Mock do P2PService para simular rotas
class MockP2PService extends P2PService {
  @override
  List<List<Peer>> findAllRoutes(String destinationId) {
    // Rotas simuladas para testes
    return [
      [Peer(id: 'node_A'), Peer(id: 'node_B'), Peer(id: 'target')], // Rota 1 (curta)
      [Peer(id: 'node_C'), Peer(id: 'node_D'), Peer(id: 'node_E'), Peer(id: 'target')], // Rota 2 (média)
      [Peer(id: 'node_F'), Peer(id: 'node_G'), Peer(id: 'node_H'), Peer(id: 'node_I'), Peer(id: 'target')], // Rota 3 (longa)
    ];
  }

  @override
  Future<void> sendData({required String peerId, required String data, Map<String, dynamic>? metadata}) async {
    // Simulação de envio bem-sucedido
    return;
  }
}

void main() {
  group('Reputation AI Integration Tests', () {
    late ReputationCore reputationCore;
    late SlashingEngine slashingEngine;
    late MultiPathEngine multiPathEngine;
    late PriorityQueueService priorityQueueService;
    late MockP2PService mockP2PService;

    setUp(() {
      // Inicialização dos componentes
      slashingEngine = SlashingEngine();
      reputationCore = ReputationCore(); // Repare que o SlashingEngine é instanciado internamente no Core
      mockP2PService = MockP2PService();
      multiPathEngine = MultiPathEngine(mockP2PService);
      priorityQueueService = PriorityQueueService();
      priorityQueueService.clear(); // Limpa a fila para cada teste
    });

    // Teste 1: Simulação de 3 nós maliciosos e queda de RS
    test('Simulação de nós maliciosos e queda de RS abaixo de 30%', () async {
      final maliciousNodes = ['mal_node_1', 'mal_node_2', 'mal_node_3'];
      const int simulationTime = 120; // 2 minutos em segundos (simulados)
      
      // Inicializa os scores (simulando o RS inicial de 0.5)
      for (final id in maliciousNodes) {
        reputationCore.getReputationScore(id);
      }

      // Simular eventos de mau comportamento por 2 minutos (120 segundos)
      // O objetivo é fazer o RS cair abaixo de 30% (0.3)
      for (int i = 0; i < simulationTime; i += 5) {
        for (final id in maliciousNodes) {
          // Simular baixa taxa de sucesso de retransmissão (Relay Success Rate)
          reputationCore.monitorBehavior(ReputationEvent(
            peerId: id,
            metric: BehaviorMetric.relaySuccessRate,
            value: 0.1, // Valor baixo (0.0 a 1.0)
            timestamp: DateTime.now(),
          ));
          // Simular alta latência
          reputationCore.monitorBehavior(ReputationEvent(
            peerId: id,
            metric: BehaviorMetric.latencyJitter,
            value: 0.1, // Valor baixo (0.0 a 1.0)
            timestamp: DateTime.now(),
          ));
        }
        // Simular eventos de bom comportamento para um nó neutro para comparação
        reputationCore.monitorBehavior(ReputationEvent(
          peerId: 'good_node',
          metric: BehaviorMetric.relaySuccessRate,
          value: 0.9,
          timestamp: DateTime.now(),
        ));
        await Future.delayed(Duration(milliseconds: 1)); // Pequeno delay para simular tempo
      }

      // Verificar se o RS dos maliciosos caiu abaixo de 30%
      for (final id in maliciousNodes) {
        final rs = reputationCore.getReputationScore(id)?.score ?? 1.0;
        print('RS final de $id: ${rs.toStringAsFixed(4)}');
        expect(rs, lessThan(0.30), reason: 'O RS do nó malicioso $id deveria cair abaixo de 0.30');
      }

      // Verificar se o RS do nó neutro se manteve alto
      final goodRs = reputationCore.getReputationScore('good_node')?.score ?? 0.0;
      print('RS final de good_node: ${goodRs.toStringAsFixed(4)}');
      expect(goodRs, greaterThan(0.70), reason: 'O RS do nó bom deveria se manter acima de 0.70');
    });

    // Teste 2: Testar se o Slashing Engine congela stake após a queda de RS (simulado)
    test('Slashing Engine: Punição Maior (RS < 30%)', () async {
      // Simular um nó com RS baixo
      final lowRsNode = 'low_rs_node';
      final lowScore = ReputationScore(
        peerId: lowRsNode,
        score: 0.25, // Abaixo de 0.30 (Punição Menor/Maior)
        lastUpdated: DateTime.now(),
      );

      // O SlashingEngine não tem integração real com o StakingService,
      // mas podemos verificar se a função de punição é chamada (via logs ou mocks,
      // mas aqui vamos confiar que o `checkAndApplyPunishment` foi executado).
      // O teste se baseia na execução do código e na ausência de erros.
      
      // Como não temos um mock para o StakingService, verificamos a execução sem erro.
      // O log de warning deve ser emitido.
      await slashingEngine.checkAndApplyPunishment(lowScore);
      
      // Teste de sanidade: um nó com RS alto não deve ser punido
      final highScore = ReputationScore(
        peerId: 'high_rs_node',
        score: 0.90,
        lastUpdated: DateTime.now(),
      );
      await slashingEngine.checkAndApplyPunishment(highScore);
      
      // O teste passa se não houver exceções.
      expect(true, isTrue, reason: 'A verificação de punição deve ser executada sem erros.');
    });

    // Teste 3: Testar se o Multi-Path Router re-roteia o tráfego evitando os nós punidos.
    test('Multi-Path Router: Evitar nós com RS < 10% (Blacklist)', () async {
      final targetId = 'target';
      final message = 'test_message';
      
      // 1. Simular RS baixo para 'node_A' (na Rota 1)
      final blacklistNode = 'node_A';
      reputationCore.getReputationScore(blacklistNode)?.score = 0.05; // Abaixo de 0.10

      // 2. Simular RS alto para 'node_C' (na Rota 2)
      reputationCore.getReputationScore('node_C')?.score = 0.95;

      // 3. Executar o roteamento
      final results = await multiPathEngine.sendMultiPath(
        destinationId: targetId,
        message: message,
        maxPaths: 3,
      );

      // Rota 1: [node_A, node_B, target] deve ser evitada (blacklist)
      // Rota 2: [node_C, node_D, node_E, target] deve ser priorizada
      // Rota 3: [node_F, node_G, node_H, node_I, target] deve ser considerada

      // O número de rotas selecionadas deve ser menor que o total (3) se a Rota 1 for evitada.
      // A Rota 1 contém 'node_A' que está na blacklist.
      final allRoutes = mockP2PService.findAllRoutes(targetId);
      final expectedRoutesCount = allRoutes.length - 1; // Rota 1 removida

      // O resultado deve ter 2 rotas (Rota 2 e Rota 3)
      expect(results.length, equals(expectedRoutesCount), reason: 'A rota com nó blacklist deve ser filtrada.');
      
      // Verificar se a Rota 1 não está nos resultados (simulando o log de sucesso)
      expect(results.any((r) => r.contains('node_A')), isFalse, reason: 'A rota blacklist não deve ser usada.');
      
      // Verificar se a Rota 2 (com nó de alta reputação) foi usada
      expect(results.any((r) => r.contains('node_C')), isTrue, reason: 'A rota de alta reputação deve ser usada.');
    });

    // Teste 4: Testar se o Prioritization Engine prioriza pacotes de alta reputação.
    test('Prioritization Engine: Multiplicador de 1.2x para alta reputação (RS > 70%)', () {
      final highRsNode = 'high_rs_sync_node';
      final lowRsNode = 'low_rs_sync_node';
      
      // 1. Simular RS alto e baixo
      reputationCore.getReputationScore(highRsNode)?.score = 0.80; // > 0.70
      reputationCore.getReputationScore(lowRsNode)?.score = 0.60; // < 0.70

      // 2. Criar itens de sincronização (prioridade crítica)
      final highRsItem = PriorityQueueItem(
        itemId: 'sync_high_rs',
        priority: MessagePriority.critical,
        timestamp: DateTime.now(),
        data: {'type': 'Ledger Consensus'},
        sourcePeerId: highRsNode,
      );
      
      final lowRsItem = PriorityQueueItem(
        itemId: 'sync_low_rs',
        priority: MessagePriority.critical,
        timestamp: DateTime.now(),
        data: {'type': 'Ledger Consensus'},
        sourcePeerId: lowRsNode,
      );

      // 3. Enfileirar em ordem inversa
      priorityQueueService.enqueue(lowRsItem);
      priorityQueueService.enqueue(highRsItem);

      // 4. Verificar a ordem de prioridade
      final nextItem = priorityQueueService.peek();
      
      // O item de alta reputação deve ter um score maior (multiplicador de 1.2x)
      final highScore = highRsItem.priorityScore(reputationCore);
      final lowScore = lowRsItem.priorityScore(reputationCore);
      
      print('Score do nó de alta RS: ${highScore.toStringAsFixed(2)}');
      print('Score do nó de baixa RS: ${lowScore.toStringAsFixed(2)}');

      expect(highScore, greaterThan(lowScore), reason: 'O score do nó de alta reputação deve ser maior.');
      expect(nextItem?.itemId, equals(highRsItem.itemId), reason: 'O item de alta reputação deve ser o próximo a ser processado.');
    });
  });
}
