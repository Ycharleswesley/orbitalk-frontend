import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../config/translation_config.dart';

class RazorpayService {
  late Razorpay _razorpay;

  // Use the central configuration for HTTP requests
  final String backendUrl = TranslationConfig.httpServerUrl;

  Function(String orderId, String paymentId)? onSuccess;
  Function(String message)? onFailure;

  void init() {
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  void dispose() {
    _razorpay.clear();
  }

  Future<void> checkoutPackage({
    required String packageId,
    required double expectedAmount, // Local display amount passed to Razorpay checkout options
    required String testKeyId,
    required String name,
    required String description,
    required String userEmail,
    required String userContact,
  }) async {
    try {
      // 1. Create order on the backend
      final response = await http.post(
        Uri.parse('$backendUrl/create-razorpay-order'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'packageId': packageId,
          'currency': 'INR',
        }),
      );

      if (response.statusCode != 200) {
        onFailure?.call("Failed to create order on server: ${response.body}");
        return;
      }

      final orderData = jsonDecode(response.body);
      final String orderId = orderData['id'];
      
      // If the backend returned the exact package amount, we can use it.
      // We fall back to `expectedAmount` just in case.
      final double finalAmount = orderData['amount'] != null 
          ? (orderData['amount'] / 100.0) // Razorpay backend returns amount in paise
          : expectedAmount;

      // 2. Open Razorpay Checkout
      var options = {
        'key': testKeyId,
        'amount': (finalAmount * 100).toInt(), // Amount in paise
        'name': name,
        'order_id': orderId,
        'description': description,
        'timeout': 120,
        'prefill': {
          'contact': userContact,
          'email': userEmail,
        },
      };

      _razorpay.open(options);
    } catch (e) {
      onFailure?.call(e.toString());
    }
  }

  Future<void> _handlePaymentSuccess(PaymentSuccessResponse response) async {
    try {
      // 3. Verify signature on the backend
      final verifyResponse = await http.post(
        Uri.parse('$backendUrl/verify-razorpay-payment'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'razorpay_order_id': response.orderId,
          'razorpay_payment_id': response.paymentId,
          'razorpay_signature': response.signature,
        }),
      );

      if (verifyResponse.statusCode == 200) {
        onSuccess?.call(response.orderId!, response.paymentId!);
      } else {
        onFailure?.call("Payment verification failed at server!");
      }
    } catch (e) {
       onFailure?.call("Verification error: ${e.toString()}");
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    onFailure?.call("Payment Failed: ${response.message ?? "Unknown error"}");
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    onFailure?.call("External Wallet Selected: ${response.walletName}");
  }
}
