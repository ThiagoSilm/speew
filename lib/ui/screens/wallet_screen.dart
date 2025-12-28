import '../../models/coin_transaction.dart';
import '../../services/wallet/wallet_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Tela de carteira da moeda simbólica
/// Exibe saldo, histórico e ofertas pendentes de aceite
class WalletScreen extends StatefulWidget {
  final String userId;

  const WalletScreen({
    Key? key,
    required this.userId,
  }) : super(key: key);

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  late WalletService _walletService;
  bool _isLoading = true;
  Map<String, dynamic>? _stats;

  @override
  void initState() {
    super.initState();
    _walletService = WalletService();
    _initializeWallet();
  }

  /// Inicializa a carteira
  Future<void> _initializeWallet() async {
    try {
      await _walletService.initialize(widget.userId);
      final stats = await _walletService.getWalletStats(widget.userId);
      setState(() {
        _stats = stats;
        _isLoading = false;
      });
    } catch (e) {
      _showError('Erro ao inicializar carteira: $e');
      setState(() => _isLoading = false);
    }
  }

  /// Aceita uma transação pendente
  Future<void> _acceptTransaction(CoinTransaction transaction) async {
    try {
      // Em produção, obter chave privada do armazenamento seguro
      final privateKey = 'user-private-key'; // Placeholder
      
      final success = await _walletService.acceptTransaction(
        transactionId: transaction.transactionId,
        receiverId: widget.userId,
        receiverPrivateKey: privateKey,
      );

      if (success) {
        _showSuccess('Transação aceita: ${transaction.amount}');
        await _refreshWallet();
      } else {
        _showError('Falha ao aceitar transação');
      }
    } catch (e) {
      _showError('Erro ao aceitar transação: $e');
    }
  }

  /// Rejeita uma transação pendente
  Future<void> _rejectTransaction(CoinTransaction transaction) async {
    try {
      final success = await _walletService.rejectTransaction(
        transactionId: transaction.transactionId,
        receiverId: widget.userId,
      );

      if (success) {
        _showSuccess('Transação rejeitada');
        await _refreshWallet();
      } else {
        _showError('Falha ao rejeitar transação');
      }
    } catch (e) {
      _showError('Erro ao rejeitar transação: $e');
    }
  }

  /// Atualiza os dados da carteira
  Future<void> _refreshWallet() async {
    await _walletService.refreshBalance(widget.userId);
    final stats = await _walletService.getWalletStats(widget.userId);
    setState(() {
      _stats = stats;
    });
  }

  /// Mostra mensagem de erro
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  /// Mostra mensagem de sucesso
  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _walletService,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Carteira'),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _refreshWallet,
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Consumer<WalletService>(
                builder: (context, wallet, child) {
                  return RefreshIndicator(
                    onRefresh: _refreshWallet,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: Column(
                        children: [
                          // Painel de saldo
                          _buildBalancePanel(wallet),
                          
                          // Mensagem de Contexto da Speew Trust Tokens
                          _buildCoinContext(),
                          
                          const Divider(),
                          
                          // Estatísticas
                          _buildStatsPanel(),
                          
                          const Divider(),
                          
                          // Transações pendentes
                          _buildPendingTransactions(wallet),
                          
                          const Divider(),
                          
                          // Histórico de transações
                          _buildTransactionHistory(wallet),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }

  /// Constrói o painel de saldo
  Widget _buildCoinContext() {
    return const Padding(
      padding: EdgeInsets.all(16.0),
      child: Text(
        'A Speew Trust Tokens não possui valor monetário. Ela representa seu nível de Confiança e Colaboração na rede. Quanto mais você ajuda (repassa dados), mais pontos você ganha. Perder pontos indica falha em cumprir sua parte.',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 14,
          color: Colors.black54,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }

  /// Constrói o painel de saldo
  Widget _buildBalancePanel(WalletService wallet) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue[700]!, Colors.blue[500]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        children: [
          const Text(
            'Saldo Disponível',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            wallet.balance.toStringAsFixed(2),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 48,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Text(
            'Pontos de Confiança e Colaboração',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  /// Constrói o painel de estatísticas
  Widget _buildStatsPanel() {
    if (_stats == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Estatísticas',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Enviado',
                  _stats!['totalSent'].toStringAsFixed(2),
                  Icons.arrow_upward,
                  Colors.red,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatCard(
                  'Recebido',
                  _stats!['totalReceived'].toStringAsFixed(2),
                  Icons.arrow_downward,
                  Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Transações',
                  _stats!['transactionCount'].toString(),
                  Icons.swap_horiz,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatCard(
                  'Pendentes',
                  _stats!['pendingCount'].toString(),
                  Icons.pending,
                  Colors.orange,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Constrói um card de estatística
  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Constrói a lista de transações pendentes
  Widget _buildPendingTransactions(WalletService wallet) {
    if (wallet.pendingTransactions.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text('Nenhuma transação pendente'),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Ofertas Pendentes',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: wallet.pendingTransactions.length,
          itemBuilder: (context, index) {
            final transaction = wallet.pendingTransactions[index];
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: ListTile(
                leading: const CircleAvatar(
                  child: Icon(Icons.monetization_on),
                ),
                title: Text(
                  '+${transaction.amount.toStringAsFixed(2)} moedas',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  'De: ${transaction.senderId.substring(0, 8)}...\n${_formatTimestamp(transaction.timestamp)}',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.check, color: Colors.green),
                      onPressed: () => _acceptTransaction(transaction),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.red),
                      onPressed: () => _rejectTransaction(transaction),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  /// Constrói o histórico de transações
  Widget _buildTransactionHistory(WalletService wallet) {
    if (wallet.transactionHistory.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text('Nenhuma transação no histórico'),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Histórico',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: wallet.transactionHistory.length,
          itemBuilder: (context, index) {
            final transaction = wallet.transactionHistory[index];
            final isReceived = transaction.receiverId == widget.userId;
            final isAccepted = transaction.status == 'accepted';
            
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: isAccepted 
                    ? (isReceived ? Colors.green : Colors.red)
                    : Colors.grey,
                  child: Icon(
                    isReceived ? Icons.arrow_downward : Icons.arrow_upward,
                    color: Colors.white,
                  ),
                ),
                title: Text(
                  '${isReceived ? '+' : '-'}${transaction.amount.toStringAsFixed(2)} moedas',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isAccepted 
                      ? (isReceived ? Colors.green : Colors.red)
                      : Colors.grey,
                  ),
                ),
                subtitle: Text(
                  '${isReceived ? 'De' : 'Para'}: ${(isReceived ? transaction.senderId : transaction.receiverId).substring(0, 8)}...\n${_formatTimestamp(transaction.timestamp)}',
                ),
                trailing: Chip(
                  label: Text(
                    transaction.status == 'accepted' ? 'Aceita' :
                    transaction.status == 'rejected' ? 'Rejeitada' : 'Pendente',
                    style: const TextStyle(fontSize: 12),
                  ),
                  backgroundColor: transaction.status == 'accepted' ? Colors.green[100] :
                    transaction.status == 'rejected' ? Colors.red[100] : Colors.orange[100],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  /// Formata timestamp para exibição
  String _formatTimestamp(DateTime timestamp) {
    return '${timestamp.day}/${timestamp.month}/${timestamp.year} ${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
  }
}
