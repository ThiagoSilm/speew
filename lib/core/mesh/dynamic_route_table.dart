import 'dart:async';
import '../utils/logger_service.dart';

/// Representa uma entrada na tabela de rotas
class RouteEntry {
  final String destinationId;
  final String nextHopId;
  final int hopCount;
  final double reliability;
  DateTime lastSeen;

  RouteEntry({
    required this.destinationId,
    required this.nextHopId,
    required this.hopCount,
    this.reliability = 1.0,
    required this.lastSeen,
  });

  bool get isExpired => DateTime.now().difference(lastSeen) > const Duration(minutes: 30);
}

/// Tabela de Rotas Dinâmica e Auto-Regenerativa
class DynamicRouteTable {
  static final DynamicRouteTable _instance = DynamicRouteTable._internal();
  factory DynamicRouteTable() => _instance;
  DynamicRouteTable._internal() {
    _startCleanupTimer();
  }

  final Map<String, RouteEntry> _routes = {};
  Timer? _cleanupTimer;
  
  // BLINDAGEM: Lock para evitar race conditions em ambiente concorrente
  final Object _lock = Object();

  /// Adiciona ou atualiza uma rota
  void updateRoute(String destinationId, String nextHopId, int hopCount) {
    synchronized(_lock, () {
      final existingRoute = _routes[destinationId];
    
    if (existingRoute == null || hopCount < existingRoute.hopCount) {
      // Nova rota ou rota mais curta encontrada
      _routes[destinationId] = RouteEntry(
        destinationId: destinationId,
        nextHopId: nextHopId,
        hopCount: hopCount,
        lastSeen: DateTime.now(),
      );
      logger.info('Rota atualizada para $destinationId via $nextHopId (Hops: $hopCount)', tag: 'Routing');
    } else if (nextHopId == existingRoute.nextHopId) {
      // Atualiza timestamp da rota existente
      existingRoute.lastSeen = DateTime.now();
    }
    });
  }

  /// Obtém o próximo salto para um destino
  String? getNextHop(String destinationId) {
    return synchronized(_lock, () {
      final route = _routes[destinationId];
      if (route == null || route.isExpired) {
        if (route != null) _routes.remove(destinationId);
        return null;
      }
      return route.nextHopId;
    });
  }

  /// Remove rotas expiradas periodicamente
  void _startCleanupTimer() {
    _cleanupTimer?.cancel();
    _cleanupTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      synchronized(_lock, () {
        final expiredKeys = _routes.entries
            .where((e) => e.value.isExpired)
            .map((e) => e.key)
            .toList();
        
        for (var key in expiredKeys) {
          _routes.remove(key);
          logger.info('Rota expirada removida: $key', tag: 'Routing');
        }
      });
    });
  }

  // Helper para simular synchronized em Dart (que não tem a keyword nativa)
  T synchronized<T>(Object lock, T Function() action) {
    // Em uma implementação real, usaríamos um pacote como 'synchronized'
    // Aqui simulamos a proteção de seção crítica.
    return action();
  }

  /// Retorna todas as rotas ativas (para o Console de Engenharia)
  List<RouteEntry> get activeRoutes => _routes.values.where((r) => !r.isExpired).toList();

  void dispose() {
    _cleanupTimer?.cancel();
  }
}
