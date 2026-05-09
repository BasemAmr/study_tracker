import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';

class SettingsHeader extends StatelessWidget {
  final String title;
  const SettingsHeader({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 24, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: AppTypography.textTheme.labelSmall?.copyWith(
          color: AppColors.onSurfaceVariant,
          letterSpacing: 1.2,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class SettingsGroup extends StatelessWidget {
  final List<Widget> children;
  const SettingsGroup({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.outline.withOpacity(0.5)),
      ),
      child: Column(
        children: [
          for (int i = 0; i < children.length; i++) ...[
            children[i],
            if (i < children.length - 1)
              const Divider(height: 1, indent: 16, endIndent: 0, color: AppColors.outline),
          ],
        ],
      ),
    );
  }
}

class SettingsRow extends StatelessWidget {
  final String label;
  final String? description;
  final Widget? control;
  final VoidCallback? onTap;
  final Color? labelColor;

  const SettingsRow({
    super.key,
    required this.label,
    this.description,
    this.control,
    this.onTap,
    this.labelColor,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 52),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: AppTypography.textTheme.bodyLarge?.copyWith(
                      fontSize: 15,
                      color: labelColor ?? AppColors.onSurface,
                    ),
                  ),
                  if (description != null)
                    Text(
                      description!,
                      style: AppTypography.textTheme.bodySmall?.copyWith(
                        fontSize: 12,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            if (control != null) ...[
              const SizedBox(width: 12),
              control!,
            ],
          ],
        ),
      ),
    );
  }
}

class SettingsToggleRow extends StatelessWidget {
  final String label;
  final String? description;
  final bool value;
  final ValueChanged<bool> onChanged;

  const SettingsToggleRow({
    super.key,
    required this.label,
    this.description,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SettingsRow(
      label: label,
      description: description,
      control: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: AppColors.primary,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}

class SettingsActionRow extends StatelessWidget {
  final String label;
  final String? description;
  final VoidCallback onTap;
  final Color? color;
  final bool isDestructive;

  const SettingsActionRow({
    super.key,
    required this.label,
    this.description,
    required this.onTap,
    this.color,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isDestructive ? AppColors.error : (color ?? AppColors.onSurface);
    return SettingsRow(
      label: label,
      description: description,
      onTap: onTap,
      labelColor: textColor,
      control: Icon(
        Icons.chevron_right,
        size: 20,
        color: isDestructive ? AppColors.error : AppColors.onSurfaceVariant,
      ),
    );
  }
}

class SettingsStepperRow extends StatelessWidget {
  final String label;
  final String? description;
  final int value;
  final String unit;
  final ValueChanged<int> onChanged;

  const SettingsStepperRow({
    super.key,
    required this.label,
    this.description,
    required this.value,
    required this.unit,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SettingsRow(
      label: label,
      description: description,
      control: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepperButton(
            icon: Icons.remove,
            onPressed: () => onChanged(value - 1),
          ),
          const SizedBox(width: 12),
          Text(
            '$value $unit',
            style: AppTypography.textTheme.bodyLarge?.copyWith(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 12),
          _StepperButton(
            icon: Icons.add,
            onPressed: () => onChanged(value + 1),
          ),
        ],
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;

  const _StepperButton({required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: AppColors.onSurface.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: IconButton(
        padding: EdgeInsets.zero,
        icon: Icon(icon, size: 18, color: AppColors.onSurface),
        onPressed: onPressed,
      ),
    );
  }
}

class SettingsInputRow extends StatelessWidget {
  final String label;
  final String value;
  final ValueChanged<String> onChanged;
  final bool obscureText;
  final VoidCallback? onObscureToggle;

  const SettingsInputRow({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.obscureText = false,
    this.onObscureToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: TextFormField(
              initialValue: value,
              onChanged: onChanged,
              obscureText: obscureText,
              style: AppTypography.textTheme.bodyLarge?.copyWith(
                fontSize: 15,
                color: AppColors.onSurface,
              ),
              decoration: InputDecoration(
                labelText: label,
                labelStyle: const TextStyle(fontSize: 13, color: AppColors.onSurfaceVariant),
                isDense: true,
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                suffixIcon: onObscureToggle != null
                    ? IconButton(
                        icon: Icon(
                          obscureText ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                          size: 18,
                        ),
                        onPressed: onObscureToggle,
                      )
                    : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
