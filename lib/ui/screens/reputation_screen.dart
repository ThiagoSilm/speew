import '../../services/reputation/reputation_service.dart';
import 'package:flutter/material.dart';

/// Tela de reputação do usuário
/// Exibe score, interações e estatísticas
class ReputationScreen extends StatefulWidget {
  final String userId;

  const ReputationScreen({
    Key? key,
    required this.userId,
  }) : super(key: key);

  @override
  State<ReputationScreen> createState() => _ReputationScreenState();
}

class _ReputationScreenState extends State<ReputationScreen> {
  final ReputationService _reputationService = ReputationService();
  
  bool _isLoading = true;
  Map<String, dynamic>? _stats;

  @override
  void initState() {
    super.initState();
    _loadReputationStats();
  }

  /// Carrega estatísticas de reputação
  Future<void> _loadReputationStats() async {
    try {
      final stats = await _reputationService.getReputationStats(widget.userId);
      setState(() {
        _stats = stats;
        _isLoading = false;
      });
    } catch (e) {
      _showError('Erro ao carregar reputação: $e');
      setState(() => _isLoading = false);
    }
  }

  /// Recalcula a reputação
  Future<void> _recalculateReputation() async {
    setState(() => _isLoading = true);
    await _reputationService.calculateReputation(widget.userId);
    await _loadReputationStats();
  }

  /// Mostra mensagem de erro
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reputação'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _recalculateReputation,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _recalculateReputation,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  children: [
                    // Painel de score
                    _buildScorePanel(),
                    
                    const Divider(),
                    
                    // Estatísticas de interações
                    _buildInteractionStats(),
                    
                    const Divider(),
                    
                    // Informações sobre reputação
                    _buildReputationInfo(),
                  ],
                ),
              ),
            ),
    );
  }

  /// Constrói o painel de score
  Widget _buildScorePanel() {
    if (_stats == null) return const SizedBox.shrink();

    final score = _stats!['score'] as double;
    final label = _stats!['label'] as String;
    final color = _getColorFromString(_stats!['color'] as String);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.8), color],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        children: [
          const Text(
            'Seu Score de Reputação',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 16),
          
          // Indicador circular de score
          SizedBox(
            width: 150,
            height: 150,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 150,
                  height: 150,
                  child: CircularProgressIndicator(
                    value: score,
                    strokeWidth: 12,
                    backgroundColor: Colors.white.withOpacity(0.3),
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      (score * 100).toStringAsFixed(0),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Text(
                      '%',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  /// Constrói as estatísticas de interações
  Widget _buildInteractionStats() {
    if (_stats == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Estatísticas de Interações',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          
          _buildStatRow(
            'Transações Aceitas',
            _stats!['acceptedCount'].toString(),
            Icons.check_circle,
            Colors.green,
          ),
          
          _buildStatRow(
            'Transações Rejeitadas',
            _stats!['rejectedCount'].toString(),
            Icons.cancel,
            Colors.red,
          ),
          
          _buildStatRow(
            'Transações Pendentes',
            _stats!['pendingCount'].toString(),
            Icons.pending,
            Colors.orange,
          ),
          
          _buildStatRow(
            'Total de Interações',
            _stats!['totalInteractions'].toString(),
            Icons.swap_horiz,
            Colors.blue,
          ),
          
          const Divider(height: 32),
          
          _buildStatRow(
            'Taxa de Aceitação',
            '${_stats!['acceptanceRate']}%',
            Icons.trending_up,
            Colors.purple,
          ),
        ],
      ),
    );
  }

  /// Constrói uma linha de estatística
  Widget _buildStatRow(String label, String value, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 16),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  /// Constrói informações sobre reputação
  Widget _buildReputationInfo() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Como funciona a Reputação?',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          
          _buildInfoCard(
            'Cálculo do Score',
            'Seu score é calculado pela fórmula:\n\nScore = Transações Aceitas ÷ Total de Interações\n\nQuanto mais transações suas forem aceitas, maior será sua reputação.',
            Icons.calculate,
            Colors.blue,
          ),
          
          const SizedBox(height: 12),
          
          _buildInfoCard(
            'Benefícios da Alta Reputação',
            '• Prioridade no roteamento da rede mesh\n• Maior confiança de outros usuários\n• Maior chance de suas transações serem aceitas',
            Icons.star,
            Colors.amber,
          ),
          
          const SizedBox(height: 12),
          
          _buildInfoCard(
            'Como Melhorar',
            '• Seja honesto nas transações\n• Aceite transações legítimas\n• Mantenha interações positivas\n• Evite comportamentos suspeitos',
            Icons.trending_up,
            Colors.green,
          ),
        ],
      ),
    );
  }

  /// Constrói um card de informação
  Widget _buildInfoCard(String title, String content, IconData icon, Color color) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    content,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Converte string de cor para Color
  Color _getColorFromString(String colorString) {
    switch (colorString.toLowerCase()) {
      case 'green':
        return Colors.green;
      case 'yellow':
        return Colors.amber;
      case 'red':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
