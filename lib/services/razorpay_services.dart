import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

class RazorpayService {
  late Razorpay _razorpay;
  late Function(String paymentId) onSuccess;

  void init({
    required String razorpayKey,
    required String amount,
    required Function(String paymentId) onSuccess,
  }) {
    _razorpay = Razorpay();
    this.onSuccess = onSuccess;

    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);

    var options = {
      'key': razorpayKey,
      'amount': (double.parse(amount) * 100).toInt(), // amount in paise
      'name': 'ElderZha',
      'description': 'Plan Purchase',
      'currency': 'INR',
      'image': "https://elderzha.batechnology.in/storage/upload/logo/logo.png",
      'theme.color': '#FFCC01',
      'method': {'upi': true, 'card': true, 'netbanking': true, 'wallet': true},
    };

    try {
      _razorpay.open(options);
    } catch (e) {
      debugPrint("Razorpay open error: $e");
    }
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) {
    showCommonToast("Payment Successful 🎉", bgColor: Colors.green);
    onSuccess(response.paymentId ?? "");
    log(response.paymentId.toString());
    _razorpay.clear();
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    if (response.code == Razorpay.PAYMENT_CANCELLED) {
      showCommonToast("Payment Cancelled");
    } else {
      showCommonToast(
        response.message?.isNotEmpty == true
            ? response.message!
            : "Payment Failed",
        bgColor: Colors.red,
      );
    }

    _razorpay.clear();
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    showCommonToast(response.walletName ?? "", bgColor: Colors.green);
  }

  void showCommonToast(String message, {Color bgColor = Colors.black87}) {
    Fluttertoast.showToast(
      msg: message,
      backgroundColor: bgColor,
      textColor: Colors.white,
    );
  }
}
