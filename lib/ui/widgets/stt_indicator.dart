import 'package:flutter/material.dart';

/// Tamanhos disponíveis para o STT Indicator
enum STTIndicatorSize {
  tiny,   // 3 barras, altura 12px
  small,  // 5 barras, altura 16px
  medium, // 5 barras, altura 24px
  large,  // 5 barras, altura 32px
}

/// Widget que exibe o STT Score (reputação) de forma visual
/// Usa um medidor de barras para representar o score de 0.0 a 1.0
class STTIndicator extends StatelessWidget {
  final double score;
  final STTIndicatorSize size;
  final bool showLabel;

  const STTIndicator({
    Key? key,
    required this.score,
    this.size = STTIndicatorSize.medium,
    this.showLabel = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final config = _getConfig();
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildBars(config),
        if (showLabel) ...[
          const SizedBox(width: 8),
          Text(
            _getLabel(),
            style: TextStyle(
              fontSize: config.fontSize,
              fontWeight: FontWeight.bold,
              color: _getColor(),
            ),
          ),
        ],
      ],
    );
  }

  /// Constrói as barras do indicador
  Widget _buildBars(_STTConfig config) {
    final barCount = config.barCount;
    final filledBars = (score * barCount).round();
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(barCount, (index) {
        final isFilled = index < filledBars;
        return Container(
          margin: EdgeInsets.only(right: index < barCount - 1 ? config.spacing : 0),
          width: config.barWidth,
          height: config.barHeight,
          decoration: BoxDecoration(
            color: isFilled ? _getColor() : Colors.grey[300],
            borderRadius: BorderRadius.circular(config.borderRadius),
          ),
        );
      }),
    );
  }

  /// Retorna a cor baseada no score
  Color _getColor() {
    if (score >= 0.8) return Colors.green;
    if (score >= 0.6) return Colors.lightGreen;
    if (score >= 0.4) return Colors.orange;
    if (score >= 0.2) return Colors.deepOrange;
    return Colors.red;
  }

  /// Retorna o label textual do score
  String _getLabel() {
    if (score >= 0.9) return 'Excelente';
    if (score >= 0.75) return 'Muito Boa';
    if (score >= 0.6) return 'Boa';
    if (score >= 0.4) return 'Regular';
    if (score >= 0.25) return 'Baixa';
    return 'Muito Baixa';
  }

  /// Retorna a configuração baseada no tamanho
  _STTConfig _getConfig() {
    switch (size) {
      case STTIndicatorSize.tiny:
        return _STTConfig(
          barCount: 3,
          barWidth: 3,
          barHeight: 12,
          spacing: 2,
          borderRadius: 1.5,
          fontSize: 10,
        );
      case STTIndicatorSize.small:
        return _STTConfig(
          barCount: 5,
          barWidth: 4,
          barHeight: 16,
          spacing: 3,
          borderRadius: 2,
          fontSize: 12,
        );
      case STTIndicatorSize.medium:
        return _STTConfig(
          barCount: 5,
          barWidth: 6,
          barHeight: 24,
          spacing: 4,
          borderRadius: 3,
          fontSize: 14,
        );
      case STTIndicatorSize.large:
        return _STTConfig(
          barCount: 5,
          barWidth: 8,
          barHeight: 32,
          spacing: 5,
          borderRadius: 4,
          fontSize: 16,
        );
    }
  }
}

/// Configuração interna do STT Indicator
class _STTConfig {
  final int barCount;
  final double barWidth;
  final double barHeight;
  final double spacing;
  final double borderRadius;
  final double fontSize;

  _STTConfig({
    required this.barCount,
    required this.barWidth,
    required this.barHeight,
    required this.spacing,
    required this.borderRadius,
    required this.fontSize,
  });
}

/// Widget expandido que exibe o STT Score com mais detalhes
class STTIndicatorExpanded extends StatelessWidget {
  final double score;
  final int totalInteractions;
  final int acceptedTransactions;

  const STTIndicatorExpanded({
    Key? key,
    required this.score,
    required this.totalInteractions,
    required this.acceptedTransactions,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'STT Score',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              STTIndicator(
                score: score,
                size: STTIndicatorSize.large,
                showLabel: true,
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Barra de progresso
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: score,
              minHeight: 12,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(_getColor()),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Estatísticas
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStat(
                label: 'Total',
                value: totalInteractions.toString(),
                icon: Icons.swap_horiz,
              ),
              _buildStat(
                label: 'Aceitas',
                value: acceptedTransactions.toString(),
                icon: Icons.check_circle,
                color: Colors.green,
              ),
              _buildStat(
                label: 'Taxa',
                value: '${(score * 100).toStringAsFixed(0)}%',
                icon: Icons.trending_up,
                color: _getColor(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStat({
    required String label,
    required String value,
    required IconData icon,
    Color? color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color ?? Colors.grey[600], size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color ?? Colors.black,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Color _getColor() {
    if (score >= 0.8) return Colors.green;
    if (score >= 0.6) return Colors.lightGreen;
    if (score >= 0.4) return Colors.orange;
    if (score >= 0.2) return Colors.deepOrange;
    return Colors.red;
  }
}
