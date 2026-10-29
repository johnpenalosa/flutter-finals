import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

// AppColors comes from main.dart
import 'main.dart';

/// URL of your Vercel backend (no trailing slash).
const kBackend = 'https://xendit-backend-nu.vercel.app';

/// Used when the customer is a guest (no login = no email).
/// example.com is a reserved domain, so nothing is ever delivered to it.
const kGuestEmail = 'guest@example.com';

class PaymentException implements Exception {
  final String message;
  PaymentException(this.message);
  @override
  String toString() => message;
}

class PaymentResult {
  final String invoiceId;
  const PaymentResult(this.invoiceId);
}

class _Invoice {
  final String id, url;
  const _Invoice(this.id, this.url);
}

class PaymentService {
  static final _emailRe = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  static Future<_Invoice> _create({
    required String orderId,
    required int amount,
    required String email,
    String description = '',
  }) async {
    // Guests have no email, so fall back to a placeholder.
    // Xendit rejects blank / badly formatted emails.
    final cleanEmail = email.trim();
    final payload = <String, dynamic>{
      'orderId': orderId,
      'amount': amount, // must be an int, e.g. 3995
      'email': _emailRe.hasMatch(cleanEmail) ? cleanEmail : kGuestEmail,
      // Shown in the Xendit dashboard so you can see what was bought
      if (description.trim().isNotEmpty) 'description': description.trim(),
    };

    final http.Response res;
    try {
      res = await http
          .post(
            Uri.parse('$kBackend/api/create-invoice'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 25));
    } catch (_) {
      throw PaymentException(
          'Cannot reach the payment server. Check your internet.');
    }

    // Debug: shows the real server reply in your console
    debugPrint('CREATE-INVOICE payload: ${jsonEncode(payload)}');
    debugPrint('CREATE-INVOICE status: ${res.statusCode}');
    debugPrint('CREATE-INVOICE body: ${res.body}');

    Map<String, dynamic> data = {};
    try {
      data = jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {}
    if (res.statusCode != 200 || data['invoice_url'] == null) {
      throw PaymentException(
          (data['error'] ?? 'Could not start the payment.').toString());
    }
    return _Invoice(data['id'].toString(), data['invoice_url'].toString());
  }

  static Future<String?> _status(String id) async {
    try {
      final r = await http
          .get(Uri.parse('$kBackend/api/invoice-status?id=$id'))
          .timeout(const Duration(seconds: 15));
      return (jsonDecode(r.body) as Map<String, dynamic>)['status']?.toString();
    } catch (_) {
      return null; // network hiccup, try again on the next poll
    }
  }

  static Future<bool> _open(String url) =>
      launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);

  /// Opens the Xendit GCash page and waits until it is paid.
  /// Returns null if the customer cancelled or the invoice expired.
  static Future<PaymentResult?> payWithGcash(
    BuildContext context, {
    required String orderId,
    required int amount,
    required String email,
    String description = '',
  }) async {
    final inv = await _create(
        orderId: orderId,
        amount: amount,
        email: email,
        description: description);
    if (!await _open(inv.url)) {
      throw PaymentException('Could not open the payment page.');
    }
    if (!context.mounted) return null;
    final paid = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _PayWaitDialog(invoice: inv),
    );
    return paid == true ? PaymentResult(inv.id) : null;
  }
}

class _PayWaitDialog extends StatefulWidget {
  final _Invoice invoice;
  const _PayWaitDialog({required this.invoice});
  @override
  State<_PayWaitDialog> createState() => _PayWaitDialogState();
}

class _PayWaitDialogState extends State<_PayWaitDialog>
    with WidgetsBindingObserver {
  Timer? _timer;
  bool _checking = false, _done = false;
  String _msg =
      'Complete the payment in the page that opened, then come back here.';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _check());
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _check();
  }

  void _finish(bool ok) {
    if (_done || !mounted) return;
    _done = true;
    _timer?.cancel();
    Navigator.pop(context, ok);
  }

  Future<void> _check({bool manual = false}) async {
    if (_checking || _done) return;
    _checking = true;
    final s = await PaymentService._status(widget.invoice.id);
    _checking = false;
    if (s == 'PAID' || s == 'SETTLED') {
      _finish(true);
    } else if (s == 'EXPIRED') {
      _finish(false);
    } else if (manual && mounted) {
      setState(
          () => _msg = 'Payment not received yet. Please finish paying first.');
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: false,
        child: AlertDialog(
          shape: const RoundedRectangleBorder(),
          title: const Text('Waiting for payment'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const LinearProgressIndicator(color: AppColors.gold),
              const SizedBox(height: 16),
              Text(_msg, style: const TextStyle(fontSize: 13, height: 1.4)),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => PaymentService._open(widget.invoice.url),
                child: const Text('OPEN PAGE')),
            TextButton(
                onPressed: () => _check(manual: true),
                child: const Text("I'VE PAID")),
            TextButton(
                onPressed: () => _finish(false), child: const Text('CANCEL')),
          ],
        ),
      );
}