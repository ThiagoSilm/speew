import 'package:flutter/material.dart';

/// Botão customizado da aplicação
/// 
/// Componente reutilizável com variantes e animações
class AppButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final AppButtonSize size;
  final IconData? icon;
  final bool isLoading;
  final bool isFullWidth;

  const AppButton({
    Key? key,
    required this.text,
    this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.size = AppButtonSize.medium,
    this.icon,
    this.isLoading = false,
    this.isFullWidth = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    Widget button;
    
    switch (variant) {
      case AppButtonVariant.primary:
        button = ElevatedButton(
          onPressed: isLoading ? null : onPressed,
          child: _buildContent(theme),
        );
        break;
      case AppButtonVariant.secondary:
        button = OutlinedButton(
          onPressed: isLoading ? null : onPressed,
          child: _buildContent(theme),
        );
        break;
      case AppButtonVariant.text:
        button = TextButton(
          onPressed: isLoading ? null : onPressed,
          child: _buildContent(theme),
        );
        break;
    }
    
    if (isFullWidth) {
      return SizedBox(
        width: double.infinity,
        child: button,
      );
    }
    
    return button;
  }

  Widget _buildContent(ThemeData theme) {
    if (isLoading) {
      return SizedBox(
        height: _getHeight(),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(
                variant == AppButtonVariant.primary
                    ? Colors.white
                    : theme.colorScheme.primary,
              ),
            ),
          ),
        ),
      );
    }

    final content = <Widget>[];
    
    if (icon != null) {
      content.add(Icon(icon, size: _getIconSize()));
      content.add(SizedBox(width: 8));
    }
    
    content.add(Text(text));
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: content,
    );
  }

  double _getHeight() {
    switch (size) {
      case AppButtonSize.small:
        return 36;
      case AppButtonSize.medium:
        return 48;
      case AppButtonSize.large:
        return 56;
    }
  }

  double _getIconSize() {
    switch (size) {
      case AppButtonSize.small:
        return 16;
      case AppButtonSize.medium:
        return 20;
      case AppButtonSize.large:
        return 24;
    }
  }
}

enum AppButtonVariant {
  primary,
  secondary,
  text,
}

enum AppButtonSize {
  small,
  medium,
  large,
}
