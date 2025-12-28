import 'package:flutter/material.dart';
import '../themes/app_theme.dart';

/// Indicador de status da rede P2P
class P2PStatusIndicator extends StatelessWidget {
  final bool isConnected;
  final int connectedPeers;
  final bool isAnimated;

  const P2PStatusIndicator({
    Key? key,
    required this.isConnected,
    required this.connectedPeers,
    this.isAnimated = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = isConnected ? AppTheme.success : AppTheme.error;
    
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isAnimated)
            _AnimatedDot(color: color)
          else
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
          SizedBox(width: 8),
          Text(
            isConnected ? '$connectedPeers peers' : 'Offline',
            style: theme.textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Dot animado para indicador
class _AnimatedDot extends StatefulWidget {
  final Color color;

  const _AnimatedDot({required this.color});

  @override
  State<_AnimatedDot> createState() => _AnimatedDotState();
}

class _AnimatedDotState extends State<_AnimatedDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.3, end: 1.0).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: widget.color.withOpacity(_animation.value),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: widget.color.withOpacity(_animation.value * 0.5),
                blurRadius: 4,
                spreadRadius: 1,
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Badge de token/moeda
class TokenBadge extends StatelessWidget {
  final double amount;
  final String symbol;
  final bool isLarge;

  const TokenBadge({
    Key? key,
    required this.amount,
    this.symbol = 'MESH',
    this.isLarge = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isLarge ? 16 : 12,
        vertical: isLarge ? 12 : 8,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.primaryDark, AppTheme.secondaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(isLarge ? 16 : 12),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryDark.withOpacity(0.3),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.toll,
            color: Colors.white,
            size: isLarge ? 24 : 18,
          ),
          SizedBox(width: 8),
          Text(
            '${amount.toStringAsFixed(2)} $symbol',
            style: theme.textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: isLarge ? 20 : 16,
            ),
          ),
        ],
      ),
    );
  }
}

/// Bolha de node mesh
class MeshNodeBubble extends StatelessWidget {
  final String nodeId;
  final String displayName;
  final bool isOnline;
  final int hops;
  final VoidCallback? onTap;

  const MeshNodeBubble({
    Key? key,
    required this.nodeId,
    required this.displayName,
    required this.isOnline,
    this.hops = 0,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = isOnline ? AppTheme.success : AppTheme.textSecondaryDark;
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.cardTheme.color,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color.withOpacity(0.3),
            width: 2,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Avatar
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            SizedBox(height: 8),
            // Nome
            Text(
              displayName,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            // Hops
            if (hops > 0) ...[
              SizedBox(height: 4),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.info.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$hops hop${hops > 1 ? 's' : ''}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppTheme.info,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Avatar customizado
class AppAvatar extends StatelessWidget {
  final String name;
  final Color? color;
  final double size;
  final bool showBorder;

  const AppAvatar({
    Key? key,
    required this.name,
    this.color,
    this.size = 48,
    this.showBorder = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final avatarColor = color ?? AppTheme.primaryDark;
    
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: avatarColor.withOpacity(0.2),
        shape: BoxShape.circle,
        border: showBorder
            ? Border.all(color: avatarColor, width: 2)
            : null,
      ),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: theme.textTheme.titleLarge?.copyWith(
            color: avatarColor,
            fontWeight: FontWeight.bold,
            fontSize: size * 0.4,
          ),
        ),
      ),
    );
  }
}

/// Card customizado
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;

  const AppCard({
    Key? key,
    required this.child,
    this.padding,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final card = Card(
      child: Padding(
        padding: padding ?? EdgeInsets.all(16),
        child: child,
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: card,
      );
    }

    return card;
  }
}

/// Indicador de carregamento
class LoadingIndicator extends StatelessWidget {
  final String? message;
  final double size;

  const LoadingIndicator({
    Key? key,
    this.message,
    this.size = 48,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              strokeWidth: 3,
            ),
          ),
          if (message != null) ...[
            SizedBox(height: 16),
            Text(
              message!,
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

/// Divider customizado
class AppDivider extends StatelessWidget {
  final double height;
  final double thickness;

  const AppDivider({
    Key? key,
    this.height = 24,
    this.thickness = 1,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: height,
      thickness: thickness,
    );
  }
}
