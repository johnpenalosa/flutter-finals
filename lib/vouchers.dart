import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'cart_screen.dart';
// AppColors, peso, toast, cardDecoration, Reveal come from main.dart
import 'main.dart';

// ============================================================
// VOUCHER DEFINITIONS
// Edit this list to add, remove or change vouchers.
// ============================================================

class Voucher {
  final String code;
  final String title;
  final String description;

  /// true = percentage off, false = fixed peso amount off
  final bool percent;
  final int value;

  /// Minimum cart subtotal (PHP) needed to use the voucher
  final int minSpend;

  /// Cap for percentage vouchers (PHP). null = no cap
  final int? maxDiscount;

  /// If set, the discount only applies to this brand's watches
  final String? brand;

  /// null = never expires
  final DateTime? expires;

  const Voucher({
    required this.code,
    required this.title,
    required this.description,
    required this.percent,
    required this.value,
    this.minSpend = 0,
    this.maxDiscount,
    this.brand,
    this.expires,
  });

  bool get expired => expires != null && DateTime.now().isAfter(expires!);

  String get valueLabel => percent ? '$value% OFF' : '${peso(value)} OFF';

  String get conditions {
    final parts = <String>[];
    if (minSpend > 0) parts.add('Min. spend ${peso(minSpend)}');
    if (maxDiscount != null) parts.add('Max. discount ${peso(maxDiscount!)}');
    if (brand != null) parts.add('$brand only');
    return parts.isEmpty ? 'No minimum spend' : parts.join('  •  ');
  }

  /// Part of the cart this voucher can discount.
  int eligibleSubtotal(List<CartItem> items) => items
      .where((i) => brand == null || i.watch.brand == brand)
      .fold(0, (s, i) => s + i.watch.price * i.qty);

  /// Why the voucher cannot be used on this cart (null = it can).
  String? ineligibleReason(List<CartItem> items, int subtotal) {
    if (expired) return 'Expired';
    if (subtotal < minSpend) {
      return 'Spend ${peso(minSpend - subtotal)} more to use this voucher';
    }
    if (eligibleSubtotal(items) <= 0) return 'Only for ${brand ?? 'selected'} watches';
    return null;
  }

  bool isEligible(List<CartItem> items, int subtotal) =>
      ineligibleReason(items, subtotal) == null;

  int discountFor(List<CartItem> items) {
    final base = eligibleSubtotal(items);
    var d = percent ? (base * value / 100).floor() : value;
    if (maxDiscount != null && d > maxDiscount!) d = maxDiscount!;
    if (d > base) d = base;
    return d;
  }
}

final kVouchers = <Voucher>[
  Voucher(
    code: 'WELCOME10',
    title: 'Welcome voucher',
    description: '10% off your order',
    percent: true,
    value: 10,
    minSpend: 3000,
    maxDiscount: 2000,
    expires: DateTime(2027, 1, 31, 23, 59),
  ),
  Voucher(
    code: 'SAVE500',
    title: '₱500 off',
    description: '₱500 off your order',
    percent: false,
    value: 500,
    minSpend: 5000,
    expires: DateTime(2026, 12, 31, 23, 59),
  ),
  Voucher(
    code: 'CASIO15',
    title: 'Casio week',
    description: '15% off Casio watches',
    percent: true,
    value: 15,
    minSpend: 2000,
    maxDiscount: 1500,
    brand: 'Casio',
    expires: DateTime(2026, 11, 30, 23, 59),
  ),
  Voucher(
    code: 'LUXE5',
    title: 'Luxury voucher',
    description: '5% off Patek Philippe watches',
    percent: true,
    value: 5,
    minSpend: 500000,
    maxDiscount: 100000,
    brand: 'Patek Philippe',
    expires: DateTime(2027, 3, 31, 23, 59),
  ),
];

class VoucherException implements Exception {
  final String message;
  VoucherException(this.message);
  @override
  String toString() => message;
}

// ============================================================
// VOUCHER STATE (saved in users/{uid}.vouchers)
//   vouchers: { CODE: { claimedAt: ..., usedAt: ... } }
// Each voucher can be claimed once and used once per account.
// ============================================================

class VoucherStore extends ChangeNotifier {
  VoucherStore._();
  static final VoucherStore instance = VoucherStore._();

  final Map<String, bool> _claimed = {}; // code -> already used?
  String? _uid;
  StreamSubscription<User?>? _sub;

  bool isClaimed(String code) => _claimed.containsKey(code);
  bool isUsed(String code) => _claimed[code] == true;

  /// Claimed, not used and not expired.
  List<Voucher> get usable => kVouchers
      .where((v) => isClaimed(v.code) && !isUsed(v.code) && !v.expired)
      .toList();

  /// Not claimed yet and not expired.
  List<Voucher> get claimable =>
      kVouchers.where((v) => !isClaimed(v.code) && !v.expired).toList();

  /// Call once in main() after Firebase.initializeApp.
  void init() {
    _sub ??= FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user == null) {
        _uid = null;
        _claimed.clear();
        notifyListeners();
      } else if (user.uid != _uid) {
        _load(user.uid);
      }
    });
  }

  Future<void> _load(String uid) async {
    _uid = uid;
    _claimed.clear();
    notifyListeners();
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      if (_uid != uid) return;
      final map = doc.data()?['vouchers'];
      if (map is Map) {
        map.forEach((code, v) {
          _claimed[code.toString()] = v is Map && v['usedAt'] != null;
        });
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Voucher load error: $e');
    }
  }

  /// Returns null on success, otherwise an error message.
  Future<String?> claim(Voucher v) async {
    final uid = _uid;
    if (uid == null) return 'Please log in first.';
    if (v.expired) return 'This voucher has expired.';
    final ref = FirebaseFirestore.instance.collection('users').doc(uid);
    try {
      final ok = await FirebaseFirestore.instance.runTransaction<bool>((tx) async {
        final snap = await tx.get(ref);
        final existing = snap.data()?['vouchers'];
        if (existing is Map && existing.containsKey(v.code)) return false;
        tx.set(
          ref,
          {
            'vouchers': {
              v.code: {'claimedAt': FieldValue.serverTimestamp()}
            }
          },
          SetOptions(merge: true),
        );
        return true;
      });
      if (!ok) {
        _claimed.putIfAbsent(v.code, () => false);
        notifyListeners();
        return 'You already claimed this voucher.';
      }
      _claimed[v.code] = false;
      notifyListeners();
      return null;
    } catch (e) {
      debugPrint('Voucher claim error: $e');
      return 'Could not claim the voucher. Please try again.';
    }
  }

  /// Call after an order that used the voucher was saved.
  void markUsed(String code) {
    _claimed[code] = true;
    notifyListeners();
  }
}

// ============================================================
// VOUCHERS SCREEN
// ============================================================

class VouchersScreen extends StatefulWidget {
  const VouchersScreen({super.key});
  @override
  State<VouchersScreen> createState() => _VouchersScreenState();
}

class _VouchersScreenState extends State<VouchersScreen> {
  String? _busy;

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];

  String _date(DateTime d) => '${_months[d.month - 1]} ${d.day}, ${d.year}';

  Future<void> _claim(Voucher v) async {
    setState(() => _busy = v.code);
    final err = await VoucherStore.instance.claim(v);
    if (!mounted) return;
    setState(() => _busy = null);
    toast(context, err ?? 'Voucher ${v.code} claimed! Use it at checkout.');
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('VOUCHERS')),
        body: ListenableBuilder(
          listenable: VoucherStore.instance,
          builder: (context, _) {
            final store = VoucherStore.instance;
            // Claimable first, then claimed, then used / expired
            int rank(Voucher v) {
              if (v.expired) return 3;
              if (store.isUsed(v.code)) return 2;
              if (store.isClaimed(v.code)) return 1;
              return 0;
            }

            final list = [...kVouchers]
              ..sort((a, b) => rank(a).compareTo(rank(b)));

            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text('Claim your vouchers',
                        style: GoogleFonts.playfairDisplay(
                            fontSize: 24, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 6),
                    const Text(
                      'Each voucher can be claimed once per account and used on one order.',
                      style: TextStyle(fontSize: 13, color: AppColors.muted),
                    ),
                    const SizedBox(height: 16),
                    for (final v in list) _card(v, store),
                  ],
                ),
              ),
            );
          },
        ),
      );

  Widget _card(Voucher v, VoucherStore store) {
    final used = store.isUsed(v.code);
    final claimed = store.isClaimed(v.code);
    final dead = v.expired || used;

    Widget action;
    if (used) {
      action = const Text('USED',
          style: TextStyle(
              fontSize: 12, letterSpacing: 1.5, color: AppColors.muted));
    } else if (v.expired) {
      action = const Text('EXPIRED',
          style: TextStyle(
              fontSize: 12, letterSpacing: 1.5, color: AppColors.muted));
    } else if (claimed) {
      action = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle, size: 16, color: Colors.green.shade700),
          const SizedBox(width: 4),
          Text('CLAIMED',
              style: TextStyle(
                  fontSize: 12,
                  letterSpacing: 1.5,
                  color: Colors.green.shade700)),
        ],
      );
    } else {
      action = FilledButton(
        onPressed: _busy != null ? null : () => _claim(v),
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 36),
          padding: const EdgeInsets.symmetric(horizontal: 18),
          textStyle: const TextStyle(
              fontWeight: FontWeight.w600, letterSpacing: 1.5, fontSize: 12),
        ),
        child: _busy == v.code
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white))
            : const Text('CLAIM'),
      );
    }

    return Opacity(
      opacity: dead ? 0.55 : 1,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: cardDecoration(),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 104,
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  color: AppColors.ink,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(6),
                    bottomLeft: Radius.circular(6),
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  v.valueLabel.replaceFirst(' OFF', '\nOFF'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      height: 1.25),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(v.title,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text(v.description, style: const TextStyle(fontSize: 13)),
                      const SizedBox(height: 4),
                      Text(v.conditions,
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.muted)),
                      if (v.expires != null)
                        Text('Valid until ${_date(v.expires!)}',
                            style: const TextStyle(
                                fontSize: 11, color: AppColors.muted)),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              border: Border.all(color: AppColors.gold),
                            ),
                            child: Text(v.code,
                                style: const TextStyle(
                                    fontSize: 11,
                                    letterSpacing: 1.5,
                                    color: AppColors.gold,
                                    fontWeight: FontWeight.w700)),
                          ),
                          const Spacer(),
                          action,
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}