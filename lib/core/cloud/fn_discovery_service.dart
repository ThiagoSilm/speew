import 'dart:async';
import 'package:rede_p2p_refactored/core/cloud/fixed_node_client.dart';
import 'package:rede_p2p_refactored/core/reputation/reputation_core.dart';
import 'package:rede_p2p_refactored/core/utils/logger_service.dart';
import 'package:rede_p2p_refactored/lib/services/ledger/distributed_ledger_service.dart'; // Assumindo este caminho

class FNDiscoveryService {
  final LoggerService _logger = LoggerService('FNDiscoveryService');
  final ReputationCore _reputationCore;
  final DistributedLedgerService _ledgerService;
  
  // Cache local de FNs verificados
  final Map<String, FixedNode> _fnCache = {};

  FNDiscoveryService(this._reputationCore, this._ledgerService);

  // Lista inicial de FNs (hard-coded para simulação)
  final List<FixedNode> _initialFNs = [
    FixedNode(id: 'fn_alpha', address: 'fn.alpha.com', port: 443, reputationScore: 0.98),
    FixedNode(id: 'fn_beta', address: 'fn.beta.net', port: 443, reputationScore: 0.96),
    FixedNode(id: 'fn_gamma', address: 'fn.gamma.org', port: 443, reputationScore: 0.99),
  ];

  Future<void> initialize() async {
    _logger.info('Inicializando Fixed Node Discovery Service...');
    // 1. Carregar lista inicial e atualizar cache
    for (var fn in _initialFNs) {
      _fnCache[fn.id] = fn;
    }
    await _discoverFNsFromLedger();
    _updateReputationScores();
    _logger.info('Cache inicializado com ${_fnCache.length} Fixed Nodes.');
  }

  // Capacidade de descobrir FNs por DNS ou por um contrato inteligente (Smart Contract) no Ledger.
  Future<void> _discoverFNsFromLedger() async {
    _logger.debug('Buscando FNs registrados no Distributed Ledger...');
    try {
      // Simulação de busca no Ledger por FNs
      final ledgerFNs = await _ledgerService.getRegisteredFixedNodes();
      
      for (var fnData in ledgerFNs) {
        final id = fnData['id'] as String;
        if (!_fnCache.containsKey(id)) {
          final newFN = FixedNode(
            id: id,
            address: fnData['address'] as String,
            port: fnData['port'] as int,
            reputationScore: 0.0, // Será atualizado na próxima etapa
          );
          _fnCache[id] = newFN;
          _logger.debug('Novo FN descoberto via Ledger: $id');
        }
      }
    } catch (e) {
      _logger.error('Falha ao buscar FNs no Ledger: $e');
    }
  }

  // Manter um cache local de FNs verificados e seus respectivos Reputation Scores
  void _updateReputationScores() {
    _fnCache.forEach((id, fn) {
      // O FN também deve ser pontuado!
      fn.reputationScore = _reputationCore.getReputationScore(id);
    });
  }

  // Retorna a lista de FNs, ordenada por Reputação (decrescente) e Latência (crescente)
  List<FixedNode> getAvailableFixedNodes() {
    _updateReputationScores(); // Garantir que os scores estejam atualizados
    return _fnCache.values.where((fn) => fn.reputationScore >= 0.95).toList()
      ..sort((a, b) {
        // Prioriza maior reputação
        int repCompare = b.reputationScore.compareTo(a.reputationScore);
        if (repCompare != 0) return repCompare;
        // Em caso de empate, prioriza menor latência (se conhecida)
        return a.latency.compareTo(b.latency);
      });
  }
}

// Mock para simular o DistributedLedgerService, necessário para compilação
class DistributedLedgerService {
  Future<List<Map<String, dynamic>>> getRegisteredFixedNodes() async {
    // Simulação de FNs registrados no Ledger
    return [
      {'id': 'fn_delta', 'address': 'fn.delta.io', 'port': 443},
      {'id': 'fn_epsilon', 'address': 'fn.epsilon.co', 'port': 443},
    ];
  }
}
