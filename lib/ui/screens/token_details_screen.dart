import 'package:flutter/material.dart';
import '../../core/wallet/tokens/token_model.dart';
import '../../core/wallet/tokens/token_registry.dart';
import '../components/p2p_components.dart';
import '../themes/app_theme.dart';

/// Tela de detalhes de um token simbólico.
class TokenDetailsScreen extends StatelessWidget {
  final String tokenId;

  const TokenDetailsScreen({
    Key? key,
    required this.tokenId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final token = TokenRegistry.getTokenById(tokenId);
    final theme = Theme.of(context);

    if (token == null) {
      return Scaffold(
        appBar: AppBar(title: Text('Token Não Encontrado')),
        body: Center(child: Text('O token com ID $tokenId não foi encontrado.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('${token.symbol} - Detalhes'),
      ),
      body: ListView(
        padding: EdgeInsets.all(16),
        children: [
          // Header
          AppCard(
            child: Column(
              children: [
                Icon(token.icon, size: 64, color: AppTheme.primaryDark),
                SizedBox(height: 16),
                Text(
                  token.name,
                  style: theme.textTheme.displaySmall,
                ),
                SizedBox(height: 8),
                TokenBadge(amount: token.supply, symbol: 'Supply', isLarge: true),
              ],
            ),
          ),
          
          SizedBox(height: 24),
          Text(
            'Propriedades',
            style: theme.textTheme.titleLarge,
          ),
          SizedBox(height: 12),

          // Propriedades
          _buildPropertyCard(context, 'ID', token.id),
          _buildPropertyCard(context, 'Símbolo', token.symbol),
          _buildPropertyCard(context, 'Supply Total', token.supply.toStringAsFixed(2)),
          _buildPropertyCard(context, 'Decimais', token.decimals.toString()),
          _buildPropertyCard(context, 'Descrição', token.dynamicProperties['description'] ?? 'Nenhuma descrição.'),

          // Propriedades Dinâmicas
          if (token.dynamicProperties.isNotEmpty) ...[
            SizedBox(height: 24),
            Text(
              'Propriedades Dinâmicas',
              style: theme.textTheme.titleLarge,
            ),
            SizedBox(height: 12),
            ...token.dynamicProperties.entries
                .where((e) => e.key != 'description')
                .map((e) => _buildPropertyCard(context, e.key, e.value.toString()))
                .toList(),
          ],
        ],
      ),
    );
  }

  Widget _buildPropertyCard(BuildContext context, String title, String value) {
    final theme = Theme.of(context);
    return AppCard(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              color: AppTheme.textSecondaryDark,
            ),
          ),
          Flexible(
            child: Text(
              value,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}
