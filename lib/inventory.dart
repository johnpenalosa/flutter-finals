import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class Inventory extends ChangeNotifier {
  Inventory._();
  static final Inventory instance = Inventory._();

  final Map<String, int> _stock = {};
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;

  /// Call once in main() after Firebase.initializeApp.
  void init() {
    _sub ??= FirebaseFirestore.instance.collection('watches').snapshots().listen(
      (snap) {
        _stock.clear();
        for (final d in snap.docs) {
          final s = d.data()['stock'];
          if (s is num) _stock[d.id] = s.toInt();
        }
        notifyListeners();
      },
      onError: (e) => debugPrint('Inventory error: $e'),
    );
  }

  /// null = unknown (not loaded / not in Firestore yet).
  int? stockOf(String id) => _stock[id];

  bool soldOut(String id) => _stock[id] != null && _stock[id]! <= 0;

  bool canAdd(String id, int inCart) {
    final s = _stock[id];
    return s == null || inCart < s;
  }

  bool isShort(String id, int wanted) {
    final s = _stock[id];
    return s != null && wanted > s;
  }

  int maxQty(String id, int cap) {
    final s = _stock[id];
    if (s == null) return cap;
    return s < cap ? (s < 0 ? 0 : s) : cap;
  }
}

/// Dark "Sold Out" circle over a faded image.
class SoldOutOverlay extends StatelessWidget {
  final String watchId;
  final bool small;
  const SoldOutOverlay({super.key, required this.watchId, this.small = false});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Inventory.instance,
        builder: (_, __) {
          if (!Inventory.instance.soldOut(watchId)) {
            return const SizedBox.shrink();
          }
          final d = small ? 76.0 : 120.0;
          return IgnorePointer(
            child: Container(
              color: Colors.white.withValues(alpha: 0.4),
              alignment: Alignment.center,
              child: Container(
                width: d,
                height: d,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.78),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  'Sold Out',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: small ? 13 : 18,
                  ),
                ),
              ),
            ),
          );
        },
      );
}

/// "In stock: 10" / "Only 2 left" / "Sold out" text for the detail page.
class StockLabel extends StatelessWidget {
  final String watchId;
  const StockLabel({super.key, required this.watchId});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Inventory.instance,
        builder: (_, __) {
          final s = Inventory.instance.stockOf(watchId);
          if (s == null) return const SizedBox.shrink();
          if (s <= 0) {
            return Text('Sold out',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.red.shade700));
          }
          if (s <= 3) {
            return Text('Only $s left',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.red.shade700));
          }
          return Text('In stock: $s',
              style: const TextStyle(fontSize: 13, color: Color(0xFF5E6B78)));
        },
      );
}