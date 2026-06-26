import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../screens/home/home_screen.dart';
import '../screens/community/community_screen.dart';
import '../screens/reminders/reminder_screen.dart';
import '../screens/offers/offers_screen.dart';
import '../screens/profile/profile_screen.dart';

class MainScaffold extends StatefulWidget {
  const MainScaffold({
    super.key,
    this.initialIndex = 0,
    this.communityInitialTab = 0,
  });

  final int initialIndex;
  final int communityInitialTab;

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  late int _i;
  int _communityVersion = 0;
  late int _communityInitialTab;
  final _labels = ['Home', 'Reminder', 'Spike', 'Offers', 'Profile'];
  final _icons = [
    Icons.home_rounded,
    Icons.notifications_active_rounded,
    Icons.chat_bubble_rounded,
    Icons.card_giftcard_rounded,
    Icons.person_rounded
  ];
  final _iconsOff = [
    Icons.home_outlined,
    Icons.notifications_active_outlined,
    Icons.chat_bubble_outline_rounded,
    Icons.card_giftcard_outlined,
    Icons.person_outline_rounded
  ];

  @override
  void initState() {
    super.initState();
    _i = widget.initialIndex.clamp(0, 4);
    _communityInitialTab = widget.communityInitialTab.clamp(0, 3);
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      HomeScreen(
        onOpenReminder: () => setState(() => _i = 1),
        onOpenSpike: () => setState(() {
          _communityInitialTab = 0;
          _communityVersion++;
          _i = 2;
        }),
      ),
      const ReminderScreen(),
      CommunityScreen(
        key: ValueKey('$_communityVersion-$_communityInitialTab'),
        initialTab: _communityInitialTab,
      ),
      const OffersScreen(),
      const ProfileScreen(),
    ];
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (_, __) {
        if (_i != 0) {
          setState(() => _i = 0);
          return;
        }
        SystemNavigator.pop();
      },
      child: Scaffold(
        body: IndexedStack(index: _i, children: screens),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: C.white,
            border: const Border(top: BorderSide(color: C.bg2)),
            boxShadow: [
              BoxShadow(
                color: C.ink.withOpacity(.06),
                blurRadius: 18,
                offset: const Offset(0, -8),
              ),
            ],
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 7, 4, 8),
              child: Row(
                  children: List.generate(5, (i) {
                final sel = _i == i;
                final isSpike = i == 2;
                return Expanded(
                    child: GestureDetector(
                  onTap: () => setState(() {
                    if (i == 2) {
                      _communityInitialTab = 0;
                      _communityVersion++;
                    }
                    _i = i;
                  }),
                  behavior: HitTestBehavior.opaque,
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    AnimatedScale(
                      scale: isSpike && sel ? 1.08 : 1,
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutBack,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: isSpike ? 48 : 38,
                        height: isSpike ? 48 : 34,
                        margin: EdgeInsets.only(top: isSpike ? 0 : 6),
                        decoration: BoxDecoration(
                          color: isSpike
                              ? C.yellow
                              : (sel ? C.yellowMid : Colors.transparent),
                          borderRadius:
                              BorderRadius.circular(isSpike ? 18 : 14),
                          border: isSpike
                              ? Border.all(color: C.yellowDark, width: 1.2)
                              : null,
                          boxShadow: isSpike
                              ? [
                                  BoxShadow(
                                    color: C.yellowDark.withOpacity(.23),
                                    blurRadius: 16,
                                    offset: const Offset(0, 8),
                                  )
                                ]
                              : null,
                        ),
                        child: Icon(
                          sel ? _icons[i] : _iconsOff[i],
                          size: isSpike ? 28 : 22,
                          color: isSpike ? C.ink : (sel ? C.ink : C.txl),
                        ),
                      ),
                    ),
                    SizedBox(height: isSpike ? 3 : 2),
                    Text(_labels[i],
                        style: poppins(9,
                            w: FontWeight.w800, c: sel ? C.yellowDark : C.txl)),
                  ]),
                ));
              })),
            ),
          ),
        ),
      ),
    );
  }
}
