import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'address_screen.dart';
import 'cart_screen.dart';
import 'inventory.dart';
import 'payment_service.dart';
// AppColors, peso, WatchImage, Reveal, toast come from main.dart
import 'main.dart';
import 'vouchers.dart';

/// Shipping fee in PHP. Set an amount if you charge for shipping (0 = free).
const kShippingFee = 0;

/// Highest amount GCash (through Xendit) accepts in one payment.
const kGcashMax = 100000;

const kPaymentMethods = [
  'Cash on Delivery',
  'GCash',
];

class StockException implements Exception {
  final String message;
  StockException(this.message);
  @override
  String toString() => message;
}

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});
  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  ShippingAddress? _address;
  String _payment = kPaymentMethods.first;
  bool _loading = true;
  bool _busy = false;

  Voucher? _voucher;

  /// Discount from the selected voucher (0 if none / no longer valid).
  int get _discount {
    final v = _voucher;
    final cart = Cart.instance;
    if (v == null || !v.isEligible(cart.items, cart.total)) return 0;
    return v.discountFor(cart.items);
  }

  bool get _hasAddress => _address?.isComplete ?? false;

  @override
  void initState() {
    super.initState();
    _loadAddress();
  }

  Future<void> _loadAddress() async {
    final a = await ShippingAddress.load();
    if (!mounted) return;
    setState(() {
      _address = a;
      _loading = false;
    });
    // No address yet? Open the form automatically.
    if (!_hasAddress) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _editAddress();
      });
    }
  }

  Future<void> _editAddress() async {
    final result = await Navigator.push<ShippingAddress>(
      context,
      MaterialPageRoute(builder: (_) => AddressScreen(initial: _address)),
    );
    if (result != null && mounted) setState(() => _address = result);
  }

  Future<void> _placeOrder() async {
    // Cannot check out without a complete address
    if (!_hasAddress) {
      toast(context, 'Please add your shipping address first.');
      _editAddress();
      return;
    }
    final cart = Cart.instance;
    if (cart.isEmpty) return;

    // Stock check (the server checks again inside the transaction)
    final wanted = <String, int>{};
    for (final i in cart.items) {
      wanted[i.watch.id] = (wanted[i.watch.id] ?? 0) + i.qty;
    }
    for (final e in wanted.entries) {
      if (Inventory.instance.isShort(e.key, e.value)) {
        final name = cart.items.firstWhere((i) => i.watch.id == e.key).watch.name;
        final left = Inventory.instance.stockOf(e.key) ?? 0;
        toast(
            context,
            left <= 0
                ? '$name is sold out. Please remove it from your cart.'
                : 'Only $left left of $name. Please reduce the quantity.');
        return;
      }
    }

    // GCash (Xendit) only accepts PHP 1 to PHP 100,000 per payment
    final payTotal = cart.total + kShippingFee - _discount;
    if (_payment == 'GCash' && payTotal > kGcashMax) {
      toast(context,
          'GCash supports orders up to ${peso(kGcashMax)} only. Please choose Cash on Delivery.');
      return;
    }

    setState(() => _busy = true);
    final user = FirebaseAuth.instance.currentUser;

    // Re-check the voucher against the current cart
    final voucher =
        (_voucher != null && _voucher!.isEligible(cart.items, cart.total))
            ? _voucher
            : null;
    final discount = voucher?.discountFor(cart.items) ?? 0;

    try {
      final db = FirebaseFirestore.instance;
      final orderRef = db.collection('orders').doc();
      final payDetails = _paymentDetails();
      final orderTotal = cart.total + kShippingFee - discount;
      String paymentStatus = 'unpaid';

      // GCash: pay first through Xendit, save the order only after it is PAID.
      if (_payment == 'GCash' && orderTotal > 0) {
        final paid = await PaymentService.payWithGcash(
          context,
          orderId: 'ORDER-${orderRef.id}',
          amount: orderTotal,
          email: user?.email ?? '',
          description: cart.items
              .map((i) =>
                  '${i.watch.brand} ${i.watch.name} (${i.size}) x${i.qty}')
              .join(', '),
        );
        if (paid == null) {
          if (mounted) toast(context, 'Payment was not completed.');
          if (mounted) setState(() => _busy = false);
          return;
        }
        payDetails['invoiceId'] = paid.invoiceId;
        payDetails['paid'] = true;
        paymentStatus = 'paid';
      }
      final data = <String, dynamic>{
        'uid': user?.uid,
        'email': user?.email,
        'shipping': _address!.toMap(),
        'payment': _payment,
        'paymentDetails': payDetails,
        'items': [
          for (final i in cart.items)
            {
              'id': i.watch.id,
              'brand': i.watch.brand,
              'name': i.watch.name,
              'price': i.watch.price,
              'size': i.size,
              'qty': i.qty,
            }
        ],
        'subtotal': cart.total,
        'shippingFee': kShippingFee,
        'voucher': voucher?.code,
        'discount': discount,
        'total': orderTotal,
        'status': paymentStatus == 'paid' ? 'paid' : 'pending',
        'paymentStatus': paymentStatus,
        'paidAt': paymentStatus == 'paid' ? FieldValue.serverTimestamp() : null,
        'createdAt': FieldValue.serverTimestamp(),
      };

      final userRef = db.collection('users').doc(user!.uid);
      final need = <String, int>{};
      for (final i in cart.items) {
        need[i.watch.id] = (need[i.watch.id] ?? 0) + i.qty;
      }

      // One transaction: checks the voucher and the stock on the server,
      // saves the order, marks the voucher as used and lowers the stock.
      await db.runTransaction((tx) async {
        // ---- reads first ----
        DocumentSnapshot<Map<String, dynamic>>? userSnap;
        if (voucher != null) userSnap = await tx.get(userRef);
        final stockSnaps = <String, DocumentSnapshot<Map<String, dynamic>>>{};
        for (final id in need.keys) {
          stockSnaps[id] = await tx.get(db.collection('watches').doc(id));
        }

        // ---- checks ----
        if (voucher != null) {
          final vm = userSnap!.data()?['vouchers'];
          final entry = vm is Map ? vm[voucher.code] : null;
          if (entry is! Map) {
            throw VoucherException('You have not claimed this voucher.');
          }
          if (entry['usedAt'] != null) {
            throw VoucherException('This voucher was already used.');
          }
        }
        for (final e in need.entries) {
          final stock = stockSnaps[e.key]!.data()?['stock'];
          if (stock is num && stock < e.value) {
            final name =
                cart.items.firstWhere((i) => i.watch.id == e.key).watch.name;
            throw StockException(stock <= 0
                ? '$name just sold out.'
                : 'Only ${stock.toInt()} left of $name.');
          }
        }

        // ---- writes ----
        tx.set(orderRef, data);
        if (voucher != null) {
          tx.update(userRef, {
            'vouchers.${voucher.code}.usedAt': FieldValue.serverTimestamp(),
          });
        }
        for (final e in need.entries) {
          final stock = stockSnaps[e.key]!.data()?['stock'];
          if (stock is num) {
            tx.update(db.collection('watches').doc(e.key),
                {'stock': stock.toInt() - e.value});
          }
        }
      });
      if (voucher != null) VoucherStore.instance.markUsed(voucher.code);

      cart.clear();
      if (!mounted) return;
      await _showSuccess(orderRef.id);
      if (mounted) Navigator.popUntil(context, (r) => r.isFirst);
      return;
    } on StockException catch (e) {
      if (mounted) toast(context, e.message);
    } on PaymentException catch (e) {
      if (mounted) toast(context, e.message);
    } on VoucherException catch (e) {
      if (mounted) {
        setState(() => _voucher = null);
        toast(context, e.message);
      }
    } catch (e) {
      debugPrint('Order error: $e');
      // TEMPORARY: shows the real error so we can find the problem.
      // After it is fixed, change back to: 'Could not place order. Please try again.'
      if (mounted) toast(context, 'Order error: $e');
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _showSuccess(String orderId) => showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          shape: const RoundedRectangleBorder(),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 800),
                curve: Curves.elasticOut,
                builder: (_, s, child) =>
                    Transform.scale(scale: s, child: child),
                child: const Icon(Icons.check_circle,
                    size: 72, color: AppColors.gold),
              ),
              const SizedBox(height: 16),
              const Text('Order placed',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text('Order #${orderId.substring(0, 8).toUpperCase()}',
                  style: const TextStyle(
                      color: AppColors.muted, letterSpacing: 1)),
              const SizedBox(height: 12),
              Text(_successMessage(), textAlign: TextAlign.center),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('BACK TO SHOP'),
            ),
          ],
        ),
      );

  // ---------- UI ----------

  @override
  Widget build(BuildContext context) {
    final cart = Cart.instance;
    final total = cart.total + kShippingFee - _discount;

    return Scaffold(
      appBar: AppBar(title: const Text('CHECKOUT')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : cart.isEmpty
              ? const Center(child: Text('Your cart is empty.'))
              : Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 560),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Reveal(child: _addressSection()),
                                Reveal(
                                  delay: const Duration(milliseconds: 100),
                                  child: _itemsSection(cart),
                                ),
                                Reveal(
                                  delay: const Duration(milliseconds: 200),
                                  child: _paymentSection(),
                                ),
                                Reveal(
                                  delay: const Duration(milliseconds: 250),
                                  child: _voucherSection(),
                                ),
                                Reveal(
                                  delay: const Duration(milliseconds: 300),
                                  child: _priceSection(cart),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    _bottomBar(total),
                  ],
                ),
    );
  }

  Widget _section(String title, Widget child, {Color? borderColor}) =>
      Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            border: Border.all(color: borderColor ?? AppColors.line)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title.toUpperCase(),
                style: const TextStyle(
                    fontSize: 12,
                    letterSpacing: 2,
                    fontWeight: FontWeight.w700,
                    color: AppColors.gold)),
            const SizedBox(height: 14),
            child,
          ],
        ),
      );

  Widget _addressSection() {
    final a = _address;

    // No complete address: checkout is blocked
    if (!_hasAddress) {
      return _section(
        'Shipping address',
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.location_off_outlined, color: Colors.red),
                SizedBox(width: 10),
                Expanded(
                  child: Text('No shipping address yet',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'You need to add a shipping address before you can place an order.',
              style: TextStyle(fontSize: 13, color: AppColors.muted),
            ),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: _editAddress,
              child: const Text('ADD ADDRESS'),
            ),
          ],
        ),
        borderColor: Colors.red.shade300,
      );
    }

    return _section(
      'Shipping address',
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(Icons.location_on_outlined, color: AppColors.ink),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${a!.name}  •  ${a.phone}',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(a.fullAddress,
                    style: const TextStyle(fontSize: 13, height: 1.4)),
                if (a.notes.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text('Note: ${a.notes}',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.muted)),
                ],
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  color: AppColors.mist,
                  child: Text(a.label.toUpperCase(),
                      style: const TextStyle(fontSize: 10, letterSpacing: 1.5)),
                ),
              ],
            ),
          ),
          TextButton(onPressed: _editAddress, child: const Text('CHANGE')),
        ],
      ),
    );
  }

  Widget _itemsSection(Cart cart) => _section(
        'Order summary',
        Column(
          children: [
            for (final i in cart.items)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      color: AppColors.mist,
                      padding: const EdgeInsets.all(4),
                      child: WatchImage(url: i.watch.imageUrl),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(i.watch.brand.toUpperCase(),
                              style: const TextStyle(
                                  color: AppColors.gold,
                                  fontSize: 10,
                                  letterSpacing: 2)),
                          Text(i.watch.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13)),
                          const SizedBox(height: 2),
                          Text('Size: ${i.size}  •  Qty: ${i.qty}',
                              style: const TextStyle(
                                  fontSize: 12, color: AppColors.muted)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(peso(i.watch.price * i.qty),
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
          ],
        ),
      );

  /// Extra payment info saved with the order.
  /// (GCash no longer needs a number: the Xendit page asks for it.)
  Map<String, dynamic> _paymentDetails() => <String, dynamic>{};

  String _successMessage() {
    switch (_payment) {
      case 'GCash':
        return 'Payment received via GCash. Thank you!';
      default:
        return 'Thank you! Please pay when your order arrives.';
    }
  }

  /// Notes shown under the selected payment method.
  Widget _paymentExtra() {
    const note = TextStyle(fontSize: 12, color: AppColors.muted);
    switch (_payment) {
      case 'GCash':
        return const Padding(
          padding: EdgeInsets.only(top: 8),
          child: Text(
            'After you tap Place Order, the GCash payment page will open. '
            'Enter your GCash details and finish the payment there, then '
            'return to this app.',
            style: note,
          ),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _paymentSection() => _section(
        'Payment method',
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final m in kPaymentMethods)
              InkWell(
                onTap: () => setState(() => _payment = m),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    children: [
                      Icon(
                        _payment == m
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                        color: _payment == m ? AppColors.ink : AppColors.muted,
                        size: 22,
                      ),
                      const SizedBox(width: 12),
                      Text(m),
                    ],
                  ),
                ),
              ),
            _paymentExtra(),
          ],
        ),
      );

  // ---------- Voucher ----------

  Widget _voucherSection() {
    final v = _voucher;
    final cart = Cart.instance;
    final valid = v != null && v.isEligible(cart.items, cart.total);

    return _section(
      'Voucher',
      v == null
          ? Row(
              children: [
                const Icon(Icons.local_offer_outlined, color: AppColors.muted),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text('No voucher applied',
                      style: TextStyle(color: AppColors.muted)),
                ),
                TextButton(onPressed: _pickVoucher, child: const Text('SELECT')),
              ],
            )
          : Row(
              children: [
                const Icon(Icons.local_offer, color: AppColors.gold),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${v.code}  •  ${v.valueLabel}',
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      Text(
                        valid
                            ? 'You save ${peso(_discount)}'
                            : 'This voucher does not apply to your cart',
                        style: TextStyle(
                            fontSize: 12,
                            color: valid
                                ? AppColors.muted
                                : Colors.red.shade700),
                      ),
                    ],
                  ),
                ),
                TextButton(onPressed: _pickVoucher, child: const Text('CHANGE')),
                TextButton(
                  onPressed: () => setState(() => _voucher = null),
                  child: const Text('REMOVE'),
                ),
              ],
            ),
    );
  }

  Future<void> _pickVoucher() async {
    final cart = Cart.instance;
    final picked = await showModalBottomSheet<Voucher>(
      context: context,
      backgroundColor: AppColors.paper,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(12))),
      builder: (ctx) {
        final list = VoucherStore.instance.usable;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Your vouchers',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                if (list.isEmpty) ...[
                  const Text(
                    'You have no vouchers to use yet. Claim some first.',
                    style: TextStyle(color: AppColors.muted),
                  ),
                  const SizedBox(height: 14),
                  FilledButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const VouchersScreen()),
                      ).then((_) {
                        if (mounted) setState(() {});
                      });
                    },
                    child: const Text('GET VOUCHERS'),
                  ),
                ] else
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        for (final v in list)
                          Builder(builder: (_) {
                            final reason =
                                v.ineligibleReason(cart.items, cart.total);
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              enabled: reason == null,
                              leading: const Icon(Icons.local_offer_outlined),
                              title: Text('${v.code}  •  ${v.valueLabel}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600)),
                              subtitle: Text(reason ?? v.conditions),
                              trailing: reason == null
                                  ? const Icon(Icons.chevron_right)
                                  : null,
                              onTap: reason == null
                                  ? () => Navigator.pop(ctx, v)
                                  : null,
                            );
                          }),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
    if (picked != null && mounted) setState(() => _voucher = picked);
  }

  Widget _priceRow(String l, String r, {bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(l,
                style: TextStyle(
                    fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
                    fontSize: bold ? 16 : 14)),
            Text(r,
                style: TextStyle(
                    fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
                    fontSize: bold ? 16 : 14)),
          ],
        ),
      );

  Widget _priceSection(Cart cart) => _section(
        'Payment details',
        Column(
          children: [
            _priceRow('Subtotal', peso(cart.total)),
            _priceRow(
                'Shipping', kShippingFee == 0 ? 'FREE' : peso(kShippingFee)),
            const Divider(color: AppColors.line),
            if (_discount > 0)
              _priceRow('Voucher (${_voucher!.code})', '-${peso(_discount)}'),
            _priceRow('Total', peso(cart.total + kShippingFee - _discount),
                bold: true),
          ],
        ),
      );

  Widget _bottomBar(int total) => Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        decoration: const BoxDecoration(
          color: AppColors.paper,
          border: Border(top: BorderSide(color: AppColors.line)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!_hasAddress)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text('Add a shipping address to place your order.',
                      style:
                          TextStyle(fontSize: 12, color: Colors.red.shade700)),
                ),
              Row(
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Total',
                          style:
                              TextStyle(fontSize: 12, color: AppColors.muted)),
                      Text(peso(total),
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.w700)),
                    ],
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: FilledButton(
                      onPressed: (_hasAddress && !_busy) ? _placeOrder : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.ink,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: AppColors.line,
                        disabledForegroundColor: AppColors.muted,
                      ),
                      child: _busy
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: AppColors.muted))
                          : const Text('PLACE ORDER'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
}