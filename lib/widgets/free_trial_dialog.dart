import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// "Free Trial Activation" popup shown before AutoPay set-up opens.
/// Returns true for "OK, Continue", false/null for Cancel.
Future<bool?> showFreeTrialDialog(BuildContext context) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => Dialog(
      backgroundColor: C.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 22),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const _GiftBadge(),
          const SizedBox(height: 6),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Flexible(
              child: Text('Free Trial Activation',
                  textAlign: TextAlign.center,
                  style: poppins(21, w: FontWeight.w800, c: C.ink)),
            ),
            const SizedBox(width: 6),
            const Text('🎉', style: TextStyle(fontSize: 22)),
          ]),
          const SizedBox(height: 12),
          // Pay ₹0
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
            decoration: BoxDecoration(
                color: C.yellowMid, borderRadius: BorderRadius.circular(20)),
            child: Column(children: [
              Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text('Pay ',
                        style: poppins(34, w: FontWeight.w900, c: C.ink, h: 1.1)),
                    Text('₹0',
                        style: poppins(64, w: FontWeight.w900, c: C.green, h: 1.0)),
                    const SizedBox(width: 6),
                    const _Sparks(),
                  ]),
              const SizedBox(height: 4),
              Text.rich(
                TextSpan(children: [
                  const TextSpan(text: 'to activate your '),
                  TextSpan(
                      text: 'free trial',
                      style: poppins(17, w: FontWeight.w900, c: C.ink)),
                ]),
                textAlign: TextAlign.center,
                style: poppins(17, w: FontWeight.w600, c: C.ink),
              ),
            ]),
          ),
          const SizedBox(height: 10),
          // Existing explanation, unchanged.
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                color: C.yellowLight, borderRadius: BorderRadius.circular(18)),
            child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
              Container(
                width: 44,
                height: 44,
                decoration:
                    const BoxDecoration(color: C.yellow, shape: BoxShape.circle),
                child: const Icon(Icons.info_outline_rounded,
                    color: C.ink, size: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                    'Only a small verification amount of Rs 1 to Rs 5 will be '
                    'debited from your account and it will be refunded within '
                    '3 working days.',
                    style: poppins(13, w: FontWeight.w600, c: C.txm, h: 1.45)),
              ),
            ]),
          ),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: () => Navigator.pop(ctx, true),
            child: Container(
              width: double.infinity,
              height: 52,
              decoration: BoxDecoration(
                  color: C.ink, borderRadius: BorderRadius.circular(18)),
              child: Center(
                  child: Text('OK, Continue',
                      style: poppins(15.5, w: FontWeight.w800, c: Colors.white))),
            ),
          ),
          const SizedBox(height: 2),
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: poppins(14, w: FontWeight.w700, c: C.txl)),
          ),
        ]),
      ),
    ),
  );
}

/// Yellow circle, gift box with a red ribbon and bow, and a "FREE TRIAL" tag.
class _GiftBadge extends StatelessWidget {
  const _GiftBadge();

  @override
  Widget build(BuildContext context) {
    const ribbon = Color(0xFFE8452C);
    const boxYellow = Color(0xFFFFC21A);
    return SizedBox(
      width: 220,
      height: 128,
      child: Stack(alignment: Alignment.center, children: [
        Container(
            width: 124,
            height: 124,
            decoration:
                const BoxDecoration(color: C.yellowMid, shape: BoxShape.circle)),
        // sparkles each side of the gift
        const Positioned(left: 22, top: 40, child: _SparkTriple(flip: false)),
        const Positioned(right: 22, top: 40, child: _SparkTriple(flip: true)),
        // lid
        Positioned(
          top: 36,
          child: Container(
            width: 84,
            height: 22,
            decoration: BoxDecoration(
              color: boxYellow,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFFE5A600), width: 1.5),
            ),
          ),
        ),
        // box body
        Positioned(
          top: 56,
          child: Container(
            width: 74,
            height: 58,
            decoration: BoxDecoration(
              color: boxYellow,
              borderRadius:
                  const BorderRadius.vertical(bottom: Radius.circular(8)),
              border: Border.all(color: const Color(0xFFE5A600), width: 1.5),
            ),
          ),
        ),
        // ribbon down the middle
        Positioned(
            top: 36,
            child: Container(width: 14, height: 78, color: ribbon)),
        // bow
        Positioned(
          top: 14,
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Transform.rotate(
                angle: -.5,
                child: Container(
                    width: 30,
                    height: 22,
                    decoration: BoxDecoration(
                        color: ribbon,
                        borderRadius: BorderRadius.circular(14)))),
            const SizedBox(width: 2),
            Transform.rotate(
                angle: .5,
                child: Container(
                    width: 30,
                    height: 22,
                    decoration: BoxDecoration(
                        color: ribbon,
                        borderRadius: BorderRadius.circular(14)))),
          ]),
        ),
        Positioned(
            top: 28,
            child: Container(
                width: 16,
                height: 14,
                decoration: BoxDecoration(
                    color: const Color(0xFFC93A24),
                    borderRadius: BorderRadius.circular(6)))),
        // FREE TRIAL tag
        Positioned(
          top: 68,
          child: Transform.rotate(
            angle: -.12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF4D6),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFE5A600), width: 1),
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text('FREE',
                    style: poppins(12, w: FontWeight.w900, c: C.ink, h: 1.0)),
                Text('TRIAL',
                    style: poppins(12, w: FontWeight.w900, c: C.ink, h: 1.0)),
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}

class _SparkTriple extends StatelessWidget {
  final bool flip;
  const _SparkTriple({required this.flip});

  @override
  Widget build(BuildContext context) {
    Widget bar(double angle) => Transform.rotate(
        angle: flip ? -angle : angle,
        child: Container(
            width: 14,
            height: 4,
            decoration: BoxDecoration(
                color: C.yellow, borderRadius: BorderRadius.circular(3))));
    return Column(children: [
      bar(-.6),
      const SizedBox(height: 8),
      bar(.6),
    ]);
  }
}

/// The little "rays" beside the big ₹0.
class _Sparks extends StatelessWidget {
  const _Sparks();

  @override
  Widget build(BuildContext context) {
    Widget ray(double a) => Transform.rotate(
        angle: a,
        child: Container(
            width: 16,
            height: 4.5,
            decoration: BoxDecoration(
                color: C.yellow, borderRadius: BorderRadius.circular(3))));
    return SizedBox(
      width: 22,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        ray(-math.pi / 4),
        const SizedBox(height: 8),
        ray(0),
        const SizedBox(height: 8),
        ray(math.pi / 4),
      ]),
    );
  }
}
