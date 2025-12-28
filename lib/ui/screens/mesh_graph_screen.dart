import 'package:flutter/material.dart';
import 'dart:math';
import '../../core/models/peer.dart';
import '../../core/p2p/p2p_service.dart';
import '../../core/mesh/multipath_engine.dart';
import '../components/p2p_components.dart';
import '../themes/app_theme.dart';

/// Tela de visualização da Mesh Network (MeshGraphScreen).
class MeshGraphScreen extends StatefulWidget {
  final P2PService p2pService;
  final MultiPathEngine multiPathEngine;

  const MeshGraphScreen({
    Key? key,
    required this.p2pService,
    required this.multiPathEngine,
  }) : super(key: key);

  @override
  State<MeshGraphScreen> createState() => _MeshGraphScreenState();
}

class _MeshGraphScreenState extends State<MeshGraphScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  final Map<String, Offset> _peerPositions = {};
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(seconds: 2),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.8, end: 1.2).animate(_controller);
    
    // Inicializa posições dos peers
    _initializePeerPositions();
  }

  void _initializePeerPositions() {
    final peers = widget.p2pService.getConnectedPeers();
    for (var peer in peers) {
      _peerPositions[peer.id] = Offset(
        _random.nextDouble() * 300 + 50,
        _random.nextDouble() * 300 + 50,
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          return CustomPaint(
            painter: MeshGraphPainter(
              peers: widget.p2pService.getConnectedPeers(),
              peerPositions: _peerPositions,
              animationValue: _animation.value,
            ),
            child: Container(),
          );
        },
      ),
    );
  }
}

class MeshGraphPainter extends CustomPainter {
  final List<Peer> peers;
  final Map<String, Offset> peerPositions;
  final double animationValue;

  MeshGraphPainter({
    required this.peers,
    required this.peerPositions,
    required this.animationValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final selfPosition = Offset(center.dx, center.dy);

    // 1. Desenhar conexões (linhas)
    final linePaint = Paint()
      ..color = AppTheme.primaryDark.withOpacity(0.5)
      ..strokeWidth = 1.5;

    for (var peer in peers) {
      final peerPos = peerPositions[peer.id] ?? Offset.zero;
      // Desenha a linha de conexão do nó central para o peer
      canvas.drawLine(selfPosition, peerPos, linePaint);
    }

    // 2. Desenhar nós (círculos)
    // Nó Central (Self)
    _drawNode(canvas, selfPosition, 'Você', AppTheme.success, 15.0 * animationValue);

    // Outros Nós
    for (var peer in peers) {
      final peerPos = peerPositions[peer.id] ?? Offset.zero;
      final color = peer.isRelay ? AppTheme.info : AppTheme.primaryDark;
      _drawNode(canvas, peerPos, peer.id.substring(0, 4), color, 10.0 * animationValue);
    }
  }

  void _drawNode(Canvas canvas, Offset position, String label, Color color, double radius) {
    // Desenha o círculo principal
    final fillPaint = Paint()..color = color.withOpacity(0.8);
    canvas.drawCircle(position, radius, fillPaint);

    // Desenha o anel de pulso (simulando vida da rede)
    final pulsePaint = Paint()
      ..color = color.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawCircle(position, radius * 1.5 * animationValue, pulsePaint);

    // Desenha o texto
    final textPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      position - Offset(textPainter.width / 2, textPainter.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true; // Repinta a cada frame da animação
  }
}
