import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// AppColors comes from main.dart
import 'main.dart';

// ============================================================
// EDIT THESE FIRST. They are inserted into all three documents.
// ============================================================

const kBusinessName = 'Atelier Watches'; // registered / legal name
const kBusinessAddress = '[Your complete business address], Philippines';
const kContactEmail = '[support@yourshop.ph]';
const kContactPhone = '[09XX XXX XXXX]';
const kRegistrationNo = '[DTI / SEC registration no.]';
const kDpoName = '[Name of Data Protection Officer]';
const kDpoEmail = '[privacy@yourshop.ph]';
const kEffectiveDate = 'October 15, 2026';
const kReturnDays = 7; // return window, in days from delivery
const kRefundDays = '7 to 14'; // business days to process a refund

// ============================================================
// DOCUMENT MODEL
// ============================================================

class LegalDoc {
  final String title;
  final String intro;
  final List<(String, String)> sections;
  const LegalDoc(this.title, this.intro, this.sections);
}

final kTerms = LegalDoc(
  'Terms & Conditions',
  'Please read these terms carefully before using the $kBusinessName app. '
      'By creating an account or placing an order, you agree to them.',
  [
    (
      '1. About us',
      '$kBusinessName ("we", "us") is a business registered in the Philippines '
          '($kRegistrationNo), located at $kBusinessAddress. You can reach us at '
          '$kContactEmail or $kContactPhone.'
    ),
    (
      '2. Eligibility',
      'You must be at least 18 years old, or have the permission of a parent or '
          'legal guardian, to create an account and buy from us.'
    ),
    (
      '3. Your account',
      'You must give accurate information and keep your password secret. You are '
          'responsible for activity on your account. Tell us right away if you think '
          'someone else is using it. We may suspend accounts that give false '
          'information or are used for fraud.'
    ),
    (
      '4. Products and information',
      'We try to describe and photograph every watch as accurately as possible. '
          'Colors may look slightly different on your screen. Specifications come '
          'from the manufacturer and may change. If a price or description contains '
          'an obvious error, we may correct it or cancel the order and refund you in '
          'full.'
    ),
    (
      '5. Orders',
      'Placing an order is an offer to buy. An order is accepted when we confirm '
          'it (status "Confirmed"). We may decline or cancel an order if an item is '
          'out of stock, if we cannot verify your details or payment, or if we suspect '
          'fraud. If we cancel after you have paid, you will be refunded in full.'
    ),
    (
      '6. Prices and payment',
      'All prices are in Philippine pesos (PHP) and are shown for the item and size '
          'you select. Accepted payment methods are shown at checkout (Cash on '
          'Delivery, GCash, Bank Transfer, Credit/Debit Card). For GCash, bank '
          'transfer and card payments, we will send you payment instructions or a '
          'secure payment link after you place your order. Never send card details '
          'by chat or text. Orders may be held until payment is confirmed.'
    ),
    (
      '7. Vouchers',
      'Each voucher can be claimed once per account and used on one order. Vouchers '
          'have minimum spend, brand and expiry conditions shown in the app, have no '
          'cash value, and cannot be combined unless stated. We may cancel vouchers '
          'that were obtained or used through abuse or error.'
    ),
    (
      '8. Shipping and delivery',
      'We deliver to the address saved in your account. Please make sure it is '
          'complete and correct, and that someone can receive the parcel. Delivery '
          'times are estimates. If a delivery fails because of a wrong address or '
          'repeated no-show, we may charge for re-delivery or cancel the order. '
          'Please inspect the parcel on arrival and report visible damage right away '
          '(see our Return Policy).'
    ),
    (
      '9. Cancellations, returns and refunds',
      'You can cancel an order in the app while it is still "Pending". Returns and '
          'refunds are covered by our Return Policy, which is part of these terms.'
    ),
    (
      '10. Warranty',
      'Watches may come with a manufacturer or shop warranty, as stated on the '
          'product page or in the box. Warranty does not cover damage from misuse, '
          'water damage beyond the stated water resistance, unauthorized repairs or '
          'normal wear. Nothing in these terms limits your rights under the Consumer '
          'Act of the Philippines (RA 7394) or other laws.'
    ),
    (
      '11. Intellectual property',
      'The app, our logo, text and design belong to $kBusinessName. Brand names and '
          'product images belong to their respective owners and are used only to '
          'identify the products we sell. You may not copy or reuse them without '
          'permission.'
    ),
    (
      '12. Acceptable use',
      'Do not use the app to break the law, interfere with its security or '
          'operation, use bots or scrapers, or place orders you do not intend to '
          'pay for.'
    ),
    (
      '13. Limitation of liability',
      'To the extent allowed by law, we are not liable for indirect or consequential '
          'losses, or for delays caused by couriers, payment providers, or events '
          'beyond our control. Nothing here excludes liability that cannot be '
          'excluded by law, including for fraud or for goods that are defective or '
          'not as described.'
    ),
    (
      '14. Changes to these terms',
      'We may update these terms. The latest version is always in the app, with the '
          'effective date shown at the top. Continuing to use the app after a change '
          'means you accept it. Orders already placed are governed by the terms in '
          'effect when you placed them.'
    ),
    (
      '15. Governing law and disputes',
      'These terms are governed by the laws of the Republic of the Philippines. '
          'Please contact us first so we can try to settle any complaint. You may '
          'also bring a complaint to the Department of Trade and Industry (DTI). '
          'If a dispute goes to court, it will be filed in the proper courts of '
          '[your city], Philippines.'
    ),
    (
      '16. Contact',
      '$kBusinessName\n$kBusinessAddress\n$kContactEmail  •  $kContactPhone'
    ),
  ],
);

final kPrivacy = LegalDoc(
  'Privacy Policy',
  '$kBusinessName respects your privacy. This policy explains what personal '
      'information we collect, why we collect it, and your rights under the Data '
      'Privacy Act of 2012 (Republic Act No. 10173) and its implementing rules.',
  [
    (
      '1. Who is responsible',
      '$kBusinessName ($kBusinessAddress) is the personal information controller. '
          'Our Data Protection Officer is $kDpoName, reachable at $kDpoEmail.'
    ),
    (
      '2. What we collect',
      '• Account details: name, email address, password (stored securely by our '
          'authentication provider, never in readable form).\n'
          '• Delivery details: receiver name, mobile number, address, postal code, '
          'delivery notes and address label.\n'
          '• Order details: items, sizes, quantities, prices, vouchers used, payment '
          'method, order status and dates. If you pay by GCash, the GCash number you '
          'enter; if by bank transfer, your chosen bank.\n'
          '• App activity saved to your account: cart, wishlist and claimed '
          'vouchers.\n'
          '• Technical data: basic device and log information needed to run and '
          'secure the app.\n\n'
          'We do not store your card number, CVV or online banking credentials in '
          'the app.'
    ),
    (
      '3. Why we use it',
      '• To create and secure your account and verify your email.\n'
          '• To process, deliver and support your orders, including payments, '
          'refunds, returns and warranty.\n'
          '• To save your cart, wishlist and vouchers across devices.\n'
          '• To contact you about your order or account.\n'
          '• To prevent fraud and abuse and to meet legal, tax and accounting '
          'obligations.\n'
          '• To improve the app.\n\n'
          'We only send marketing messages if you agree, and you can opt out at any '
          'time.'
    ),
    (
      '4. Basis for processing',
      'We process your information because you gave consent, because it is '
          'necessary to carry out your order and our contract with you, because the '
          'law requires it, or for our legitimate interests such as fraud '
          'prevention, in line with Sections 12 and 13 of the Data Privacy Act.'
    ),
    (
      '5. Who we share it with',
      'We share only what is needed with:\n'
          '• Service providers: Google Firebase (authentication, database and '
          'hosting) and similar technology providers.\n'
          '• Couriers and delivery partners (your name, phone number and address).\n'
          '• Payment providers (GCash, banks, card processors) to complete your '
          'payment.\n'
          '• Government agencies or courts when required by law.\n\n'
          'We do not sell your personal information. Our providers may only use it '
          'to serve us, under agreements that require them to protect it.'
    ),
    (
      '6. Storage and transfers',
      'Your data is stored on servers of our cloud providers, which may be located '
          'outside the Philippines. We use providers that apply security '
          'safeguards, and we remain responsible for protecting your data.'
    ),
    (
      '7. How long we keep it',
      'We keep account data while your account is active. Order records are kept '
          'for as long as needed for warranty, returns, disputes, and tax and '
          'accounting rules (generally up to [5 to 10] years). After that, data is '
          'deleted or anonymized.'
    ),
    (
      '8. Security',
      'We use reasonable organizational, physical and technical measures, such as '
          'encrypted connections, access rules, and limiting who can see your data. '
          'No system is perfectly secure. If a breach affecting your data occurs, '
          'we will notify you and the National Privacy Commission as required by '
          'law.'
    ),
    (
      '9. Your rights',
      'Under the Data Privacy Act you have the right to:\n'
          '• be informed about how your data is processed;\n'
          '• access your personal data;\n'
          '• object to processing, including for marketing;\n'
          '• correct inaccurate data;\n'
          '• request erasure or blocking of data that is unlawfully held or no '
          'longer needed;\n'
          '• data portability, where applicable;\n'
          '• claim compensation for damages from inaccurate or unlawfully used '
          'data;\n'
          '• withdraw consent at any time.\n\n'
          'You can update your name and address in the app. For anything else, '
          'including account deletion, email $kDpoEmail. We may need to keep some '
          'records (such as orders) where the law requires it.'
    ),
    (
      '10. Children',
      'The app is not meant for children under 18. If you believe a minor gave us '
          'personal data without a parent or guardian\'s consent, contact us and we '
          'will delete it.'
    ),
    (
      '11. Changes to this policy',
      'We may update this policy and will show the new effective date. For '
          'significant changes we will notify you in the app or by email.'
    ),
    (
      '12. Contact and complaints',
      'Questions or requests: $kDpoName, $kDpoEmail, $kBusinessAddress.\n\n'
          'If you believe your rights were violated, you may file a complaint with '
          'the National Privacy Commission (privacy.gov.ph).'
    ),
  ],
);

final kReturns = LegalDoc(
  'Return & Refund Policy',
  'We want you to be happy with your watch. This policy explains how cancellations, '
      'returns, exchanges and refunds work. It does not affect your rights under '
      'the Consumer Act of the Philippines (RA 7394) and other applicable laws.',
  [
    (
      '1. Cancelling an order',
      'You can cancel an order yourself in My Orders while its status is '
          '"Pending". After it is confirmed, contact us at $kContactEmail as soon '
          'as possible and we will do our best to help. Any voucher used on a '
          'cancelled pending order is returned to your account.'
    ),
    (
      '2. Inspect your parcel',
      'Please record an unboxing video when you open your parcel. It helps us '
          'resolve issues quickly. If the package looks tampered with or damaged, '
          'tell the courier and contact us right away.'
    ),
    (
      '3. Returns for defects or errors',
      'You may return an item within $kReturnDays days of delivery if it is:\n'
          '• defective or damaged on arrival;\n'
          '• not the item, model, color or size you ordered; or\n'
          '• materially different from its description.\n\n'
          'We will pay the return shipping, and you may choose a replacement '
          '(subject to stock), a repair, or a full refund including the original '
          'shipping fee.'
    ),
    (
      '4. Change of mind and size exchange',
      'You may also return or exchange an item within $kReturnDays days of '
          'delivery if you simply changed your mind or the strap size does not '
          'fit, provided it meets the conditions in section 5. In this case the '
          'return shipping is paid by you.'
    ),
    (
      '5. Conditions for returns',
      '• The watch is unused and unworn, with no scratches, marks or signs of '
          'wear.\n'
          '• Protective films and stickers are still on, where applicable.\n'
          '• The strap has not been resized, cut or altered.\n'
          '• It comes with the original box, papers, warranty card, tags and '
          'accessories.\n'
          '• You have your order number.\n\n'
          'These conditions do not apply when the item is defective or not as '
          'described. We may refuse returns of items that were damaged by '
          'misuse, water damage beyond the stated rating, or unauthorized '
          'repairs.'
    ),
    (
      '6. How to request a return',
      '1. Email $kContactEmail or call $kContactPhone within $kReturnDays days of '
          'delivery.\n'
          '2. Include your order number, the reason, and photos or your unboxing '
          'video if the item is defective or wrong.\n'
          '3. We will review your request and reply with instructions and the '
          'return address.\n'
          '4. Pack the item securely and ship it with tracking. We recommend '
          'insurance for high-value items.'
    ),
    (
      '7. Inspection',
      'When we receive the item, we will inspect it. If it meets this policy, we '
          'will approve your replacement or refund. If it does not, we will explain '
          'why and arrange to send it back to you.'
    ),
    (
      '8. Refunds',
      'Approved refunds are processed within $kRefundDays business days after we '
          'receive and inspect the item. They are returned to your original '
          'payment method. For Cash on Delivery orders, we will refund by GCash or '
          'bank transfer to the account you give us. Vouchers are not refunded as '
          'cash.'
    ),
    (
      '9. Warranty',
      'Items with a manufacturer or shop warranty are covered as described on the '
          'product page or warranty card. For warranty repairs, contact us with your '
          'order number and the warranty card.'
    ),
    (
      '10. Contact',
      '$kBusinessName\n$kBusinessAddress\n$kContactEmail  •  $kContactPhone'
    ),
  ],
);

// ============================================================
// SCREENS
// ============================================================

/// Menu page listing the three documents.
class LegalMenuScreen extends StatelessWidget {
  const LegalMenuScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('LEGAL')),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                for (final d in [kTerms, kPrivacy, kReturns])
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: cardDecoration(),
                    child: ListTile(
                      title: Text(d.title,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => openLegal(context, d),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
}

void openLegal(BuildContext context, LegalDoc d) => Navigator.push(
    context, MaterialPageRoute(builder: (_) => LegalScreen(doc: d)));

class LegalScreen extends StatelessWidget {
  final LegalDoc doc;
  const LegalScreen({super.key, required this.doc});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(doc.title.toUpperCase())),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(doc.title,
                    style: GoogleFonts.playfairDisplay(
                        fontSize: 26, fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                Text('Effective $kEffectiveDate',
                    style:
                        const TextStyle(fontSize: 12, color: AppColors.muted)),
                const SizedBox(height: 16),
                Text(doc.intro, style: const TextStyle(fontSize: 14, height: 1.5)),
                for (final s in doc.sections) ...[
                  const SizedBox(height: 22),
                  Text(s.$1,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Text(s.$2, style: const TextStyle(fontSize: 14, height: 1.5)),
                ],
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      );
}

/// "By signing up you agree to our Terms and Privacy Policy" line.
/// Use it on the Sign up screen: const LegalConsentText()
class LegalConsentText extends StatelessWidget {
  const LegalConsentText({super.key});

  Widget _link(BuildContext context, String text, LegalDoc d) => InkWell(
        onTap: () => openLegal(context, d),
        child: Text(text,
            style: const TextStyle(
                fontSize: 12,
                color: AppColors.ink,
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.underline)),
      );

  @override
  Widget build(BuildContext context) {
    const t = TextStyle(fontSize: 12, color: AppColors.muted);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const Text('By signing up, you agree to our ', style: t),
          _link(context, 'Terms', kTerms),
          const Text(', ', style: t),
          _link(context, 'Privacy Policy', kPrivacy),
          const Text(' and ', style: t),
          _link(context, 'Return Policy', kReturns),
          const Text('.', style: t),
        ],
      ),
    );
  }
}