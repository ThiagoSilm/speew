import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/p2p/p2p_service.dart';
import 'core/wallet/wallet_service.dart';
import 'core/reputation/reputation_service.dart';
import 'core/crypto/crypto_service.dart';
import 'core/storage/database_service.dart';
import 'core/storage/repository_pattern.dart';
import 'core/config/app_config.dart';
import 'core/utils/logger_service.dart';
import 'core/models/user.dart';
import 'ui/themes/app_theme.dart';
import 'ui/screens/onboarding_screen.dart';
import 'ui/screens/setup_identity_screen.dart';
import 'ui/screens/dashboard_screen.dart';

/// Ponto de entrada do aplicativo v0.6.0
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Inicializar serviços
  await _initializeServices();
  
  runApp(const RedeP2PApp());
}

/// Inicializa todos os serviços necessários
Future<void> _initializeServices() async {
  try {
    // Inicializar banco de dados
    final db = DatabaseService();
    await db.database;
    
    // Inicializar serviço P2P
    final p2p = P2PService();
    await p2p.initialize();
    
    logger.info('Serviços inicializados com sucesso', tag: 'App');
  } catch (e) {
    logger.error('Erro ao inicializar serviços', tag: 'App', error: e);
  }
}

/// Widget principal do aplicativo
class RedeP2PApp extends StatelessWidget {
  const RedeP2PApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => P2PService()),
        ChangeNotifierProvider(create: (_) => WalletService()),
        ChangeNotifierProvider(create: (_) => ReputationService()),
      ],
      child: MaterialApp(
        title: 'Speew',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: const AppInitializer(),
      ),
    );
  }
}

/// Gerenciador de inicialização e fluxo do app
class AppInitializer extends StatefulWidget {
  const AppInitializer({Key? key}) : super(key: key);

  @override
  State<AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends State<AppInitializer> {
  bool _isLoading = true;
  bool _showOnboarding = true;
  User? _currentUser;

  @override
  void initState() {
    super.initState();
    _checkFirstRun();
  }

  /// Verifica se é primeira execução
  Future<void> _checkFirstRun() async {
    try {
      // Verificar se já existe usuário
      final userRepo = repositories.users;
      final users = await userRepo.findAll();
      
      if (users.isNotEmpty) {
        setState(() {
          _currentUser = users.first;
          _showOnboarding = false;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      logger.error('Erro ao verificar primeira execução', tag: 'App', error: e);
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 24),
              Text(
                'Inicializando Rede P2P...',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
        ),
      );
    }

    // Se já tem usuário, vai direto pro dashboard
    if (_currentUser != null) {
      return DashboardScreen(currentUser: _currentUser!);
    }

    // Se precisa de onboarding
    if (_showOnboarding) {
      return OnboardingScreen(
        onComplete: () {
          setState(() {
            _showOnboarding = false;
          });
        },
      );
    }

    // Tela de criação de identidade
    return SetupIdentityScreen(
      onComplete: (user) {
        setState(() {
          _currentUser = user;
        });
      },
    );
  }
}
