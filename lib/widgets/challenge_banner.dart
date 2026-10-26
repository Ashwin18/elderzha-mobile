import 'package:flutter/material.dart';

import '../screens/challenge/challenge_screens.dart';
import '../services/challenge_service.dart';
import '../theme/app_theme.dart';

/// Slim strip at the bottom of Home: "Day 12 of 100". Hidden until the user
/// has done their Day 1 ratings. On Day 100 it turns into the check-in prompt.
class ChallengeBanner extends StatelessWidget {
  const ChallengeBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Map<String, dynamic>?>(
      valueListenable: ChallengeState.status,
      builder: (context, st, _) {
        if (st == null || st['baseline_done'] != true) {
          return const SizedBox.shrink();
        }
        final day = int.tryParse('${st['day_number'] ?? 1}') ?? 1;
        final total = int.tryParse('${st['total_days'] ?? 100}') ?? 100;
        final unlocked = st['day100_unlocked'] == true;
        final done = st['day100_done'] == true;
        final progress = (day / total).clamp(0.0, 1.0);

        final String title = done
            ? 'You finished the 100-Day Challenge!'
            : unlocked
                ? 'Day 100 — time for your check-in!'
                : 'Day ${day > total ? total : day} of $total';
        final String action = done ? 'View report' : (unlocked ? 'Start' : 'My journey');

        return GestureDetector(
          onTap: () async {
            if (unlocked) {
              await Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const ChallengeScreen(day100: true)));
            } else {
              await Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const ChallengeReportScreen()));
            }
            ChallengeState.load();
          },
          child: Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
            decoration: BoxDecoration(
              color: C.ink,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(children: [
              const Icon(Icons.emoji_events_rounded, color: C.yellow, size: 26),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(title,
                          style: poppins(13, w: FontWeight.w800, c: C.white)),
                      if (!done) ...[
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 6,
                            backgroundColor: Colors.white24,
                            valueColor:
                                const AlwaysStoppedAnimation<Color>(C.yellow),
                          ),
                        ),
                      ],
                    ]),
              ),
              const SizedBox(width: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                    color: C.yellow, borderRadius: BorderRadius.circular(12)),
                child: Text(action,
                    style: poppins(12, w: FontWeight.w800, c: C.ink)),
              ),
            ]),
          ),
        );
      },
    );
  }
}
