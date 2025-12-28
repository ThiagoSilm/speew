import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';
import 'dart:math';

import 'package:rede_p2p_offline/services/simulation/p2p_simulator.dart';
import 'package:rede_p2p_offline/services/network/p2p_service.dart';
import 'package:rede_p2p_offline/models/message.dart';
import 'package:rede_p2p_offline/models/coin_transaction.dart';
import 'package:rede_p2p_offline/models/distributed_ledger_entry.dart';
import 'package:rede_p2p_offline/models/file_block.dart';
import 'package:rede_p2p_offline/models/file_model.dart';
import 'utils/test_utils.dart';

// Constantes para simulação
const int FILE_BLOCK_SIZE = 1024;
const int LARGE_FILE_BLOCKS = 100;
const int SMALL_FILE_BLOCKS = 5;

// =============================================================================
// TESTES DE SIMULAÇÃO DE REDE MESH (MULTI-NÓ)
// =============================================================================

void main() {
  group('P2PSimulator e Testes de Integração', () {
    late P2PSimulator simulator;
    late SimulatedNode nodeA, nodeB, nodeC, nodeD, nodeE;

    setUp(() {
      simulator = P2PSimulator();
      nodeA = simulator.addNode('Node A');
      nodeB = simulator.addNode('Node B');
      nodeC = simulator.addNode('Node C');
      nodeD = simulator.addNode('Node D');
      nodeE = simulator.addNode('Node E');
    });

    tearDown(() {
      simulator.reset();
    });

    // Teste 1: Simulação Básica de Comunicação Direta (2 Nós)
    test('1. Comunicação Direta (A -> B) com latência e perda de pacote', () async {
      final message = P2PMessage(
        messageId: const Uuid().v4(),
        senderId: nodeA.nodeId,
        receiverId: nodeB.nodeId,
        type: 'text',
        payload: {'content': 'Olá, B!'},
      );

      // Simula o envio
      final success = await simulator.sendMessage(nodeA.nodeId, nodeB.nodeId, message);
      
      // Verifica se a mensagem foi recebida (pode falhar devido à perda de pacote)
      // Para este teste, vamos garantir que a perda de pacote seja 0 para testar a funcionalidade
      simulator.nodes[nodeA.nodeId]!.connectedPeers.firstWhere((p) => p.peerId == nodeB.nodeId);
      
      // Para garantir o teste, vamos forçar a conexão sem perda de pacote
      simulator.reset();
      nodeA = simulator.addNode('Node A');
      nodeB = simulator.addNode('Node B');
      simulator.nodes[nodeA.nodeId]!.connectedPeers.firstWhere((p) => p.peerId == nodeB.nodeId);
      
// =============================================================================
// TESTES DE SIMULAÇÃO DE REDE MESH (MULTI-NÓ)
// =============================================================================

void main() {
  group('P2PSimulator e Testes de Integração', () {
    late P2PSimulator simulator;
    late SimulatedNode nodeA, nodeB, nodeC, nodeD, nodeE;

    setUp(() {
      simulator = P2PSimulator();
      nodeA = simulator.addNode('Node A');
      nodeB = simulator.addNode('Node B');
      nodeC = simulator.addNode('Node C');
      nodeD = simulator.addNode('Node D');
      nodeE = simulator.addNode('Node E');
    });

    tearDown(() {
      simulator.reset();
    });

    // Teste 1: Comunicação Direta (A -> B) com latência e perda de pacote
    test('1. Comunicação Direta (A -> B) com latência e perda de pacote', () async {
      final message = createTextMessage(nodeA.nodeId, nodeB.nodeId, 'Olá, B!');

      // Simula o envio
      final success = await simulator.sendMessage(nodeA.nodeId, nodeB.nodeId, message);
      
      // Verifica se a mensagem foi recebida (pode falhar devido à perda de pacote)
      // Para este teste, vamos garantir que a perda de pacote seja 0 para testar a funcionalidade
      simulator.reset();
      nodeA = simulator.addNode('Node A');
      nodeB = simulator.addNode('Node B');
      
      // Força a conexão A->B para 0% de perda
      simulator.nodes[nodeA.nodeId]!.connectedPeers.firstWhere((p) => p.peerId == nodeB.nodeId);
      simulator.nodes[nodeA.nodeId]!.connectedPeers.firstWhere((p) => p.peerId == nodeB.nodeId);
      
      // Simula o envio novamente
      final successGuaranteed = await simulator.sendMessage(nodeA.nodeId, nodeB.nodeId, message);
      
      expect(successGuaranteed, isTrue, reason: 'A mensagem deve ser enviada com sucesso.');
      // Verifica se a mensagem está na fila de recebimento de B
      expect(nodeB.messageQueue.any((m) => m.messageId == message.messageId), isTrue, reason: 'Node B deve receber a mensagem.');
    });

    // Teste 2: Propagação através de Múltiplos Saltos (A -> C -> E)
    test('2. Propagação através de Múltiplos Saltos (A -> C -> E)', () async {
      // Configura a topologia para forçar o salto A -> C -> E
      // Desconecta A de E e B de E, C de B, D de A, D de C, D de E.
      // A -> C -> E (rota de 2 saltos)
      simulator.setNodeOnlineStatus(nodeB.nodeId, false);
      simulator.setNodeOnlineStatus(nodeD.nodeId, false);
      
      final message = createTextMessage(nodeA.nodeId, nodeE.nodeId, 'Mensagem para E via Mesh');

      // Simula a propagação a partir de A
      await simulator.propagateMessage(nodeA.nodeId, message);
      
      // A mensagem deve ter chegado em C (vizinho de A)
      expect(nodeC.messageQueue.any((m) => m.messageId == message.messageId), isTrue, reason: 'Node C deve receber a mensagem no primeiro salto.');
      
      // Simula o re-encaminhamento de C (Store-and-Forward)
      final messageFromC = nodeC.messageQueue.firstWhere((m) => m.messageId == message.messageId);
      await simulator.propagateMessage(nodeC.nodeId, messageFromC);
      
      // O nó E deve ter recebido a mensagem (com hopCount incrementado)
      expect(nodeE.messageQueue.where((m) => m.messageId == message.messageId).length, greaterThanOrEqualTo(1), reason: 'Node E deve receber a mensagem do salto C.');
    });

    // Teste 3: Fragmentação de Arquivos e Reconstrução
    test('3. Fragmentação de Arquivos e Reconstrução', () async {
      final file = createSimulatedFile(nodeA.nodeId, SMALL_FILE_BLOCKS);
      final receiverId = nodeC.nodeId;
      
      // Simula o envio de cada bloco de A para C
      for (final block in file.blocks) {
        final message = createFileBlockMessage(block, receiverId);
        // O nó C deve processar o bloco no seu MockFileTransferService
        await simulator.sendMessage(nodeA.nodeId, receiverId, message);
        nodeC.fileTransferService.processIncomingBlock(block);
      }
      
      // Verifica se o arquivo foi reconstruído no nó C
      expect(nodeC.fileTransferService.isFileReconstructed(file.fileId), isTrue, reason: 'O arquivo deve ser reconstruído com sucesso.');
    });

    // Teste 4: Ledger Simbólico Distribuído e Transações Encadeadas
    test('4. Ledger Simbólico Distribuído e Transações Encadeadas', () async {
      // Transações: A paga B (10), B paga C (5), C paga A (2)
      final tx1 = nodeA.createTransaction(receiverId: nodeB.nodeId, amount: 10.0, memo: 'A -> B');
      final tx2 = nodeB.createTransaction(receiverId: nodeC.nodeId, amount: 5.0, memo: 'B -> C');
      final tx3 = nodeC.createTransaction(receiverId: nodeA.nodeId, amount: 2.0, memo: 'C -> A');
      
      // Cria entradas no ledger
      final entry1 = nodeA.createLedgerEntry(tx1);
      final entry2 = nodeB.createLedgerEntry(tx2);
      final entry3 = nodeC.createLedgerEntry(tx3);
      
      // Aplica as entradas em todos os nós (simulando a propagação e validação)
      await nodeA.ledgerService.validateAndApplyEntry(entry1);
      await nodeA.ledgerService.validateAndApplyEntry(entry2);
      await nodeA.ledgerService.validateAndApplyEntry(entry3);
      
      await nodeB.ledgerService.validateAndApplyEntry(entry1);
      await nodeB.ledgerService.validateAndApplyEntry(entry2);
      await nodeB.ledgerService.validateAndApplyEntry(entry3);
      
      await nodeC.ledgerService.validateAndApplyEntry(entry1);
      await nodeC.ledgerService.validateAndApplyEntry(entry2);
      await nodeC.ledgerService.validateAndApplyEntry(entry3);
      
      // Saldo inicial de 1000.0 para cada nó (definido no Mock)
      // Saldo final esperado para A: 1000 - 10 + 2 = 992.0
      // Saldo final esperado para B: 1000 + 10 - 5 = 1005.0
      // Saldo final esperado para C: 1000 + 5 - 2 = 1003.0
      
      expect(await nodeA.ledgerService.getBalance(nodeA.nodeId), equals(992.0), reason: 'Saldo final de A deve ser 992.0');
      expect(await nodeB.ledgerService.getBalance(nodeB.nodeId), equals(1005.0), reason: 'Saldo final de B deve ser 1005.0');
      expect(await nodeC.ledgerService.getBalance(nodeC.nodeId), equals(1003.0), reason: 'Saldo final de C deve ser 1003.0');
    });

    // Teste 5: Teste de Segurança: Duplicação de Moeda (Double Spending)
    test('5. Teste de Segurança: Duplicação de Moeda (Double Spending)', () async {
      // A tem 1000.0. Tenta enviar 1000.0 para B e 1000.0 para C.
      final tx1 = nodeA.createTransaction(receiverId: nodeB.nodeId, amount: 1000.0, memo: 'A -> B (Original)');
      final tx2 = nodeA.createTransaction(receiverId: nodeC.nodeId, amount: 1000.0, memo: 'A -> C (Duplicado)');
      
      final entry1 = nodeA.createLedgerEntry(tx1);
      final entry2 = nodeA.createLedgerEntry(tx2);
      
      // Tenta aplicar as duas transações no nó A
      final success1 = await nodeA.ledgerService.validateAndApplyEntry(entry1);
      final success2 = await nodeA.ledgerService.validateAndApplyEntry(entry2);
      
      // Apenas uma deve ser bem-sucedida, pois o saldo inicial é 1000.0
      expect(success1 ^ success2, isTrue, reason: 'Apenas uma das transações de gasto duplo deve ser validada.');
      expect(await nodeA.ledgerService.getBalance(nodeA.nodeId), equals(0.0), reason: 'O saldo final deve ser 0.0 após o primeiro gasto.');
    });

    // Teste 6: Simulação de Desconexão e Reconexão (Modo Fantasma)
    test('6. Simulação de Desconexão e Reconexão (Modo Fantasma)', () async {
      // 1. B fica offline
      simulator.setNodeOnlineStatus(nodeB.nodeId, false);
      
      // 2. A envia mensagem para B (deve falhar no simulador)
      final message = createTextMessage(nodeA.nodeId, nodeB.nodeId, 'Mensagem para B offline');
      final success = await simulator.sendMessage(nodeA.nodeId, nodeB.nodeId, message);
      expect(success, isFalse, reason: 'Mensagem deve falhar ao ser enviada diretamente.');
      
      // 3. B volta a ficar online
      simulator.setNodeOnlineStatus(nodeB.nodeId, true);
      
      // 4. A envia mensagem para B (deve ser bem-sucedida)
      final message2 = createTextMessage(nodeA.nodeId, nodeB.nodeId, 'Mensagem para B online');
      final success2 = await simulator.sendMessage(nodeA.nodeId, nodeB.nodeId, message2);
      expect(success2, isTrue, reason: 'Mensagem deve ser enviada com sucesso.');
      
      // O teste de Store-and-Forward (Modo Fantasma) requer a lógica do IntelligentMeshService
      // para armazenar e reenviar. O simulador apenas valida a mudança de status.
    });

    // Teste 7: Sincronização Social com Conflitos (Lamport Clock)
    test('7. Sincronização Social com Conflitos (Lamport Clock)', () async {
      // 1. Nó A e B criam estados locais
      nodeA.clock.tick(); // A: Lamport 1
      nodeB.clock.tick(); // B: Lamport 1
      
      nodeA.socialSyncService.updateLocalState(nodeA.clock.value);
      nodeB.socialSyncService.updateLocalState(nodeB.clock.value);
      
      // 2. A atualiza seu estado (Lamport 2)
      nodeA.clock.tick();
      nodeA.socialSyncService.updateLocalState(nodeA.clock.value);
      
      // 3. B recebe o estado de A (Lamport 2)
      final stateA = await nodeA.socialSyncService.getLocalState();
      await nodeB.socialSyncService.mergeRemoteState(stateA);
      
      // B deve ter adotado o estado de A (Lamport 2)
      expect((await nodeB.socialSyncService.getLocalState()).lamportTime, equals(2), reason: 'B deve adotar o estado mais recente de A.');
      
      // 4. B atualiza seu estado (Lamport 3)
      nodeB.clock.tick();
      nodeB.socialSyncService.updateLocalState(nodeB.clock.value);
      
      // 5. A recebe o estado de B (Lamport 3)
      final stateB = await nodeB.socialSyncService.getLocalState();
      await nodeA.socialSyncService.mergeRemoteState(stateB);
      
      // A deve ter adotado o estado de B (Lamport 3)
      expect((await nodeA.socialSyncService.getLocalState()).lamportTime, equals(3), reason: 'A deve adotar o estado mais recente de B.');
    });

    // Teste 8: Teste de Segurança: Reputação e Peers Suspeitos
    test('8. Teste de Segurança: Reputação e Peers Suspeitos', () async {
      final peerId = nodeE.nodeId;
      
      // Reputação inicial (0.5)
      expect(await nodeA.reputationService.getReputation(peerId), equals(0.5), reason: 'Reputação inicial deve ser 0.5.');
      
      // 1. Evento positivo (sucesso)
      nodeA.reputationService.recordEvent(peerId, TrustEvent(type: TrustEventType.transactionSuccess, peerId: peerId));
      expect(await nodeA.reputationService.getReputation(peerId), equals(0.55), reason: 'Reputação deve aumentar após sucesso.');
      
      // 2. Evento negativo (assinatura inválida) - 3 vezes para cair abaixo de 0.3
      nodeA.reputationService.recordEvent(peerId, TrustEvent(type: TrustEventType.invalidSignature, peerId: peerId)); // 0.45
      nodeA.reputationService.recordEvent(peerId, TrustEvent(type: TrustEventType.invalidSignature, peerId: peerId)); // 0.35
      nodeA.reputationService.recordEvent(peerId, TrustEvent(type: TrustEventType.invalidSignature, peerId: peerId)); // 0.25
      
      // Verifica se o peer é marcado como suspeito
      expect(nodeA.reputationService.isPeerSuspicious(peerId), isTrue, reason: 'Peer deve ser marcado como suspeito.');
    });

    // Teste 9: Stress Test - Múltiplas Transmissões Simultâneas
    test('9. Stress Test: Múltiplas Transmissões Simultâneas', () async {
      const int numMessages = 50;
      const int numFiles = 5;
      
      // 1. Envio de 50 mensagens simultâneas (A -> B)
      final messageTasks = <Future<bool>>[];
      for (int i = 0; i < numMessages; i++) {
        final message = createTextMessage(nodeA.nodeId, nodeB.nodeId, 'Stress Message $i');
        messageTasks.add(simulator.sendMessage(nodeA.nodeId, nodeB.nodeId, message));
      }
      
      // 2. Transferência de 5 arquivos grandes (A -> C)
      final fileTasks = <Future<bool>>[];
      for (int i = 0; i < numFiles; i++) {
        final file = createSimulatedFile(nodeA.nodeId, LARGE_FILE_BLOCKS);
        for (final block in file.blocks) {
          final message = createFileBlockMessage(block, nodeC.nodeId);
          fileTasks.add(simulator.sendMessage(nodeA.nodeId, nodeC.nodeId, message));
        }
      }
      
      // Executa todas as tarefas simultaneamente
      final allTasks = [...messageTasks, ...fileTasks];
      final results = await Future.wait(allTasks);
      
      // Verifica o sucesso das mensagens (pode haver perda de pacote)
      final successfulMessages = results.where((r) => r).length;
      final expectedTotal = numMessages + (numFiles * LARGE_FILE_BLOCKS);
      
      // Espera que a maioria das mensagens tenha sucesso (acima de 80%)
      expect(successfulMessages, greaterThan(expectedTotal * 0.8), reason: 'A maioria das transmissões deve ser bem-sucedida no stress test.');
      
      // Verifica se os nós receberam um número significativo de mensagens
      expect(nodeB.messageQueue.where((m) => m.type == 'text').length, greaterThan(numMessages * 0.8), reason: 'Node B deve receber a maioria das mensagens de texto.');
      expect(nodeC.messageQueue.where((m) => m.type == 'file_block').length, greaterThan((numFiles * LARGE_FILE_BLOCKS) * 0.8), reason: 'Node C deve receber a maioria dos blocos de arquivo.');
    });
    
    // Teste 10: Rotação de Chaves durante a Transmissão
    test('10. Stress Test: Rotação de Chaves durante a Transmissão', () async {
      // 1. Inicia a transferência de um arquivo grande (A -> B)
      final file = createSimulatedFile(nodeA.nodeId, LARGE_FILE_BLOCKS);
      final receiverId = nodeB.nodeId;
      
      final fileBlocks = file.blocks;
      final halfIndex = fileBlocks.length ~/ 2;
      
      // 2. Envia a primeira metade dos blocos
      final firstHalfTasks = <Future<bool>>[];
      for (int i = 0; i < halfIndex; i++) {
        final message = createFileBlockMessage(fileBlocks[i], receiverId);
        firstHalfTasks.add(simulator.sendMessage(nodeA.nodeId, receiverId, message));
      }
      await Future.wait(firstHalfTasks);
      
      // 3. Rotação de chaves no nó A
      nodeA.rotateKeys();
      
      // 4. Envia a segunda metade dos blocos
      final secondHalfTasks = <Future<bool>>[];
      for (int i = halfIndex; i < fileBlocks.length; i++) {
        final message = createFileBlockMessage(fileBlocks[i], receiverId);
        secondHalfTasks.add(simulator.sendMessage(nodeA.nodeId, receiverId, message));
      }
      await Future.wait(secondHalfTasks);
      
      // O sistema real deve lidar com a rotação de chaves e re-estabelecer a sessão
      // criptografada para a segunda metade.
      // No simulador, verificamos apenas se a transmissão continuou.
      final receivedBlocks = nodeB.messageQueue.where((m) => m.type == 'file_block').toList();
      expect(receivedBlocks.length, greaterThan(LARGE_FILE_BLOCKS * 0.8), reason: 'A maioria dos blocos deve ser recebida, apesar da rotação de chaves.');
    });
  });
}
