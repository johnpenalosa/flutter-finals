import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// AppColors, toast, button come from main.dart
import 'main.dart';

const kAddressLabels = ['Home', 'Work', 'Other'];

// ============================================================
// MODEL (saved in users/{uid}.shipping)
// ============================================================

class ShippingAddress {
  final String label, name, phone, province, city, barangay, street, postal, notes;

  const ShippingAddress({
    required this.label,
    required this.name,
    required this.phone,
    required this.province,
    required this.city,
    required this.barangay,
    required this.street,
    required this.postal,
    this.notes = '',
  });

  Map<String, dynamic> toMap() => {
        'label': label,
        'name': name,
        'phone': phone,
        'province': province,
        'city': city,
        'barangay': barangay,
        'street': street,
        'postal': postal,
        'notes': notes,
      };

  static ShippingAddress? fromMap(dynamic m) {
    if (m is! Map) return null;
    String g(String k) => (m[k] ?? '').toString();
    return ShippingAddress(
      label: kAddressLabels.contains(g('label')) ? g('label') : 'Home',
      name: g('name'),
      phone: g('phone'),
      province: g('province'),
      city: g('city'),
      barangay: g('barangay'),
      street: g('street'),
      postal: g('postal'),
      notes: g('notes'),
    );
  }

  /// Is everything required for checkout filled in?
  bool get isComplete =>
      name.trim().length >= 2 &&
      validatePhone(phone) == null &&
      province.trim().isNotEmpty &&
      city.trim().isNotEmpty &&
      barangay.trim().isNotEmpty &&
      street.trim().isNotEmpty &&
      postal.trim().length == 4;

  String get fullAddress => '$street, $barangay, $city, $province $postal';

  // ---------- Validation helpers ----------

  static String? validatePhone(String? v) {
    final p = (v ?? '').replaceAll(RegExp(r'[\s-]'), '');
    if (!RegExp(r'^(?:\+?63|0)9\d{9}$').hasMatch(p)) {
      return 'Enter a valid mobile number (e.g. 09171234567)';
    }
    return null;
  }

  /// +63917... / 63917... -> 0917...
  static String normalizePhone(String v) {
    final p = v.replaceAll(RegExp(r'[\s-]'), '');
    if (p.startsWith('+63')) return '0${p.substring(3)}';
    if (p.startsWith('63')) return '0${p.substring(2)}';
    return p;
  }

  // ---------- Firestore ----------

  static Future<ShippingAddress?> load() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      return fromMap(doc.data()?['shipping']);
    } catch (e) {
      debugPrint('Load address error: $e');
      return null;
    }
  }

  Future<void> save() async {
    var user = FirebaseAuth.instance.currentUser;
    // No login screen: make sure there is a guest account
    // (needs Anonymous enabled in Firebase Console > Authentication)
    user ??= (await FirebaseAuth.instance.signInAnonymously()).user;
    if (user == null) throw StateError('No user');
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .set({'shipping': toMap()}, SetOptions(merge: true));
  }
}

// ============================================================
// ADDRESS FORM SCREEN
// ============================================================

class AddressScreen extends StatefulWidget {
  final ShippingAddress? initial;
  const AddressScreen({super.key, this.initial});
  @override
  State<AddressScreen> createState() => _AddressScreenState();
}

class _AddressScreenState extends State<AddressScreen> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(
      text: widget.initial?.name.isNotEmpty == true
          ? widget.initial!.name
          : (FirebaseAuth.instance.currentUser?.displayName ?? ''));
  late final _phone = TextEditingController(text: widget.initial?.phone ?? '');
  late final _province =
      TextEditingController(text: widget.initial?.province ?? '');
  late final _city = TextEditingController(text: widget.initial?.city ?? '');
  late final _barangay =
      TextEditingController(text: widget.initial?.barangay ?? '');
  late final _street = TextEditingController(text: widget.initial?.street ?? '');
  late final _postal = TextEditingController(text: widget.initial?.postal ?? '');
  late final _notes = TextEditingController(text: widget.initial?.notes ?? '');
  late String _label = widget.initial?.label ?? 'Home';
  bool _busy = false;

  @override
  void dispose() {
    for (final c in [
      _name,
      _phone,
      _province,
      _city,
      _barangay,
      _street,
      _postal,
      _notes
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _req(String? v, String msg) =>
      (v == null || v.trim().isEmpty) ? msg : null;

  Future<void> _save() async {
    if (!_form.currentState!.validate()) {
      toast(context, 'Please complete the required details.');
      return;
    }
    setState(() => _busy = true);
    final a = ShippingAddress(
      label: _label,
      name: _name.text.trim(),
      phone: ShippingAddress.normalizePhone(_phone.text),
      province: _province.text.trim(),
      city: _city.text.trim(),
      barangay: _barangay.text.trim(),
      street: _street.text.trim(),
      postal: _postal.text.trim(),
      notes: _notes.text.trim(),
    );
    try {
      await a.save();
      if (!mounted) return;
      Navigator.pop(context, a);
      return;
    } on FirebaseException catch (e) {
      // Shows the real reason, e.g. permission-denied / operation-not-allowed
      debugPrint('Save address error: ${e.code} ${e.message}');
      if (mounted) toast(context, 'Could not save address (${e.code}).');
    } catch (e) {
      debugPrint('Save address error: $e');
      if (mounted) toast(context, 'Could not save address. Please try again.');
    }
    if (mounted) setState(() => _busy = false);
  }

  Widget _f(
    String label,
    TextEditingController c, {
    String? Function(String?)? validator,
    TextInputType? keyboard,
    TextCapitalization cap = TextCapitalization.words,
    List<TextInputFormatter>? formatters,
    int? maxLength,
    int maxLines = 1,
    String? hint,
  }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextFormField(
          controller: c,
          validator: validator,
          keyboardType: keyboard,
          textCapitalization: cap,
          inputFormatters: formatters,
          maxLength: maxLength,
          maxLines: maxLines,
          decoration: InputDecoration(
              labelText: label, hintText: hint, counterText: ''),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final isNew = widget.initial == null || !widget.initial!.isComplete;
    return Scaffold(
      appBar: AppBar(title: const Text('SHIPPING ADDRESS')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Form(
              key: _form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (isNew)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(12),
                      color: AppColors.mist,
                      child: const Text(
                        'A shipping address is required before you can check out. '
                        'It will be saved to your account so you only have to enter it once.',
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                  _f('Full name', _name,
                      validator: (v) => (v == null || v.trim().length < 2)
                          ? 'Enter the receiver\'s full name'
                          : null),
                  _f('Mobile number', _phone,
                      hint: '09171234567',
                      keyboard: TextInputType.phone,
                      formatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9+\- ]'))
                      ],
                      maxLength: 16,
                      validator: ShippingAddress.validatePhone),
                  _f('Province / Metro Manila', _province,
                      validator: (v) => _req(v, 'Enter your province')),
                  _f('City / Municipality', _city,
                      validator: (v) => _req(v, 'Enter your city')),
                  _f('Barangay', _barangay,
                      validator: (v) => _req(v, 'Enter your barangay')),
                  _f('Street, building, house no.', _street,
                      validator: (v) =>
                          _req(v, 'Enter your street / house no.')),
                  _f('Postal code', _postal,
                      keyboard: TextInputType.number,
                      formatters: [FilteringTextInputFormatter.digitsOnly],
                      maxLength: 4,
                      validator: (v) => (v == null || v.trim().length != 4)
                          ? 'Enter a 4-digit postal code'
                          : null),
                  _f('Landmark / delivery notes (optional)', _notes,
                      cap: TextCapitalization.sentences, maxLines: 2),
                  const Text('Label',
                      style: TextStyle(fontSize: 12, color: AppColors.muted)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final l in kAddressLabels)
                        ChoiceChip(
                          label: Text(l.toUpperCase()),
                          selected: _label == l,
                          labelStyle: TextStyle(
                            fontSize: 12,
                            letterSpacing: 1.2,
                            color: _label == l ? Colors.white : AppColors.ink,
                          ),
                          onSelected: (_) => setState(() => _label = l),
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  button('Save address', _busy, _save),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}