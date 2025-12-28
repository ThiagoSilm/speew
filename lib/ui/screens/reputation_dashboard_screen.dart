// rede_p2p_refactored/rede_p2p_refactored/lib/ui/screens/reputation_dashboard_screen.dart

import 'package:flutter/material.dart';
import 'package:rede_p2p_refactored/core/reputation/reputation_core.dart';
import 'package:rede_p2p_refactored/core/reputation/reputation_models.dart';
import 'package:rede_p2p_refactored/core/reputation/slashing_engine.dart';
import 'package:rede_p2p_refactored/core/utils/logger_service.dart';
import 'package:rede_p2p_refactored/lib/ui/components/app_button.dart'; // Assumindo que existe um componente AppButton

/// Tela de Reputação de Nó (ReputationDashboardScreen)
class ReputationDashboardScreen extends StatefulWidget {
  const ReputationDashboardScreen({super.key});

  @override
  State<ReputationDashboardScreen> createState() => _ReputationDashboardScreenState();
}

class _ReputationDashboardScreenState extends State<ReputationDashboardScreen> {
  final ReputationCore _reputationCore = ReputationCore();
  final SlashingEngine _slashingEngine = SlashingEngine();
  final LoggerService _logger = LoggerService('ReputationDashboardScreen');

  ReputationScore? _localReputation;
  Map<String, List<ReputationScore>> _peerScores = {'best': [], 'worst': []};
  Map<String, dynamic> _slashingStatus = {};
  bool _strictMode = false;

  @override
  void initState() {
    super.initState();
    _loadData();
    // Assinar atualizações de score
    _reputationCore.scoreUpdates.listen((score) {
      if (mounted) {
        setState(() {
          // Simulação: Se o score for do nó local (ID 'local_node'), atualiza
          if (score.peerId == 'local_node') {
            _localReputation = score;
          }
          _peerScores = _reputationCore.getTopAndWorstPeers();
        });
      }
    });
  }

  Future<void> _loadData() async {
    // Simulação de obtenção do RS local
    _localReputation = _reputationCore.getReputationScore('local_node') ??
        ReputationScore(peerId: 'local_node', score: 0.85, lastUpdated: DateTime.now());

    _peerScores = _reputationCore.getTopAndWorstPeers();
    _slashingStatus = _slashingEngine.getSlashingStatus();

    if (mounted) {
      setState(() {});
    }
  }

  void _toggleStrictMode(bool value) {
    setState(() {
      _strictMode = value;
      _logger.info('Modo de Reputação Estrita ${value ? 'ATIVADO' : 'DESATIVADO'}');
      // TODO: Implementar a lógica de roteamento para evitar nós < 50% quando ativado.
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reputation AI Dashboard'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            _buildLocalReputationCard(),
            const SizedBox(height: 20),
            _buildSlashingStatusCard(),
            const SizedBox(height: 20),
            _buildStrictModeToggle(),
            const SizedBox(height: 20),
            _buildPeerScoresList('Melhores Peers', _peerScores['best'] ?? []),
            const SizedBox(height: 20),
            _buildPeerScoresList('Piores Peers', _peerScores['worst'] ?? []),
          ],
        ),
      ),
    );
  }

  Widget _buildLocalReputationCard() {
    final rs = (_localReputation?.score ?? 0.0) * 100;
    final color = rs > 70 ? Colors.green : (rs > 30 ? Colors.orange : Colors.red);

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Sua Reputação (RS)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.security, color: color, size: 30),
                const SizedBox(width: 10),
                Text(
                  '${rs.toStringAsFixed(2)}%',
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: color),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Última Atualização: ${_localReputation?.lastUpdated.toLocal().toString().split('.').first ?? 'N/A'}'),
          ],
        ),
      ),
    );
  }

  Widget _buildSlashingStatusCard() {
    final totalPunished = _slashingStatus['totalPunished'] ?? 0.0;
    final totalStaked = _slashingStatus['totalStaked'] ?? 0.0;
    final status = _slashingStatus['status'] ?? 'Desconhecido';

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Slashing Engine Status', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Status: $status', style: TextStyle(color: status == 'Operacional' ? Colors.green : Colors.red)),
            const SizedBox(height: 4),
            Text('Total Punido (Tokens): ${totalPunished.toStringAsFixed(2)}'),
            const SizedBox(height: 4),
            Text('Total em Stake (Tokens): ${totalStaked.toStringAsFixed(2)}'),
          ],
        ),
      ),
    );
  }

  Widget _buildStrictModeToggle() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Modo de Reputação Estrita', style: TextStyle(fontSize: 16)),
            Switch(
              value: _strictMode,
              onChanged: _toggleStrictMode,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPeerScoresList(String title, List<ReputationScore> scores) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        scores.isEmpty
            ? const Text('Nenhum peer para exibir.')
            : ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: scores.length,
                itemBuilder: (context, index) {
                  final score = scores[index];
                  final rs = score.score * 100;
                  final color = rs > 70 ? Colors.green : (rs > 30 ? Colors.orange : Colors.red);
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: color.withOpacity(0.2),
                      child: Text(rs.toStringAsFixed(0), style: TextStyle(color: color, fontWeight: FontWeight.bold)),
                    ),
                    title: Text('Peer ID: ${score.peerId.substring(0, 8)}...'),
                    trailing: Text('${rs.toStringAsFixed(2)}%', style: TextStyle(color: color)),
                  );
                },
              ),
      ],
    );
  }
}
