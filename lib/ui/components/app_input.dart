import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Campo de input customizado
/// 
/// Componente reutilizável com validação e formatação
class AppInput extends StatelessWidget {
  final String? label;
  final String? hint;
  final String? errorText;
  final TextEditingController? controller;
  final TextInputType? keyboardType;
  final bool obscureText;
  final IconData? prefixIcon;
  final IconData? suffixIcon;
  final VoidCallback? onSuffixIconTap;
  final ValueChanged<String>? onChanged;
  final int? maxLines;
  final int? maxLength;
  final List<TextInputFormatter>? inputFormatters;
  final bool enabled;

  const AppInput({
    Key? key,
    this.label,
    this.hint,
    this.errorText,
    this.controller,
    this.keyboardType,
    this.obscureText = false,
    this.prefixIcon,
    this.suffixIcon,
    this.onSuffixIconTap,
    this.onChanged,
    this.maxLines = 1,
    this.maxLength,
    this.inputFormatters,
    this.enabled = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: theme.textTheme.titleMedium,
          ),
          SizedBox(height: 8),
        ],
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscureText,
          onChanged: onChanged,
          maxLines: maxLines,
          maxLength: maxLength,
          inputFormatters: inputFormatters,
          enabled: enabled,
          decoration: InputDecoration(
            hintText: hint,
            errorText: errorText,
            prefixIcon: prefixIcon != null ? Icon(prefixIcon) : null,
            suffixIcon: suffixIcon != null
                ? IconButton(
                    icon: Icon(suffixIcon),
                    onPressed: onSuffixIconTap,
                  )
                : null,
          ),
        ),
      ],
    );
  }
}
