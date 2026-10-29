import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'checkout_screen.dart';
import 'inventory.dart';

// Uses AppColors, Watch, peso, WatchImage, toast, and button from main.dart
import 'main.dart';

// ============================================================
// CART STATE (shared across the whole app)
// ============================================================

class CartItem {
  final Watch watch;
  final String size; // strap size: S / M / L
  int qty;
  CartItem(this.watch, this.size, [this.qty = 1]);

  /// Same watch in a different size is a different cart line.
  String get key => '${watch.id}|$size';
}

class Cart extends ChangeNotifier {
  Cart._();
  static final Cart instance = Cart._();

  final Map<String, CartItem> _items = {};
  String? _uid; // which account the cart belongs to
  bool _loaded = false;
  Timer? _debounce;
  StreamSubscription<User?>? _sub;

  List<CartItem> get items => _items.values.toList();
  bool get isEmpty => _items.isEmpty;
  int get count => _items.values.fold(0, (s, i) => s + i.qty);
  int get total =>
      _items.values.fold(0, (s, i) => s + i.watch.price * i.qty);

  /// Call once in main() after Firebase.initializeApp.
  /// When a user logs in (or reloads the page while still logged in), their
  /// saved cart is loaded. On logout, the in-memory cart is cleared.
  void init() {
    _sub ??= FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user == null) {
        _reset();
      } else if (user.uid != _uid) {
        _load(user.uid);
      }
    });
  }

  void _reset() {
    _debounce?.cancel();
    _uid = null;
    _loaded = false;
    _items.clear();
    notifyListeners();
  }

  Future<void> _load(String uid) async {
    _debounce?.cancel();
    _uid = uid;
    _loaded = false;
    _items.clear();
    notifyListeners();

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      if (_uid != uid) return; // account changed while loading

      final hadLocal = _items.isNotEmpty; // items added while loading
      final list = doc.data()?['cart'];
      if (list is List) {
        for (final e in list) {
          if (e is! Map) continue;
          final id = e['id']?.toString();
          final qty = e['qty'] is num ? (e['qty'] as num).toInt() : 0;
          var size = (e['size'] ?? 'M').toString(); // old carts had no size
          if (!kSizes.contains(size)) size = 'M';
          if (id == null || qty < 1) continue;
          final key = '$id|$size';
          if (_items.containsKey(key)) continue;
          final match = sampleWatches.where((w) => w.id == id);
          if (match.isEmpty) continue; // no longer in the catalog
          _items[key] = CartItem(match.first, size, qty);
        }
      }
      _loaded = true;
      notifyListeners();
      if (hadLocal) _scheduleSave();
    } catch (e) {
      // The cart is not saved until it has loaded,
      // so the saved cart is never overwritten.
      debugPrint('Cart load error: $e');
    }
  }

  void _scheduleSave() {
    final uid = _uid;
    if (uid == null || !_loaded) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      if (_uid != uid) return;
      try {
        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'cart': [
            for (final i in _items.values)
              {'id': i.watch.id, 'size': i.size, 'qty': i.qty}
          ],
        }, SetOptions(merge: true));
      } catch (e) {
        debugPrint('Cart save error: $e');
      }
    });
  }

  /// Total quantity of one watch across all sizes.
  int qtyOfWatch(String id) => _items.values
      .where((i) => i.watch.id == id)
      .fold(0, (s, i) => s + i.qty);

  /// Returns false when there is no more stock for this watch.
  bool add(Watch w, String size) {
    if (!Inventory.instance.canAdd(w.id, qtyOfWatch(w.id))) return false;
    final key = '${w.id}|$size';
    final existing = _items[key];
    if (existing != null) {
      existing.qty++;
    } else {
      _items[key] = CartItem(w, size);
    }
    notifyListeners();
    _scheduleSave();
    return true;
  }

  void decrease(String key) {
    final item = _items[key];
    if (item == null) return;
    if (item.qty > 1) {
      item.qty--;
      notifyListeners();
      _scheduleSave();
    }
  }

  void remove(String key) {
    _items.remove(key);
    notifyListeners();
    _scheduleSave();
  }

  void clear() {
    _items.clear();
    notifyListeners();
    _scheduleSave();
  }
}

// ============================================================
// CART SCREEN
// ============================================================

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});
  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('CART')),
      body: ListenableBuilder(
        listenable: Listenable.merge([Cart.instance, Inventory.instance]),
        builder: (context, _) {
          final cart = Cart.instance;
          if (cart.isEmpty) return _empty(context);

          final items = cart.items;
          return Column(
            children: [
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 24, color: AppColors.line),
                  itemBuilder: (_, i) => _CartRow(item: items[i]),
                ),
              ),
              _summary(cart),
            ],
          );
        },
      ),
    );
  }

  Widget _empty(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.shopping_bag_outlined,
                  size: 64, color: AppColors.muted),
              const SizedBox(height: 16),
              const Text('Your cart is empty.',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 24),
              SizedBox(
                width: 240,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('CONTINUE SHOPPING'),
                ),
              ),
            ],
          ),
        ),
      );

  Widget _summary(Cart cart) => Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        decoration: const BoxDecoration(
          color: AppColors.paper,
          border: Border(top: BorderSide(color: AppColors.line)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Subtotal'),
                  Text(peso(cart.total)),
                ],
              ),
              const SizedBox(height: 4),
              const Text('Shipping and taxes calculated at checkout.',
                  style: TextStyle(fontSize: 12, color: AppColors.muted)),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    transitionBuilder: (child, a) =>
                        FadeTransition(opacity: a, child: child),
                    child: Text(
                      peso(cart.total),
                      key: ValueKey(cart.total),
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              button(
                'Checkout',
                false,
                () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const CheckoutScreen())),
              ),
            ],
          ),
        ),
      );
}

class _CartRow extends StatelessWidget {
  final CartItem item;
  const _CartRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final w = item.watch;
    final cart = Cart.instance;

    return Dismissible(
      key: ValueKey(item.key),
      direction: DismissDirection.endToStart,
      background: Container(
        color: AppColors.ink,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      onDismissed: (_) => cart.remove(item.key),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 90,
            height: 90,
            color: AppColors.mist,
            padding: const EdgeInsets.all(6),
            child: Stack(
              children: [
                Positioned.fill(child: WatchImage(url: w.imageUrl)),
                Positioned.fill(
                    child: SoldOutOverlay(watchId: w.id, small: true)),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(w.brand.toUpperCase(),
                    style: const TextStyle(
                        color: AppColors.gold, fontSize: 11, letterSpacing: 2)),
                const SizedBox(height: 2),
                Text(w.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, height: 1.3)),
                const SizedBox(height: 2),
                Text('Size: ${item.size}',
                    style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                if (Inventory.instance.isShort(w.id, cart.qtyOfWatch(w.id)))
                  Text('Only ${Inventory.instance.stockOf(w.id) ?? 0} in stock',
                      style: TextStyle(fontSize: 12, color: Colors.red.shade700)),
                const SizedBox(height: 4),
                Text(peso(w.price),
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _qtyBtn(Icons.remove,
                        item.qty > 1 ? () => cart.decrease(item.key) : null),
                    SizedBox(
                      width: 32,
                      child: Text('${item.qty}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                    ),
                    _qtyBtn(
                      Icons.add,
                      Inventory.instance.canAdd(w.id, cart.qtyOfWatch(w.id))
                          ? () => cart.add(w, item.size)
                          : null,
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => cart.remove(item.key),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.muted,
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 32),
                      ),
                      child: const Text('Remove',
                          style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _qtyBtn(IconData icon, VoidCallback? onTap) => SizedBox(
        width: 32,
        height: 32,
        child: OutlinedButton(
          onPressed: onTap,
          style: OutlinedButton.styleFrom(
            padding: EdgeInsets.zero,
            shape: const RoundedRectangleBorder(),
            side: const BorderSide(color: AppColors.line),
            foregroundColor: AppColors.ink,
          ),
          child: Icon(icon, size: 16),
        ),
      );
}