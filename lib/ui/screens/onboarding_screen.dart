import 'package:flutter/material.dart';
import '../themes/app_theme.dart';
import '../components/app_button.dart';

/// Tela de onboarding com introdução ao app
class OnboardingScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const OnboardingScreen({
    Key? key,
    required this.onComplete,
  }) : super(key: key);

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<OnboardingPage> _pages = [
    OnboardingPage(
      icon: Icons.hub,
      title: 'Rede P2P Mesh',
      description:
          'Conecte-se diretamente com outros dispositivos sem internet. '
          'Sua rede privada e descentralizada.',
    ),
    OnboardingPage(
      icon: Icons.security,
      title: 'Privacidade Total',
      description:
          'Comunicação criptografada ponta-a-ponta. '
          'Identidade anônima e rotação automática de chaves.',
    ),
    OnboardingPage(
      icon: Icons.toll,
      title: 'Speew Trust Tokens',
      description:
          'Sistema econômico interno com tokens MESH. '
          'Transações instantâneas sem taxas.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Indicadores de página
            Padding(
              padding: EdgeInsets.all(24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _pages.length,
                  (index) => AnimatedContainer(
                    duration: Duration(milliseconds: 300),
                    margin: EdgeInsets.symmetric(horizontal: 4),
                    width: _currentPage == index ? 32 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _currentPage == index
                          ? AppTheme.primaryDark
                          : AppTheme.textSecondaryDark.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
            ),
            
            // Conteúdo das páginas
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                itemCount: _pages.length,
                itemBuilder: (context, index) {
                  return _buildPage(_pages[index], theme);
                },
              ),
            ),
            
            // Botões de navegação
            Padding(
              padding: EdgeInsets.all(24),
              child: Row(
                children: [
                  if (_currentPage > 0)
                    Expanded(
                      child: AppButton(
                        text: 'Voltar',
                        variant: AppButtonVariant.secondary,
                        onPressed: () {
                          _pageController.previousPage(
                            duration: Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        },
                      ),
                    ),
                  if (_currentPage > 0) SizedBox(width: 16),
                  Expanded(
                    flex: _currentPage == 0 ? 1 : 1,
                    child: AppButton(
                      text: _currentPage == _pages.length - 1
                          ? 'Começar'
                          : 'Próximo',
                      onPressed: () {
                        if (_currentPage == _pages.length - 1) {
                          widget.onComplete();
                        } else {
                          _pageController.nextPage(
                            duration: Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        }
                      },
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

  Widget _buildPage(OnboardingPage page, ThemeData theme) {
    return Padding(
      padding: EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Ícone
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.primaryDark, AppTheme.secondaryDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(
              page.icon,
              size: 64,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 48),
          
          // Título
          Text(
            page.title,
            style: theme.textTheme.displayMedium,
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 24),
          
          // Descrição
          Text(
            page.description,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: AppTheme.textSecondaryDark,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }
}

class OnboardingPage {
  final IconData icon;
  final String title;
  final String description;

  OnboardingPage({
    required this.icon,
    required this.title,
    required this.description,
  });
}
