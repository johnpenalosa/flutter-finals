import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'cart_screen.dart';
import 'inventory.dart';
// AppColors, Watch, sampleWatches, peso, WatchImage, toast come from main.dart
import 'main.dart';

// ============================================================
// WISHLIST STATE (saved in users/{uid}.wishlist)
// ============================================================

class Wishlist extends ChangeNotifier {
  Wishlist._();
  static final Wishlist instance = Wishlist._();

  final List<String> _ids = [];
  String? _uid;
  bool _loaded = false;
  StreamSubscription<User?>? _sub;

  /// Saved watches, in the order they were added.
  List<Watch> get items => [
        for (final id in _ids)
          for (final w in sampleWatches)
            if (w.id == id) w
      ];
  int get count => items.length;
  bool contains(String id) => _ids.contains(id);

  /// Call once in main() after Firebase.initializeApp.
  void init() {
    _sub ??= FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user == null) {
        _uid = null;
        _loaded = false;
        _ids.clear();
        notifyListeners();
      } else if (user.uid != _uid) {
        _load(user.uid);
      }
    });
  }

  Future<void> _load(String uid) async {
    _uid = uid;
    _loaded = false;
    _ids.clear();
    notifyListeners();
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      if (_uid != uid) return; // account changed while loading

      final hadLocal = _ids.isNotEmpty; // hearts tapped while loading
      final list = doc.data()?['wishlist'];
      if (list is List) {
        for (final e in list) {
          final id = e.toString();
          if (!_ids.contains(id)) _ids.add(id);
        }
      }
      _loaded = true;
      notifyListeners();
      if (hadLocal) _save();
    } catch (e) {
      // Not saved until loaded, so the saved list is never overwritten.
      debugPrint('Wishlist load error: $e');
    }
  }

  Future<void> _save() async {
    final uid = _uid;
    if (uid == null || !_loaded) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .set({'wishlist': List<String>.from(_ids)}, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Wishlist save error: $e');
    }
  }

  void toggle(String id) {
    if (!_ids.remove(id)) _ids.add(id);
    notifyListeners();
    _save();
  }
}

// ============================================================
// HEART BUTTON
// ============================================================

class HeartButton extends StatelessWidget {
  final String watchId;
  final double size;

  /// Draws a soft white circle behind the heart (used on top of images).
  final bool bubble;

  const HeartButton(
      {super.key, required this.watchId, this.size = 20, this.bubble = false});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Wishlist.instance,
        builder: (_, __) {
          final on = Wishlist.instance.contains(watchId);
          return Material(
            color: bubble ? Colors.white.withValues(alpha: 0.85) : Colors.transparent,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => Wishlist.instance.toggle(watchId),
              child: Padding(
                padding: const EdgeInsets.all(7),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  transitionBuilder: (child, a) =>
                      ScaleTransition(scale: a, child: child),
                  child: Icon(
                    on ? Icons.favorite : Icons.favorite_border,
                    key: ValueKey(on),
                    size: size,
                    color: on ? Colors.red.shade600 : AppColors.ink,
                  ),
                ),
              ),
            ),
          );
        },
      );
}

// ============================================================
// WISHLIST SCREEN
// ============================================================

class WishlistScreen extends StatelessWidget {
  const WishlistScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('WISHLIST')),
        body: ListenableBuilder(
          listenable: Listenable.merge([Wishlist.instance, Inventory.instance]),
          builder: (context, _) {
            final items = Wishlist.instance.items;
            if (items.isEmpty) return _empty(context);
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 24, color: AppColors.line),
                  itemBuilder: (_, i) => _row(context, items[i]),
                ),
              ),
            );
          },
        ),
      );

  Widget _empty(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.favorite_border,
                  size: 64, color: AppColors.muted),
              const SizedBox(height: 16),
              const Text('Your wishlist is empty.',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              const Text('Tap the heart on any watch to save it here.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.muted)),
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

  Widget _row(BuildContext context, Watch w) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 90,
            height: 90,
            decoration: cardDecoration(),
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
                        color: AppColors.ink, fontSize: 12, letterSpacing: 1)),
                const SizedBox(height: 2),
                Text(w.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, height: 1.3)),
                const SizedBox(height: 6),
                Text(peso(w.price),
                    style: const TextStyle(
                        color: AppColors.gold,
                        fontSize: 15,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: Inventory.instance.soldOut(w.id)
                      ? null
                      : () async {
                          final size = await pickSize(context, w);
                          if (size == null || !context.mounted) return;
                          if (!Cart.instance.add(w, size)) {
                            toast(context, 'No more stock available.');
                            return;
                          }
                          toast(context, 'Added to cart (size $size).');
                        },
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 36),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    textStyle: const TextStyle(
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.5,
                        fontSize: 11),
                  ),
                  child: Text(
                      Inventory.instance.soldOut(w.id) ? 'SOLD OUT' : 'ADD TO CART'),
                ),
              ],
            ),
          ),
          HeartButton(watchId: w.id),
        ],
      );
}