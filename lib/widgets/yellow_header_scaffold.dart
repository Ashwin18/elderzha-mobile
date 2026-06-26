import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

/// Signature ElderZha layout: amber yellow header + white card slides up
class YellowHeaderScaffold extends StatelessWidget {
  final String? title;
  final Widget headerContent;
  final Widget body;
  final List<Widget>? actions;
  final bool showBack;
  final double headerHeight;
  final Widget? bottomBar;

  const YellowHeaderScaffold({
    super.key,
    this.title,
    required this.headerContent,
    required this.body,
    this.actions,
    this.showBack = true,
    this.headerHeight = 200,
    this.bottomBar,
  });

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: AppColors.yellow,
        body: Column(
          children: [
            // Yellow header zone
            SafeArea(
              bottom: false,
              child: SizedBox(
                height: headerHeight,
                child: Stack(
                  children: [
                    // Back button
                    if (showBack)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: IconButton(
                          icon: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: AppColors.ink),
                          ),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                    // Actions
                    if (actions != null)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Row(children: actions!),
                      ),
                    // Header content
                    Positioned.fill(child: headerContent),
                  ],
                ),
              ),
            ),
            // White body slides up with curved top
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: AppColors.bg,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(28),
                    topRight: Radius.circular(28),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(28),
                    topRight: Radius.circular(28),
                  ),
                  child: body,
                ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: bottomBar,
      ),
    );
  }
}
