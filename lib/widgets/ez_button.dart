import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

class EzButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool loading;
  final bool outlined;
  final IconData? icon;
  final Color? color;
  final Color? textColor;
  final double? width;

  const EzButton({
    super.key,
    required this.label,
    this.onTap,
    this.loading = false,
    this.outlined = false,
    this.icon,
    this.color,
    this.textColor,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    final bg = color ?? AppColors.yellow;
    final fg = textColor ?? AppColors.ink;

    return SizedBox(
      width: width ?? double.infinity,
      height: 54,
      child: Material(
        color: outlined ? Colors.transparent : bg,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: loading ? null : onTap,
          child: Container(
            decoration: outlined
                ? BoxDecoration(
                    border: Border.all(color: AppColors.borderStrong, width: 1.5),
                    borderRadius: BorderRadius.circular(14),
                  )
                : null,
            alignment: Alignment.center,
            child: loading
                ? SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: outlined ? AppColors.ink : fg,
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (icon != null) ...[
                        Icon(icon, size: 20, color: outlined ? AppColors.ink : fg),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        label,
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: outlined ? AppColors.ink : fg,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
