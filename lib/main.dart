import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'address_screen.dart';
import 'cart_screen.dart';
import 'firebase_options.dart';
import 'inventory.dart';
import 'legal_screens.dart';
import 'vouchers.dart';
import 'wishlist.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  if (FirebaseAuth.instance.currentUser == null) {
    try {
      await FirebaseAuth.instance.signInAnonymously();
    } catch (e) {
      debugPrint('Anonymous sign-in failed: $e');
    }
  }

  Catalog.instance.init(); // live catalog from Firestore (start it first)
  Cart.instance.init();
  Wishlist.instance.init();
  VoucherStore.instance.init();
  Inventory.instance.init();
  runApp(const MyApp());
}

class AppScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
      };
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: kAppName,
        debugShowCheckedModeBanner: false,
        scrollBehavior: AppScrollBehavior(),
        theme: buildTheme(),
        builder: (context, child) =>
            SkyBackground(child: child ?? const SizedBox()),
        home: const DashboardScreen(),
      );
}

const kAppName = 'Atelier Watches';
const kTagline = 'Timeless, made for everyday.';

const kLuxuryCurve = Cubic(0.16, 1, 0.3, 1);

class AppColors {
  static const ink = Color(0xFF161B22);
  static const paper = Color(0xFFF3F2EC);
  static const gold = Color(0xFFB8963E);
  static const mist = Color(0xFFF3F2EC);
  static const line = Color(0xFFB3C6DA);
  static const muted = Color(0xFF5E6B78);
  static const outline = Color(0xFF3F6C9B);
  static const skyTop = Color(0xFFB7D3EE);
  static const skyMid = Color(0xFFD6E6F5);
  static const skyBottom = Color(0xFFEDF3F9);
}

class SkyBackground extends StatelessWidget {
  final Widget child;
  const SkyBackground({super.key, required this.child});
  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.skyTop, AppColors.skyMid, AppColors.skyBottom],
          ),
        ),
        child: child,
      );
}

class _SkyTransitions extends PageTransitionsBuilder {
  const _SkyTransitions();
  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final enter = animation.drive(CurveTween(curve: kLuxuryCurve));
    final leave =
        secondaryAnimation.drive(CurveTween(curve: Curves.easeInOutCubic));

    return ScaleTransition(
      scale: Tween<double>(begin: 1.0, end: 0.97).animate(leave),
      child: FadeTransition(
        opacity: Tween<double>(begin: 1.0, end: 0.85).animate(leave),
        child: FadeTransition(
          opacity: enter,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.035),
              end: Offset.zero,
            ).animate(enter),
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.985, end: 1.0).animate(enter),
              child: SkyBackground(child: child),
            ),
          ),
        ),
      ),
    );
  }
}

BoxDecoration cardDecoration() => BoxDecoration(
      color: AppColors.mist,
      borderRadius: BorderRadius.circular(6),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.14),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    );

class SilverChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const SilverChip(
      {super.key,
      required this.label,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) => Center(
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 350),
            curve: kLuxuryCurve,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: selected
                    ? const [Color(0xFF4A5058), Color(0xFF7B8189)]
                    : const [Color(0xFFE6E8EB), Color(0xFFB2B6BC)],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 350),
              curve: kLuxuryCurve,
              style: TextStyle(
                fontSize: 12,
                letterSpacing: 1.2,
                color: selected ? Colors.white : AppColors.ink,
              ),
              child: Text(label),
            ),
          ),
        ),
      );
}

ThemeData buildTheme() {
  final sharp = RoundedRectangleBorder(borderRadius: BorderRadius.circular(4));
  OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: BorderSide(color: c, width: w),
      );

  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.outline,
      brightness: Brightness.light,
    ).copyWith(
      primary: AppColors.ink,
      onPrimary: Colors.white,
      secondary: AppColors.gold,
      surface: AppColors.paper,
    ),
    scaffoldBackgroundColor: Colors.transparent,
    pageTransitionsTheme: const PageTransitionsTheme(builders: {
      TargetPlatform.android: _SkyTransitions(),
      TargetPlatform.iOS: _SkyTransitions(),
      TargetPlatform.windows: _SkyTransitions(),
      TargetPlatform.macOS: _SkyTransitions(),
      TargetPlatform.linux: _SkyTransitions(),
    }),
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.mist, // same off-white as the watch cards
      surfaceTintColor: Colors.transparent,
      foregroundColor: AppColors.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      shape: const Border(bottom: BorderSide(color: AppColors.line)),
      titleTextStyle: GoogleFonts.playfairDisplay(
        color: AppColors.ink,
        fontSize: 22,
        fontWeight: FontWeight.w500,
        letterSpacing: 1,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.35),
      border: border(AppColors.outline),
      enabledBorder: border(AppColors.outline),
      focusedBorder: border(AppColors.ink, 1.5),
      errorBorder: border(Colors.red.shade700),
      focusedErrorBorder: border(Colors.red.shade700, 1.5),
      labelStyle: const TextStyle(color: AppColors.muted),
      floatingLabelStyle: const TextStyle(color: AppColors.ink),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.ink,
        foregroundColor: Colors.white,
        shape: sharp,
        minimumSize: const Size.fromHeight(50),
        textStyle: const TextStyle(
            fontWeight: FontWeight.w600, letterSpacing: 2, fontSize: 13),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: AppColors.ink),
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
        side: const BorderSide(color: Color(0xFFB2B6BC)),
      ),
      backgroundColor: const Color(0xFFD4D7DB),
      selectedColor: const Color(0xFF565B62),
      checkmarkColor: Colors.white,
      labelStyle: const TextStyle(fontSize: 12, letterSpacing: 1.2),
      showCheckmark: false,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.ink,
      shape: sharp,
    ),
    progressIndicatorTheme:
        const ProgressIndicatorThemeData(color: AppColors.gold),
  );
}

class Watch {
  final String id;
  final String brand;
  final String name;
  final int price; // in PHP

  final String imageUrl;
  final String description;
  final Map<String, String> specs;

  const Watch({
    required this.id,
    required this.brand,
    required this.name,
    required this.price,
    required this.imageUrl,
    this.description = '',
    this.specs = const {},
  });
}

String peso(int v) {
  final s = v.toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return '₱$b';
}

const builtInWatches = <Watch>[
  Watch(
    id: 'c1',
    brand: 'Casio',
    name: 'Collection MTP-1302D Blue Dial',
    price: 3995,
    imageUrl: 'assets/images/casio_mtp1302_blue.png',
    description:
        'A slim steel dress-casual classic with a dark blue dial, fluted bezel and date window at 3 o\'clock. Easy to wear to the office or on the weekend.',
    specs: {
      'Model': 'MTP-1302PD-2AVEF',
      'Case': '38.5 mm round, stainless steel',
      'Movement': 'Quartz',
      'Water resistance': '50 m (5 ATM)',
      'Strap': 'Stainless steel bracelet',
      'Dial': 'Dark blue, with date window',
    },
  ),
  Watch(
    id: 'c2',
    brand: 'Casio',
    name: 'Collection MTP-1302D Green Dial',
    price: 3995,
    imageUrl: 'assets/images/casio_mtp1302_green.png',
    description:
        'The same MTP-1302D case and steel bracelet with a green dial. A fresh alternative to the usual black and blue.',
    specs: {
      'Model': 'MTP-1302D-3AV',
      'Case': '38.5 mm round, stainless steel',
      'Movement': 'Quartz',
      'Water resistance': '50 m (5 ATM)',
      'Strap': 'Stainless steel bracelet',
      'Dial': 'Green, with date window',
    },
  ),
  Watch(
    id: 'c3',
    brand: 'Casio',
    name: 'Collection MTP-1302D White Dial',
    price: 3995,
    imageUrl: 'assets/images/casio_mtp1302_white.png',
    description:
        'A clean white dial with large numerals and a date window at 3 o\'clock. Bright, simple and very readable.',
    specs: {
      'Model': 'MTP-1302D-7B',
      'Case': '38.5 mm round, stainless steel',
      'Movement': 'Quartz',
      'Water resistance': '50 m (5 ATM)',
      'Strap': 'Stainless steel bracelet',
      'Dial': 'White, with date window',
    },
  ),
  Watch(
    id: 'c4',
    brand: 'Casio',
    name: 'Collection MTP-1302D Black Dial',
    price: 3995,
    imageUrl: 'assets/images/casio_mtp1302_black.png',
    description:
        'A black dial on a stainless steel bracelet. Understated, sharp and goes with almost any outfit.',
    specs: {
      'Model': 'MTP-1302D-1A1',
      'Case': '38.5 mm round, stainless steel',
      'Movement': 'Quartz',
      'Water resistance': '50 m (5 ATM)',
      'Strap': 'Stainless steel bracelet',
      'Dial': 'Black, with date window',
    },
  ),
  Watch(
    id: 'c5',
    brand: 'Casio',
    name: 'Collection MTP-1302D Black Dial II',
    price: 3995,
    imageUrl: 'assets/images/casio_mtp1302_black2.png',
    description:
        'Another black-dial option from the MTP-1302D series, with the same slim case, quartz movement and steel bracelet.',
    specs: {
      'Model': 'MTP-1302D-1A2',
      'Case': '38.5 mm round, stainless steel',
      'Movement': 'Quartz',
      'Water resistance': '50 m (5 ATM)',
      'Strap': 'Stainless steel bracelet',
      'Dial': 'Black, with date window',
    },
  ),
  Watch(
    id: 'p1',
    brand: 'Patek Philippe',
    name: '5320G-011 Perpetual Calendar White Gold',
    price: 7128000,
    imageUrl: 'assets/images/patek_5320g_011.png',
    description:
        'A vintage-inspired perpetual calendar in white gold with a rose-gilt opaline dial. Day and month sit in twin apertures at 12, with a date hand circling the moon phase at 6.',
    specs: {
      'Reference': '5320G-011',
      'Case': 'White gold, 40 mm x 11.13 mm',
      'Movement': 'Self-winding, caliber 26-330 S Q',
      'Water resistance': '30 m',
      'Strap': 'Chocolate brown alligator leather',
      'Dial': 'Rose-gilt opaline',
    },
  ),
  Watch(
    id: 'p2',
    brand: 'Patek Philippe',
    name: '5327G-001 Perpetual Calendar White Gold',
    price: 6877000,
    imageUrl: 'assets/images/patek_5327g_001.png',
    description:
        'An ultra-thin perpetual calendar in a Calatrava-style case with scalloped lugs. The royal blue sunburst dial carries applied Breguet numerals.',
    specs: {
      'Reference': '5327G-001',
      'Case': 'White gold, 39 mm x 9.71 mm',
      'Movement': 'Self-winding, caliber 240 Q',
      'Water resistance': '30 m',
      'Strap': 'Navy blue alligator leather',
      'Dial': 'Sunburst blue',
    },
  ),
  Watch(
    id: 'p3',
    brand: 'Patek Philippe',
    name: '5327R-001 Perpetual Calendar Rose Gold',
    price: 6877000,
    imageUrl: 'assets/images/patek_5327r_001.png',
    description:
        'The same slim perpetual calendar in rose gold, with a lacquered ivory dial and hollowed counters that give the face a layered look.',
    specs: {
      'Reference': '5327R-001',
      'Case': 'Rose gold, 39 mm x 9.71 mm',
      'Movement': 'Self-winding, caliber 240 Q',
      'Water resistance': '30 m',
      'Strap': 'Dark brown alligator leather',
      'Dial': 'Lacquered ivory',
    },
  ),
  Watch(
    id: 'p4',
    brand: 'Patek Philippe',
    name: '5271P-010 Perpetual Calendar Chronograph Platinum',
    price: 19342000,
    imageUrl: 'assets/images/patek_5271p_010.png',
    description:
        'A platinum perpetual calendar chronograph with baguette-cut diamonds on the bezel and lugs, paired with a lacquered black dial. Hand-wound.',
    specs: {
      'Reference': '5271P-010',
      'Case': 'Platinum, 41 mm x 12.7 mm, 81 baguette diamonds',
      'Movement': 'Manual winding, caliber CH 29-535 PS Q',
      'Water resistance': '30 m',
      'Strap': 'Black alligator leather',
      'Dial': 'Lacquered black',
    },
  ),
  Watch(
    id: 'p5',
    brand: 'Patek Philippe',
    name: '5303R-001 Minute Repeater Tourbillon Rose Gold',
    price: 51581000,
    imageUrl: 'assets/images/patek_5303r_001.png',
    description:
        'A minute repeater with tourbillon and an open-worked dial, so you can watch the hammers, gongs and tourbillon carriage at work. Rose gold case with engraved white gold inlays.',
    specs: {
      'Reference': '5303R-001',
      'Case': 'Rose gold, 42 mm x 12.13 mm',
      'Movement': 'Manual winding, caliber R TO 27 PS',
      'Water resistance': 'Not water-resistant',
      'Strap': 'Black alligator leather',
      'Dial': 'Open sapphire, black hour circle',
    },
  ),
  Watch(
    id: 'p6',
    brand: 'Patek Philippe',
    name: '5370R-001 Split-Seconds Chronograph Rose Gold',
    price: 18159000,
    imageUrl: 'assets/images/patek_5370r_001.png',
    description:
        'A split-seconds chronograph in rose gold with a hand-made Grand Feu enamel dial in brown and beige. Manual winding.',
    specs: {
      'Reference': '5370R-001',
      'Case': 'Rose gold, 41 mm x 13.56 mm',
      'Movement': 'Manual winding, caliber CHR 29-535 PS',
      'Water resistance': '30 m',
      'Strap': 'Dark chestnut alligator leather',
      'Dial': 'Grand Feu enamel, brown and beige',
    },
  ),
  Watch(
    id: 'p7',
    brand: 'Patek Philippe',
    name: '5531G-001 World Time Minute Repeater White Gold',
    price: 47074000,
    imageUrl: 'assets/images/patek_5531g_001.png',
    description:
        'A white gold world-time minute repeater that always chimes local time. The dial center shows a hand-made cloisonne enamel scene of a Lake Geneva steamboat.',
    specs: {
      'Reference': '5531G-001',
      'Case': 'White gold, 40.2 mm x 11.49 mm',
      'Movement': 'Self-winding, caliber R 27 HU',
      'Water resistance': 'Not water-resistant',
      'Strap': 'Blue-green alligator leather',
      'Dial': 'Cloisonne enamel center',
    },
  ),
  Watch(
    id: 'p8',
    brand: 'Patek Philippe',
    name: '6104P-010 Celestial Platinum',
    price: 33688000,
    imageUrl: 'assets/images/patek_6104p_010.png',
    description:
        'A platinum Celestial that shows the night sky as seen from Geneva, with the moon phase and orbit. The bezel and clasp are set with baguette-cut diamonds.',
    specs: {
      'Reference': '6104P-010',
      'Case': 'Platinum, 44 mm x 11.33 mm, 60 baguette diamonds',
      'Movement': 'Self-winding, caliber 240 LU CL C',
      'Water resistance': '30 m',
      'Strap': 'Navy blue alligator leather',
      'Dial': 'Sapphire sky chart',
    },
  ),
  Watch(
    id: 'p9',
    brand: 'Patek Philippe',
    name: '6104R-001 Celestial Rose Gold',
    price: 30367000,
    imageUrl: 'assets/images/patek_6104r_001.png',
    description:
        'The Celestial astronomical watch in rose gold, with a baguette-diamond bezel and a black sky chart dial.',
    specs: {
      'Reference': '6104R-001',
      'Case': 'Rose gold, 44 mm x 11.33 mm, 60 baguette diamonds',
      'Movement': 'Self-winding, caliber 240 LU CL C',
      'Water resistance': '30 m',
      'Strap': 'Black alligator leather',
      'Dial': 'Black sapphire sky chart',
    },
  ),
  Watch(
    id: 'p10',
    brand: 'Patek Philippe',
    name: '5160/500R-001 Retrograde Perpetual Calendar Rose Gold',
    price: 13867000,
    imageUrl: 'assets/images/patek_5160_500r_001.png',
    description:
        'A retrograde perpetual calendar in an Officer-style case with a hinged back cover. The rose gold case, crown, lugs and clasp are fully hand-engraved.',
    specs: {
      'Reference': '5160/500R-001',
      'Case': 'Rose gold, 38 mm x 11.81 mm, hand-engraved',
      'Movement': 'Self-winding, caliber 26-330 S QR',
      'Water resistance': '30 m',
      'Strap': 'Patinated brown alligator leather',
      'Dial': 'Silvery opaline',
    },
  ),
  Watch(
    id: 'c11',
    brand: 'Casio',
    name: 'Beside BMS-105D-1A',
    price: 10030,
    imageUrl: 'assets/images/casio_bms105d_1a.png',
    description:
        'A slim rectangular dress watch from the Casio Beside line, with a black dial, Roman numeral and baton indexes, and a scratch-resistant sapphire crystal. Solid stainless steel band with a one-touch 3-fold clasp.',
    specs: {
      'Model': 'BMS-105D-1A',
      'Case': 'Stainless steel, 42.5 mm x 28.5 mm x 6.7 mm, sapphire crystal',
      'Movement':
          'Quartz, 3-hand analog, accuracy +/-20 sec per month (SR621SW battery, about 3 years)',
      'Water resistance': '50 m (5 bar)',
      'Strap': 'Solid stainless steel band, one-touch 3-fold clasp',
      'Dial': 'Black, Roman numeral and baton indexes',
      'Weight': '104 g',
    },
  ),
  Watch(
    id: 'c12',
    brand: 'Casio',
    name: 'Beside BMS-105D-7A',
    price: 10030,
    imageUrl: 'assets/images/casio_bms105d_7a.png',
    description:
        'The same slim rectangular Beside case with a bright white dial, Roman numeral and baton indexes, and a sapphire crystal. Solid stainless steel band with a one-touch 3-fold clasp.',
    specs: {
      'Model': 'BMS-105D-7A',
      'Case': 'Stainless steel, 42.5 mm x 28.5 mm x 6.7 mm, sapphire crystal',
      'Movement':
          'Quartz, 3-hand analog, accuracy +/-20 sec per month (SR621SW battery, about 3 years)',
      'Water resistance': '50 m (5 bar)',
      'Strap': 'Solid stainless steel band, one-touch 3-fold clasp',
      'Dial': 'White, Roman numeral and baton indexes',
      'Weight': '104 g',
    },
  ),
  Watch(
    id: 'c13',
    brand: 'Casio',
    name: 'Beside BMS-105L-1A',
    price: 9030,
    imageUrl: 'assets/images/casio_bms105l_1a.png',
    description:
        'A black-dial rectangular dress watch on a genuine leather band. Sapphire crystal, simple three-hand design and 50 m water resistance, at only 39 g.',
    specs: {
      'Model': 'BMS-105L-1A',
      'Case': 'Stainless steel, 42.5 mm x 28.5 mm x 6.7 mm, sapphire crystal',
      'Movement':
          'Quartz, 3-hand analog, accuracy +/-20 sec per month (SR621SW battery, about 3 years)',
      'Water resistance': '50 m (5 bar)',
      'Strap': 'Genuine leather band',
      'Dial': 'Black, Roman numeral and baton indexes',
      'Weight': '39 g',
    },
  ),
  Watch(
    id: 'c14',
    brand: 'Casio',
    name: 'Beside BMS-105L-7A',
    price: 9030,
    imageUrl: 'assets/images/casio_bms105l_7a.png',
    description:
        'A white-dial rectangular dress watch on a genuine leather band. Understated and formal, with a scratch-resistant sapphire crystal and a light 39 g build.',
    specs: {
      'Model': 'BMS-105L-7A',
      'Case': 'Stainless steel, 42.5 mm x 28.5 mm x 6.7 mm, sapphire crystal',
      'Movement':
          'Quartz, 3-hand analog, accuracy +/-20 sec per month (SR621SW battery, about 3 years)',
      'Water resistance': '50 m (5 bar)',
      'Strap': 'Genuine leather band',
      'Dial': 'White, Roman numeral and baton indexes',
      'Weight': '39 g',
    },
  ),
  Watch(
    id: 'c15',
    brand: 'Casio',
    name: 'Collection MTP-1183Q-7A',
    price: 3495,
    imageUrl: 'assets/images/casio_mtp1183q_7a.png',
    description:
        'A simple three-hand analog watch with a gold-tone case, genuine leather band and a date display at 3 o\'clock. Water resistant for everyday use.',
    specs: {
      'Model': 'MTP-1183Q-7A',
      'Case': '42 mm x 38.5 mm x 8.7 mm, gold tone',
      'Movement': 'Quartz, 3-hand analog, accuracy +/-20 sec per month',
      'Battery': 'SR626SW, about 2 years',
      'Water resistance': 'Water resistant',
      'Strap': 'Genuine leather band',
    },
  ),
  Watch(
    id: 'r1',
    brand: 'Richard Mille',
    name: 'RM 65-01 Automatic Winding Split-Seconds Chronograph',
    price: 17100000,
    imageUrl: 'assets/images/rm_65_01.png',
    description:
        'An automatic split-seconds chronograph in a tonneau case, with the movement visible through the back. A complication flagship of the Richard Mille collection.',
    specs: {
      'Model': 'RM 65-01',
      'Movement': 'Automatic winding, split-seconds chronograph',
      'Case': 'Tonneau, 44.5 mm x 49.94 mm x 16.1 mm',
    },
  ),
  Watch(
    id: 'r2',
    brand: 'Richard Mille',
    name: 'RM 65-01 Split-Seconds Chronograph McLaren W1',
    // PLACEHOLDER PRICE: no public price found. Set your real price.
    price: 19950000,
    imageUrl: 'assets/images/rm_65_01_mclaren_w1.png',
    description:
        'The RM 65-01 automatic split-seconds chronograph in the McLaren W1 edition, recognizable by its orange chronograph pusher.',
    specs: {
      'Model': 'RM 65-01 McLaren W1',
      'Movement': 'Automatic winding, split-seconds chronograph',
      'Case': 'Tonneau, 44.5 mm x 49.94 mm x 16.1 mm',
    },
  ),
  Watch(
    id: 'r3',
    brand: 'Richard Mille',
    name: 'RM 74-01 Automatic Winding Tourbillon',
    // PLACEHOLDER PRICE: no public price found. Set your real price.
    price: 25650000,
    imageUrl: 'assets/images/rm_74_01.png',
    description:
        'An automatic winding tourbillon in a dark tonneau case with a red-accented strap, showing the tourbillon through the caseback.',
    specs: {
      'Model': 'RM 74-01',
      'Movement': 'Automatic winding, tourbillon',
    },
  ),
  Watch(
    id: 'r4',
    brand: 'Richard Mille',
    name: 'RM 74-02 Automatic Winding Tourbillon',
    // PLACEHOLDER PRICE: no public price found. Set your real price.
    price: 28500000,
    imageUrl: 'assets/images/rm_74_02.png',
    description:
        'An automatic winding tourbillon with a rose gold and white case and a leather-lined strap.',
    specs: {
      'Model': 'RM 74-02',
      'Movement': 'Automatic winding, tourbillon',
    },
  ),
  Watch(
    id: 'r5',
    brand: 'Richard Mille',
    name: 'RM HJ-02 Automatic Winding Tourbillon',
    // PLACEHOLDER PRICE: no public price found. Set your real price.
    price: 34200000,
    imageUrl: 'assets/images/rm_hj_02.png',
    description:
        'A jewel-like automatic winding tourbillon with a pastel mint strap and a colorful skeletonized movement.',
    specs: {
      'Model': 'RM HJ-02',
      'Movement': 'Automatic winding, tourbillon',
    },
  ),
  Watch(
    id: 'r6',
    brand: 'Richard Mille',
    name: 'RM 66 Flying Tourbillon',
    // PLACEHOLDER PRICE: no public price found. Set your real price.
    price: 22800000,
    imageUrl: 'assets/images/rm_66.png',
    description:
        'A flying tourbillon in a black tonneau case with a skeletonized, gold-toned movement that is visible from the back.',
    specs: {
      'Model': 'RM 66',
      'Movement': 'Flying tourbillon',
    },
  ),
  Watch(
    id: 'r7',
    brand: 'Richard Mille',
    name: 'RM 67-01 Automatic Winding Extra Flat',
    price: 6840000,
    imageUrl: 'assets/images/rm_67_01.png',
    description:
        'An extra-flat automatic watch with a titanium tonneau case. One of the most accessible Richard Mille models in the current collection.',
    specs: {
      'Model': 'RM 67-01',
      'Movement': 'Automatic winding, extra flat',
    },
  ),
  Watch(
    id: 'r8',
    brand: 'Richard Mille',
    name: 'RM 67-02 Automatic Winding Extra Flat',
    price: 8265000,
    imageUrl: 'assets/images/rm_67_02.png',
    description:
        'The slim automatic RM 67-02 with a carbon-look case, only 7.8 mm thick, and a colored strap lining.',
    specs: {
      'Model': 'RM 67-02',
      'Movement': 'Automatic winding, extra flat',
      'Case': 'Tonneau, 38.7 mm x 47.52 mm x 7.8 mm',
    },
  ),
  Watch(
    id: 'r9',
    brand: 'Richard Mille',
    name: 'RM 72-01 Automatic Winding Lifestyle Flyback Chronograph',
    price: 18810000,
    imageUrl: 'assets/images/rm_72_01.png',
    description:
        'A lifestyle flyback chronograph with an automatic movement, in a compact tonneau case with rose gold details.',
    specs: {
      'Model': 'RM 72-01',
      'Movement': 'Automatic winding, flyback chronograph',
      'Case': 'Tonneau, 38.4 mm x 47.34 mm x 11.68 mm',
    },
  ),
  Watch(
    id: 'r10',
    brand: 'Richard Mille',
    name: 'RM 75-01 Manual Winding Flying Tourbillon Sapphire',
    // PLACEHOLDER PRICE: no public price found. Set your real price.
    price: 79800000,
    imageUrl: 'assets/images/rm_75_01_sapphire.png',
    description:
        'A limited edition with a case cut entirely from solid blue sapphire, showing a manual winding flying tourbillon and a flying barrel from every angle.',
    specs: {
      'Model': 'RM 75-01 Sapphire',
      'Movement':
          'Manual winding flying tourbillon, hours and minutes (caliber RM75-01)',
      'Power reserve': 'About 65 hours (+/- 10%)',
      'Frequency': '3 Hz (21,600 vph), 18 jewels',
      'Case': 'Bezel, caseband and caseback in solid sapphire',
      'Water resistance': '30 m',
      'Edition': 'Limited edition',
    },
  ),
  Watch(
    id: 'r11',
    brand: 'Richard Mille',
    name: 'RM 64-01 Manual Winding Tourbillon Colnago',
    // PLACEHOLDER PRICE: no public price found. Set your real price.
    price: 37050000,
    imageUrl: 'assets/images/rm_64_01_colnago.png',
    description:
        'A manual winding tourbillon in the Colnago edition, with a white case and blue accents.',
    specs: {
      'Model': 'RM 64-01 Colnago',
      'Movement': 'Manual winding, tourbillon',
    },
  ),
  Watch(
    id: 'r12',
    brand: 'Richard Mille',
    name: 'RM UP-01 Ferrari Manual Winding Ultraflat',
    price: 107616000,
    imageUrl: 'assets/images/rm_up_01_ferrari.png',
    description:
        'The ultraflat RM UP-01 Ferrari, made as one of the thinnest mechanical watches ever built. One of the most expensive Richard Mille models.',
    specs: {
      'Model': 'RM UP-01 Ferrari',
      'Movement': 'Manual winding, ultraflat',
      'Thickness': '1.75 mm',
      'Edition': 'Limited edition',
    },
  ),
  Watch(
    id: 'l1',
    brand: 'Rolex',
    name: 'Day-Date 40 White Gold Silver Stripe Dial 228239',
    // PLACEHOLDER PRICE: estimate only. Set your real price.
    price: 2565000,
    imageUrl: 'assets/images/rolex_day_date_40_228239.png',
    description:
        'The classic Day-Date in 18 ct white gold, with a fluted bezel, a silver dial with a vertical stripe motif, and the President bracelet. It shows the day written out in full at 12.',
    specs: {
      'Reference': '228239',
      'Case': 'Oyster, 40 mm, 18 ct white gold, fluted bezel',
      'Movement': 'Automatic, Calibre 3255, about 70 hours',
      'Water resistance': '100 m',
      'Bracelet': 'President, 18 ct white gold',
      'Dial': 'Silver, stripe motif',
    },
  ),
  Watch(
    id: 'l2',
    brand: 'Rolex',
    name: 'Datejust 26 Diamond Dial 1999 69174',
    // PLACEHOLDER PRICE: estimate only. Set your real price.
    price: 480000,
    imageUrl: 'assets/images/rolex_datejust_26_69174.png',
    description:
        'A 1999 Oyster Perpetual Datejust 26 with a silver dial set with diamond hour markers, a white gold fluted bezel and a Jubilee bracelet. A pre-owned piece.',
    specs: {
      'Reference': '69174 (1999)',
      'Case': 'Oyster, 26 mm, stainless steel, white gold fluted bezel',
      'Movement': 'Automatic, Calibre 2135, about 40 hours',
      'Water resistance': 'Water resistant',
      'Bracelet': 'Jubilee, stainless steel',
      'Dial': 'Silver, diamond hour markers',
    },
  ),
  Watch(
    id: 'l3',
    brand: 'Rolex',
    name: 'Submariner Date 41 Black 126610LN',
    price: 912000,
    imageUrl: 'assets/images/rolex_submariner_126610ln.png',
    description:
        'The current black Submariner Date: 41 mm Oystersteel case, black Cerachrom bezel, a Cyclops date at 3 and the Glidelock clasp for easy sizing.',
    specs: {
      'Reference': '126610LN',
      'Case': 'Oyster, 41 mm, Oystersteel, black Cerachrom bezel',
      'Movement': 'Automatic, Calibre 3235, 70 hours',
      'Water resistance': '300 m',
      'Bracelet': 'Oyster, with Glidelock',
      'Dial': 'Black, date at 3',
    },
  ),
  Watch(
    id: 'l4',
    brand: 'Rolex',
    name: 'Submariner Date Green Hulk 116610LV',
    price: 1026000,
    imageUrl: 'assets/images/rolex_submariner_hulk_116610lv.png',
    description:
        'The previous-generation Submariner Date nicknamed the Hulk, with a green dial and a green Cerachrom bezel. Produced from 2010 to 2020.',
    specs: {
      'Reference': '116610LV',
      'Case': 'Oyster, 40 mm, Oystersteel, green Cerachrom bezel',
      'Movement': 'Automatic, Calibre 3135, about 48 hours',
      'Water resistance': '300 m',
      'Bracelet': 'Oyster',
      'Dial': 'Green, date at 3',
    },
  ),
  Watch(
    id: 'l5',
    brand: 'Rolex',
    name: 'Oyster Perpetual 36 Black Dial 126000',
    price: 428000,
    imageUrl: 'assets/images/rolex_oyster_perpetual_36_126000.png',
    description:
        'A simple three-hand Oyster Perpetual 36 with a bright black dial, a smooth domed bezel and an Oyster bracelet. The easiest way into a modern Rolex.',
    specs: {
      'Reference': '126000',
      'Case': 'Oyster, 36 mm, Oystersteel',
      'Movement': 'Automatic, Calibre 3230, 70 hours',
      'Water resistance': '100 m',
      'Bracelet': 'Oyster',
      'Dial': 'Bright black',
    },
  ),
];

// ============================================================
// LIVE CATALOG (built-in watches + watches added in Firestore)
// ============================================================

/// All watches shown in the app. Built-in ones come from the list above;
/// new ones come from the Firestore "watches" collection, so adding a
/// document there shows up in the app without installing a new APK.
List<Watch> get sampleWatches => Catalog.instance.all;

class Catalog extends ChangeNotifier {
  Catalog._();
  static final Catalog instance = Catalog._();

  List<Watch> _all = List.of(builtInWatches);
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;

  List<Watch> get all => _all;

  /// Call once in main(), after Firebase.initializeApp.
  void init() {
    _sub ??=
        FirebaseFirestore.instance.collection('watches').snapshots().listen(
      (snap) {
        debugPrint('Catalog: ${snap.docs.length} docs from Firestore');
        final builtInIds = {for (final w in builtInWatches) w.id};
        final extra = <Watch>[];
        for (final d in snap.docs) {
          if (builtInIds.contains(d.id)) continue; // built-ins stay as coded
          final w = _fromDoc(d.id, d.data());
          if (w == null) {
            debugPrint('Catalog: SKIPPED ${d.id} -> ${d.data()}');
          } else {
            extra.add(w);
          }
        }
        _all = [...builtInWatches, ...extra];
        notifyListeners();
      },
      onError: (e) => debugPrint('Catalog error: $e'),
    );
  }

  // Field names are matched forgivingly: "imageUrl:", " ImageURL " and
  // "imageurl" all count as imageUrl.
  static String _key(String k) =>
      k.trim().replaceAll(RegExp(r'[:\s]+$'), '').toLowerCase();

  // "casio" -> "Casio", "richard mille" -> "Richard Mille"
  static String _title(String s) => s
      .trim()
      .split(RegExp(r'\s+'))
      .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1))
      .join(' ');

  /// A Firestore document needs at least: brand (string), name (string),
  /// price (number). Anything else is optional.
  static Watch? _fromDoc(String id, Map<String, dynamic> raw) {
    final m = <String, dynamic>{
      for (final e in raw.entries) _key(e.key): e.value,
    };

    final brand = m['brand'];
    final name = m['name'];
    final priceRaw = m['price'];
    final price = priceRaw is num
        ? priceRaw
        : (priceRaw is String ? num.tryParse(priceRaw.trim()) : null);
    if (brand is! String || name is! String || price == null) return null;

    final specs = <String, String>{};
    final rawSpecs = m['specs'];
    if (rawSpecs is Map) {
      rawSpecs.forEach((k, v) => specs[k.toString()] = v.toString());
    }

    return Watch(
      id: id,
      brand: _title(brand),
      name: name.trim(),
      price: price.toInt(),
      imageUrl: (m['imageurl'] ?? '').toString().trim(),
      description: (m['description'] ?? '').toString(),
      specs: specs,
    );
  }
}

const kSizes = ['S', 'M', 'L'];
const kSizeGuide = {
  'S': 'Wrist 14 - 16 cm',
  'M': 'Wrist 16 - 18 cm',
  'L': 'Wrist 18 - 20 cm',
};

Future<String?> pickSize(BuildContext context, Watch w) =>
    showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.paper,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(12))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Select a size',
                  style: GoogleFonts.playfairDisplay(
                      fontSize: 22, fontWeight: FontWeight.w500)),
              const SizedBox(height: 4),
              Text(w.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, color: AppColors.muted)),
              const SizedBox(height: 12),
              for (final s in kSizes)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Size $s',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(kSizeGuide[s]!),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.pop(ctx, s),
                ),
            ],
          ),
        ),
      ),
    );

/// Fades and glides up after `delay`
class Reveal extends StatefulWidget {
  final Widget child;
  final Duration delay;
  final Offset offset;
  const Reveal({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.offset = const Offset(0, 0.10),
  });

  @override
  State<Reveal> createState() => _RevealState();
}

class _RevealState extends State<Reveal> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1000));
  late final Animation<double> _a =
      CurvedAnimation(parent: _c, curve: kLuxuryCurve);
  // Fade is a little gentler than the slide so it feels silky
  late final Animation<double> _fade =
      CurvedAnimation(parent: _c, curve: Curves.easeOutQuad);
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer(widget.delay, () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: _fade,
        child: SlideTransition(
          position: Tween<Offset>(begin: widget.offset, end: Offset.zero)
              .animate(_a),
          child: widget.child,
        ),
      );
}

class WatchImage extends StatelessWidget {
  final String url;
  const WatchImage({super.key, required this.url});

  @override
  Widget build(BuildContext context) {
    const fallback = Center(
        child: Icon(Icons.watch_outlined, size: 40, color: AppColors.muted));

    final src = url.trim();
    if (src.isEmpty) return fallback;

    Widget fadeIn(BuildContext _, Widget child, int? frame, bool sync) {
      if (sync) return child;
      return AnimatedOpacity(
        opacity: frame == null ? 0 : 1,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOut,
        child: child,
      );
    }

    // Shows the real reason in the console when a picture fails to load.
    Widget onError(BuildContext _, Object e, StackTrace? __) {
      debugPrint('Image error for "$src": $e');
      return fallback;
    }

    if (src.startsWith('http')) {
      return Image.network(
        src,
        fit: BoxFit.contain,
        // On web, pictures from other websites often fail because of CORS.
        // This lets the browser load them as a normal <img> instead.
        webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
        frameBuilder: fadeIn,
        loadingBuilder: (_, child, p) => p == null
            ? child
            : const Center(
                child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2))),
        errorBuilder: onError,
      );
    }
    return Image.asset(
      src,
      fit: BoxFit.contain,
      frameBuilder: fadeIn,
      errorBuilder: onError,
    );
  }
}

void toast(BuildContext c, String m) =>
    ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(m)));

String authError(FirebaseAuthException e) {
  switch (e.code) {
    case 'email-already-in-use':
      return 'This email is already registered.';
    case 'invalid-credential':
    case 'user-not-found':
    case 'wrong-password':
      return 'Incorrect email or password.';
    case 'invalid-email':
      return 'Invalid email.';
    case 'weak-password':
      return 'Password is too weak.';
    case 'too-many-requests':
      return 'Too many attempts. Please try again later.';
    case 'network-request-failed':
      return 'No internet connection.';
    default:
      return 'Error: ${e.code}';
  }
}

class AuthPage extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const AuthPage({super.key, required this.title, required this.children});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(title.toUpperCase())),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Reveal(
                    child: Text(
                      kAppName,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.playfairDisplay(
                          fontSize: 32,
                          fontWeight: FontWeight.w400,
                          letterSpacing: 1,
                          color: AppColors.ink),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Reveal(
                    delay: Duration(milliseconds: 150),
                    child: Text(
                      kTagline,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 12,
                          letterSpacing: 1.5,
                          color: AppColors.muted),
                    ),
                  ),
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 40),
                    duration: const Duration(milliseconds: 1100),
                    curve: kLuxuryCurve,
                    builder: (_, w, __) => Align(
                      child: Container(
                        height: 2,
                        width: w,
                        color: AppColors.gold,
                        margin: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                  // The form fades in after the gold line draws
                  Reveal(
                    delay: const Duration(milliseconds: 300),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: children,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}

Widget field(String label, TextEditingController c,
        {String? Function(String?)? validator, TextInputType? keyboard}) =>
    Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: c,
        validator: validator,
        keyboardType: keyboard,
        decoration: InputDecoration(labelText: label),
      ),
    );

class PasswordField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String? Function(String?)? validator;
  const PasswordField(
      {super.key,
      required this.controller,
      this.label = 'Password',
      this.validator});
  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _hide = true;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: TextFormField(
          controller: widget.controller,
          obscureText: _hide,
          validator: widget.validator,
          decoration: InputDecoration(
            labelText: widget.label,
            suffixIcon: IconButton(
              icon: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                transitionBuilder: (c, a) =>
                    ScaleTransition(scale: a, child: c),
                child: Icon(
                  _hide ? Icons.visibility_off : Icons.visibility,
                  key: ValueKey(_hide),
                ),
              ),
              onPressed: () => setState(() => _hide = !_hide),
            ),
          ),
        ),
      );
}

Widget button(String text, bool busy, VoidCallback onTap) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: FilledButton(
        onPressed: busy ? null : onTap,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: busy
              ? const SizedBox(
                  key: ValueKey('busy'),
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : Text(text.toUpperCase(), key: const ValueKey('label')),
        ),
      ),
    );

const passwordHint =
    'Password: at least 8 characters, with an uppercase letter, a lowercase letter, a number, and a special character.';

// ============================================================
// DASHBOARD
// ============================================================

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String _brand = 'All';
  String _query = '';
  String _sort = 'Featured';

  static const _sorts = [
    'Featured',
    'Price: Low to High',
    'Price: High to Low',
    'Name: A to Z',
  ];

  // The price limits follow the live catalog, so watches added in
  // Firestore are always inside the slider range.
  int get _lo =>
      (sampleWatches.map((w) => w.price).reduce(math.min) / 1000).floor() *
      1000;
  int get _hi =>
      (sampleWatches.map((w) => w.price).reduce(math.max) / 1000).ceil() *
      1000;

  // null = the person has not touched the price filter
  RangeValues? _picked;

  RangeValues get _range {
    final lo = _lo.toDouble();
    final hi = _hi.toDouble();
    final p = _picked;
    if (p == null) return RangeValues(lo, hi);
    final s = math.min(math.max(p.start, lo), hi);
    final e = math.max(math.min(p.end, hi), s);
    return RangeValues(s, e);
  }

  bool get _priceFiltered =>
      _picked != null && (_range.start > _lo || _range.end < _hi);

  bool get _filtersActive => _sort != 'Featured' || _priceFiltered;

  // Refresh the list when a watch is added / removed in Firestore
  void _onCatalog() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    Catalog.instance.addListener(_onCatalog);
  }

  @override
  void dispose() {
    Catalog.instance.removeListener(_onCatalog);
    super.dispose();
  }

  // Address is preloaded before the button is tapped
  Future<ShippingAddress?> _addrFuture = ShippingAddress.load();

  List<String> get _brands =>
      ['All', ...{for (final w in sampleWatches) w.brand}];

  List<Watch> get _filtered {
    final q = _query.trim().toLowerCase();
    final range = _range;
    final list = sampleWatches.where((w) {
      final okBrand = _brand == 'All' || w.brand == _brand;
      final okQuery = q.isEmpty ||
          w.name.toLowerCase().contains(q) ||
          w.brand.toLowerCase().contains(q);
      final okPrice =
          !_priceFiltered || (w.price >= range.start && w.price <= range.end);
      return okBrand && okQuery && okPrice;
    }).toList();

    switch (_sort) {
      case 'Price: Low to High':
        list.sort((a, b) => a.price.compareTo(b.price));
        break;
      case 'Price: High to Low':
        list.sort((a, b) => b.price.compareTo(a.price));
        break;
      case 'Name: A to Z':
        list.sort((a, b) => a.name.compareTo(b.name));
        break;
    }
    return list;
  }

  // The price slider is logarithmic so both cheap and very expensive
  // watches stay easy to filter.
  double _toLog(double price) => math.log(price) / math.ln10;

  double _fromLog(double v) {
    if (v <= _toLog(_lo.toDouble()) + 0.001) return _lo.toDouble();
    if (v >= _toLog(_hi.toDouble()) - 0.001) return _hi.toDouble();
    final p = math.pow(10, v).toDouble();
    final step = p < 100000
        ? 500
        : p < 1000000
            ? 5000
            : p < 10000000
                ? 50000
                : 500000;
    final r = ((p / step).round() * step).toDouble();
    return math.min(math.max(r, _lo.toDouble()), _hi.toDouble());
  }

  void _openFilters() {
    var sort = _sort;
    var range = _range;
    const label = TextStyle(
        fontSize: 12,
        letterSpacing: 2,
        fontWeight: FontWeight.w700,
        color: AppColors.gold);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.paper,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(12))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Sort & Filter',
                    style: GoogleFonts.playfairDisplay(
                        fontSize: 22, fontWeight: FontWeight.w500)),
                const SizedBox(height: 18),
                const Text('SORT BY', style: label),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final o in _sorts)
                      ChoiceChip(
                        label: Text(o),
                        selected: sort == o,
                        labelStyle: TextStyle(
                          fontSize: 12,
                          color: sort == o ? Colors.white : AppColors.ink,
                        ),
                        onSelected: (_) => setSheet(() => sort = o),
                      ),
                  ],
                ),
                const SizedBox(height: 22),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('PRICE RANGE', style: label),
                    Text(
                        '${peso(range.start.round())} - ${peso(range.end.round())}',
                        style: const TextStyle(fontSize: 13)),
                  ],
                ),
                RangeSlider(
                  values: RangeValues(_toLog(range.start), _toLog(range.end)),
                  min: _toLog(_lo.toDouble()),
                  max: _toLog(_hi.toDouble()),
                  activeColor: AppColors.ink,
                  inactiveColor: AppColors.line,
                  labels: RangeLabels(
                      peso(range.start.round()), peso(range.end.round())),
                  onChanged: (v) => setSheet(() {
                    final s = _fromLog(v.start);
                    final e = _fromLog(v.end);
                    range = RangeValues(math.min(s, e), math.max(s, e));
                  }),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => setSheet(() {
                          sort = 'Featured';
                          range = RangeValues(_lo.toDouble(), _hi.toDouble());
                        }),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(50),
                          foregroundColor: AppColors.ink,
                          side: const BorderSide(color: AppColors.ink),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4)),
                        ),
                        child: const Text('RESET'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () {
                          setState(() {
                            _sort = sort;
                            _picked = range;
                          });
                          Navigator.pop(ctx);
                        },
                        child: const Text('APPLY'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _addToCart(Watch w, int qty, String size) {
    for (var i = 0; i < qty; i++) {
      Cart.instance.add(w, size);
    }

    // Keep the snackbar from getting too wide on large screens
    final width = MediaQuery.of(context).size.width;
    final side = width > 460 ? (width - 420) / 2 : 16.0;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        persist: false,
        duration: const Duration(seconds: 3),
        margin: EdgeInsets.fromLTRB(side, 0, side, 16),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        content: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              color: AppColors.mist,
              padding: const EdgeInsets.all(3),
              child: WatchImage(url: w.imageUrl),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(qty > 1 ? 'Added $qty to cart' : 'Added to cart',
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 13)),
                  Text('${w.name}  •  Size $size',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12, color: Colors.white70)),
                ],
              ),
            ),
          ],
        ),
        action: SnackBarAction(
          label: 'VIEW',
          textColor: const Color(0xFFE8B98F),
          onPressed: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const CartScreen())),
        ),
      ));
  }

  void _openDetail(Watch w) {
    Navigator.push(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 650),
        reverseTransitionDuration: const Duration(milliseconds: 500),
        pageBuilder: (_, __, ___) => SkyBackground(
            child: WatchDetailScreen(
                watch: w,
                onAdd: (watch, qty, size) => _addToCart(watch, qty, size))),
        transitionsBuilder: (_, a, __, child) => FadeTransition(
          opacity: CurvedAnimation(parent: a, curve: Curves.easeInOutCubic),
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = FirebaseAuth.instance.currentUser?.displayName ?? '';
    final items = _filtered;
    final brands = _brands;

    return Scaffold(
      appBar: AppBar(
        title: const Text(kAppName),
        actions: [
          ListenableBuilder(
            listenable: VoucherStore.instance,
            builder: (_, __) {
              final n = VoucherStore.instance.claimable.length;
              return IconButton(
                tooltip: 'Vouchers',
                icon: Badge(
                  label: Text('$n'),
                  isLabelVisible: n > 0,
                  backgroundColor: AppColors.gold,
                  child: const Icon(Icons.local_offer_outlined),
                ),
                onPressed: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const VouchersScreen())),
              );
            },
          ),
          ListenableBuilder(
            listenable: Wishlist.instance,
            builder: (_, __) => IconButton(
              tooltip: 'Wishlist',
              icon: Badge(
                label: Text('${Wishlist.instance.count}'),
                isLabelVisible: Wishlist.instance.count > 0,
                backgroundColor: AppColors.gold,
                child: const Icon(Icons.favorite_border),
              ),
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const WishlistScreen())),
            ),
          ),
          // The cart badge bounces whenever an item is added
          ListenableBuilder(
            listenable: Cart.instance,
            builder: (_, __) {
              final n = Cart.instance.count;
              return TweenAnimationBuilder<double>(
                key: ValueKey(n),
                tween: Tween(begin: n == 0 ? 1.0 : 1.5, end: 1.0),
                duration: const Duration(milliseconds: 700),
                curve: Curves.elasticOut,
                builder: (_, s, child) =>
                    Transform.scale(scale: s, child: child),
                child: IconButton(
                  tooltip: 'Cart',
                  icon: Badge(
                    label: Text('$n'),
                    isLabelVisible: n > 0,
                    backgroundColor: AppColors.gold,
                    child: const Icon(Icons.shopping_bag_outlined),
                  ),
                  onPressed: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const CartScreen())),
                ),
              );
            },
          ),
          PopupMenuButton<String>(
            tooltip: 'Account',
            icon: const Icon(Icons.person_outline),
            onSelected: (v) async {
              if (v == 'orders') {
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const OrdersScreen()));
              } else if (v == 'address') {
                // Opens the page immediately; does not wait for Firestore
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => AddressLoaderScreen(future: _addrFuture)),
                );
                // Refresh so the next open has up-to-date data
                if (mounted) {
                  setState(() => _addrFuture = ShippingAddress.load());
                }
              } else if (v == 'legal') {
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const LegalMenuScreen()));
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'orders', child: Text('My orders')),
              const PopupMenuItem(
                  value: 'address', child: Text('Shipping address')),
              const PopupMenuItem(
                  value: 'legal', child: Text('Terms & policies')),
            ],
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Reveal(
                    child: Text('Welcome${name.isEmpty ? '' : ', $name'}',
                        style: GoogleFonts.playfairDisplay(
                            fontSize: 15, color: AppColors.ink)),
                  ),
                  const SizedBox(height: 2),
                  Reveal(
                    delay: const Duration(milliseconds: 120),
                    child: Text('Featured Collection',
                        style: GoogleFonts.playfairDisplay(
                            fontSize: 28, fontWeight: FontWeight.w500)),
                  ),
                  const SizedBox(height: 16),
                  Reveal(
                    delay: const Duration(milliseconds: 240),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            onChanged: (v) => setState(() => _query = v),
                            decoration: const InputDecoration(
                              hintText: 'Search watches',
                              prefixIcon: Icon(Icons.search),
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Material(
                          color: Colors.white.withValues(alpha: 0.35),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                            side: const BorderSide(color: AppColors.outline),
                          ),
                          child: InkWell(
                            onTap: _openFilters,
                            borderRadius: BorderRadius.circular(4),
                            child: SizedBox(
                              width: 48,
                              height: 48,
                              child: Center(
                                child: Badge(
                                  isLabelVisible: _filtersActive,
                                  smallSize: 9,
                                  backgroundColor: AppColors.gold,
                                  child: const Icon(Icons.tune),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                      '${items.length} ${items.length == 1 ? 'watch' : 'watches'}',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.muted)),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Reveal(
              delay: const Duration(milliseconds: 340),
              child: SizedBox(
                height: 44,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: brands.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final b = brands[i];
                    final selected = b == _brand;
                    return SilverChip(
                      label: b.toUpperCase(),
                      selected: selected,
                      onTap: () => setState(() => _brand = b),
                    );
                  },
                ),
              ),
            ),
          ),
          if (items.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                  child: Text('No watches found.',
                      style: TextStyle(color: AppColors.muted))),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 260,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 0.66,
                ),
                delegate: SliverChildBuilderDelegate(
                  (_, i) => Reveal(
                    key: ValueKey(items[i].id),
                    delay: Duration(milliseconds: 400 + (i % 6) * 110),
                    child: WatchCard(
                      watch: items[i],
                      onTap: () => _openDetail(items[i]),
                    ),
                  ),
                  childCount: items.length,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class WatchCard extends StatefulWidget {
  final Watch watch;
  final VoidCallback onTap;
  const WatchCard({super.key, required this.watch, required this.onTap});

  @override
  State<WatchCard> createState() => _WatchCardState();
}

class _WatchCardState extends State<WatchCard> {
  bool _hover = false;
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final w = widget.watch;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        onTapDown: (_) => setState(() => _down = true),
        onTapUp: (_) => setState(() => _down = false),
        onTapCancel: () => setState(() => _down = false),
        child: AnimatedScale(
          scale: _down ? 0.97 : 1,
          duration: const Duration(milliseconds: 200),
          curve: kLuxuryCurve,
          child: AnimatedSlide(
            offset: Offset(0, _hover ? -0.015 : 0),
            duration: const Duration(milliseconds: 450),
            curve: kLuxuryCurve,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Hero(
                    tag: 'watch-${w.id}',
                    child: Container(
                      width: double.infinity,
                      decoration: cardDecoration(),
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: Padding(
                                padding: const EdgeInsets.all(8),
                                child: AnimatedScale(
                                  scale: _hover ? 1.07 : 1,
                                  duration: const Duration(milliseconds: 700),
                                  curve: kLuxuryCurve,
                                  child: WatchImage(url: w.imageUrl),
                                ),
                              ),
                            ),
                          ),
                          // Sold Out overlay (only shows when stock is 0)
                          Positioned.fill(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child:
                                  SoldOutOverlay(watchId: w.id, small: true),
                            ),
                          ),
                          Positioned(
                            top: 4,
                            right: 4,
                            child: HeartButton(watchId: w.id, bubble: true),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
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
                AnimatedContainer(
                  duration: const Duration(milliseconds: 500),
                  curve: kLuxuryCurve,
                  margin: const EdgeInsets.only(top: 6),
                  height: 2,
                  width: _hover ? 40 : 0,
                  color: AppColors.gold,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class WatchDetailScreen extends StatefulWidget {
  final Watch watch;
  final void Function(Watch watch, int qty, String size) onAdd;
  const WatchDetailScreen(
      {super.key, required this.watch, required this.onAdd});

  @override
  State<WatchDetailScreen> createState() => _WatchDetailScreenState();
}

class _WatchDetailScreenState extends State<WatchDetailScreen> {
  static const _maxQty = 999;
  static const _label = TextStyle(
      fontSize: 12,
      letterSpacing: 2,
      fontWeight: FontWeight.w700,
      color: AppColors.gold);

  int _qty = 1;
  String? _size;
  bool _sizeError = false;

  // Controls the "You may also like" row (arrow buttons + drag)
  final _relatedCtrl = ScrollController();

  void _scrollRelated(double dx) {
    if (!_relatedCtrl.hasClients) return;
    final target = (_relatedCtrl.offset + dx)
        .clamp(0.0, _relatedCtrl.position.maxScrollExtent);
    _relatedCtrl.animateTo(target,
        duration: const Duration(milliseconds: 350), curve: Curves.easeOut);
  }

  // Rebuild when the live stock changes
  void _onStock() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    Inventory.instance.addListener(_onStock);
  }

  @override
  void dispose() {
    _relatedCtrl.dispose();
    Inventory.instance.removeListener(_onStock);
    super.dispose();
  }

  /// Same brand first, then the rest.
  List<Watch> get _related {
    final others =
        sampleWatches.where((w) => w.id != widget.watch.id).toList();
    final same = others.where((w) => w.brand == widget.watch.brand);
    final diff = others.where((w) => w.brand != widget.watch.brand);
    return <Watch>[...same, ...diff].take(4).toList();
  }

  Widget _qtyBtn(IconData icon, VoidCallback? onTap) => SizedBox(
        width: 40,
        height: 40,
        child: OutlinedButton(
          onPressed: onTap,
          style: OutlinedButton.styleFrom(
            padding: EdgeInsets.zero,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            side: const BorderSide(color: AppColors.outline),
            foregroundColor: AppColors.ink,
          ),
          child: Icon(icon, size: 18),
        ),
      );

  Widget _specs(Watch w) => Container(
        decoration: cardDecoration(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Column(
          children: [
            for (final e in w.specs.entries.toList().asMap().entries) ...[
              if (e.key > 0) const Divider(height: 1, color: AppColors.line),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 11),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text(e.value.key,
                          style: const TextStyle(
                              fontSize: 13, color: AppColors.muted)),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(e.value.value,
                          textAlign: TextAlign.right,
                          style: const TextStyle(fontSize: 13)),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      );

  Widget _relatedCard(Watch r) => GestureDetector(
        onTap: () => Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (_) =>
                  WatchDetailScreen(watch: r, onAdd: widget.onAdd)),
        ),
        child: SizedBox(
          width: 140,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 140,
                width: double.infinity,
                decoration: cardDecoration(),
                padding: const EdgeInsets.all(8),
                child: WatchImage(url: r.imageUrl),
              ),
              const SizedBox(height: 8),
              Text(r.brand.toUpperCase(),
                  style: const TextStyle(fontSize: 11, letterSpacing: 1)),
              Text(r.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, height: 1.3)),
              const SizedBox(height: 4),
              Text(peso(r.price),
                  style: const TextStyle(
                      color: AppColors.gold,
                      fontSize: 13,
                      fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final w = widget.watch;
    final related = _related;
    final soldOut = Inventory.instance.soldOut(w.id);
    final maxQty = Inventory.instance.maxQty(w.id, _maxQty);
    if (_qty > maxQty && maxQty > 0) _qty = maxQty;

    return Scaffold(
      appBar: AppBar(
        title: const Text(kAppName),
        actions: [
          HeartButton(watchId: w.id, size: 24),
          const SizedBox(width: 8),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Hero(
                tag: 'watch-${w.id}',
                child: Container(
                  height: 340,
                  decoration: cardDecoration(),
                  padding: const EdgeInsets.all(16),
                  child: Stack(
                    children: [
                      Positioned.fill(child: WatchImage(url: w.imageUrl)),
                      Positioned.fill(child: SoldOutOverlay(watchId: w.id)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Reveal(
                delay: const Duration(milliseconds: 250),
                child: Text(w.brand.toUpperCase(),
                    style: const TextStyle(
                        color: AppColors.gold, letterSpacing: 3, fontSize: 12)),
              ),
              const SizedBox(height: 6),
              Reveal(
                delay: const Duration(milliseconds: 350),
                child: Text(w.name,
                    style: GoogleFonts.playfairDisplay(
                        fontSize: 26, fontWeight: FontWeight.w500)),
              ),
              const SizedBox(height: 10),
              Reveal(
                delay: const Duration(milliseconds: 450),
                child: Text(peso(w.price),
                    style: const TextStyle(
                        color: AppColors.gold,
                        fontSize: 24,
                        fontWeight: FontWeight.w700)),
              ),
              const SizedBox(height: 4),
              StockLabel(watchId: w.id),
              if (w.description.isNotEmpty) ...[
                const SizedBox(height: 16),
                Reveal(
                  delay: const Duration(milliseconds: 500),
                  child: Text(w.description,
                      style: const TextStyle(fontSize: 14, height: 1.5)),
                ),
              ],
              const SizedBox(height: 24),
              Reveal(
                delay: const Duration(milliseconds: 520),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text('SIZE', style: _label),
                        if (_sizeError)
                          Text('   Please select a size',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.red.shade700)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final sz in kSizes)
                          ChoiceChip(
                            label: Text(sz),
                            selected: _size == sz,
                            labelStyle: TextStyle(
                              fontSize: 13,
                              color: _size == sz ? Colors.white : AppColors.ink,
                            ),
                            onSelected: (_) => setState(() {
                              _size = sz;
                              _sizeError = false;
                            }),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: Text(
                        _size == null
                            ? 'S: 14 - 16 cm  •  M: 16 - 18 cm  •  L: 18 - 20 cm (wrist)'
                            : 'Fits ${kSizeGuide[_size]!.toLowerCase()}',
                        key: ValueKey(_size),
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.muted),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Reveal(
                delay: const Duration(milliseconds: 550),
                child: Row(
                  children: [
                    const Text('QUANTITY', style: _label),
                    const Spacer(),
                    _qtyBtn(Icons.remove,
                        _qty > 1 ? () => setState(() => _qty--) : null),
                    SizedBox(
                      width: 48,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        transitionBuilder: (c, a) => FadeTransition(
                            opacity: a,
                            child: ScaleTransition(scale: a, child: c)),
                        child: Text('$_qty',
                            key: ValueKey(_qty),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w700)),
                      ),
                    ),
                    _qtyBtn(Icons.add,
                        _qty < maxQty ? () => setState(() => _qty++) : null),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Reveal(
                delay: const Duration(milliseconds: 600),
                child: FilledButton(
                  onPressed: soldOut
                      ? null
                      : () {
                          if (_size == null) {
                            setState(() => _sizeError = true);
                            return;
                          }
                          widget.onAdd(w, _qty, _size!);
                          Navigator.pop(context);
                        },
                  style: FilledButton.styleFrom(
                    disabledBackgroundColor: AppColors.line,
                    disabledForegroundColor: AppColors.muted,
                  ),
                  child: Text(soldOut
                      ? 'SOLD OUT'
                      : 'ADD TO CART  •  ${peso(w.price * _qty)}'),
                ),
              ),
              if (w.specs.isNotEmpty) ...[
                const SizedBox(height: 32),
                const Text('SPECIFICATIONS', style: _label),
                const SizedBox(height: 10),
                _specs(w),
              ],
              if (related.isNotEmpty) ...[
                const SizedBox(height: 32),
                Row(
                  children: [
                    const Text('YOU MAY ALSO LIKE', style: _label),
                    const Spacer(),
                    IconButton(
                      tooltip: 'Previous',
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.chevron_left),
                      onPressed: () => _scrollRelated(-304),
                    ),
                    IconButton(
                      tooltip: 'Next',
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.chevron_right),
                      onPressed: () => _scrollRelated(304),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 232,
                  child: ListView.separated(
                    controller: _relatedCtrl,
                    scrollDirection: Axis.horizontal,
                    itemCount: related.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (_, i) => _relatedCard(related[i]),
                  ),
                ),
              ],
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

class AddressLoaderScreen extends StatelessWidget {
  final Future<ShippingAddress?> future;
  const AddressLoaderScreen({super.key, required this.future});

  @override
  Widget build(BuildContext context) => FutureBuilder<ShippingAddress?>(
        future: future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return Scaffold(
              appBar: AppBar(title: const Text('SHIPPING ADDRESS')),
              body: const Center(child: CircularProgressIndicator()),
            );
          }
          return AddressScreen(initial: snap.data);
        },
      );
}

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});
  @override
  State<OrdersScreen> createState() => _OrdersScreenState();

  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec'
  ];

  static int _millis(dynamic t) => t is Timestamp
      ? t.millisecondsSinceEpoch
      : DateTime.now().millisecondsSinceEpoch;

  static String _date(dynamic t) {
    if (t is! Timestamp) return 'Just now';
    final d = t.toDate();
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final m = d.minute.toString().padLeft(2, '0');
    return '${_months[d.month - 1]} ${d.day}, ${d.year}  •  $h:$m ${d.hour >= 12 ? 'PM' : 'AM'}';
  }

  static String _paymentLabel(Map<String, dynamic> d) {
    final base = (d['payment'] ?? '').toString();
    final det = d['paymentDetails'];
    if (det is Map) {
      if (det['gcashNumber'] != null) return '$base • ${det['gcashNumber']}';
      if (det['bank'] != null) return '$base • ${det['bank']}';
    }
    return base;
  }

  static Watch? _watchById(dynamic id) {
    final s = id?.toString();
    for (final w in sampleWatches) {
      if (w.id == s) return w;
    }
    return null;
  }

  static String _imageOf(dynamic id) => _watchById(id)?.imageUrl ?? '';

  static void _orderAgain(BuildContext context, Map<String, dynamic> d) {
    final items = (d['items'] is List) ? (d['items'] as List) : const [];
    var added = 0;
    var skipped = 0;

    for (final it in items) {
      if (it is! Map) continue;
      final w = _watchById(it['id']);
      if (w == null || Inventory.instance.soldOut(w.id)) {
        skipped++;
        continue;
      }
      var size = (it['size'] ?? 'M').toString();
      if (!kSizes.contains(size)) size = 'M';
      final wanted = (it['qty'] as num?)?.toInt() ?? 1;
      final qty = math.min(wanted, Inventory.instance.maxQty(w.id, wanted));
      if (qty < 1) {
        skipped++;
        continue;
      }
      for (var i = 0; i < qty; i++) {
        Cart.instance.add(w, size);
      }
      added++;
    }

    if (added == 0) {
      toast(context, 'Sorry, these watches are not available right now.');
      return;
    }
    toast(
        context,
        skipped == 0
            ? 'Added to your cart.'
            : 'Added to your cart. $skipped item${skipped == 1 ? ' is' : 's are'} no longer available.');
    Navigator.push(
        context, MaterialPageRoute(builder: (_) => const CartScreen()));
  }

  static Future<void> _cancel(BuildContext context,
      DocumentReference<Map<String, dynamic>> ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel this order?'),
        content: const Text(
            'This cannot be undone. Only pending orders can be cancelled.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('KEEP ORDER')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('CANCEL ORDER',
                  style: TextStyle(color: Colors.red.shade700))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      // Cancel + give the stock back, all in one transaction
      final db = FirebaseFirestore.instance;
      await db.runTransaction((tx) async {
        final snap = await tx.get(ref);
        final d = snap.data();
        if (d == null || d['status'] != 'pending') {
          throw Exception('Order is not pending');
        }
        final need = <String, int>{};
        for (final it in (d['items'] is List ? d['items'] as List : const [])) {
          if (it is Map && it['id'] != null) {
            final id = it['id'].toString();
            need[id] = (need[id] ?? 0) + ((it['qty'] as num?)?.toInt() ?? 1);
          }
        }
        final snaps = <String, DocumentSnapshot<Map<String, dynamic>>>{};
        for (final e in need.entries) {
          snaps[e.key] = await tx.get(db.collection('watches').doc(e.key));
        }
        for (final e in need.entries) {
          final ws = snaps[e.key]!;
          final cur = ws.data()?['stock'];
          if (cur is num) {
            tx.update(ws.reference, {'stock': cur.toInt() + e.value});
          }
        }
        tx.update(ref, {
          'status': 'cancelled',
          'cancelledAt': FieldValue.serverTimestamp(),
        });
      });
      if (context.mounted) toast(context, 'Order cancelled.');
    } catch (e) {
      debugPrint('Cancel order error: $e');
      if (context.mounted) {
        toast(context, 'Could not cancel the order. Please try again.');
      }
    }
  }
}

class _OrdersScreenState extends State<OrdersScreen> {
  static const _filters = ['All', 'Pending', 'Cancelled'];
  String _filter = 'All';

  static String _statusOf(Map<String, dynamic> d) =>
      (d['status'] ?? 'pending').toString();

  bool _match(Map<String, dynamic> d) {
    switch (_filter) {
      case 'Pending':
        return _statusOf(d) == 'pending';
      case 'Cancelled':
        return _statusOf(d) == 'cancelled';
      default:
        return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(title: const Text('MY ORDERS')),
      body: uid == null
          ? const Center(child: Text('Please log in.'))
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('orders')
                  .where('uid', isEqualTo: uid)
                  .snapshots(),
              builder: (context, snap) {
                if (snap.hasError) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Could not load your orders.\nCheck your Firestore rules (read access for your own orders).',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.muted),
                      ),
                    ),
                  );
                }
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final all = snap.data!.docs.toList()
                  ..sort((a, b) => OrdersScreen._millis(b.data()['createdAt'])
                      .compareTo(OrdersScreen._millis(a.data()['createdAt'])));

                final counts = {
                  'All': all.length,
                  'Pending':
                      all.where((x) => _statusOf(x.data()) == 'pending').length,
                  'Cancelled': all
                      .where((x) => _statusOf(x.data()) == 'cancelled')
                      .length,
                };
                final docs = all.where((x) => _match(x.data())).toList();

                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: Column(
                      children: [
                        // ----- Tabs -----
                        SizedBox(
                          height: 52,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                            child: Row(
                              children: [
                                for (final f in _filters) ...[
                                  SilverChip(
                                    label: '${f.toUpperCase()} (${counts[f]})',
                                    selected: _filter == f,
                                    onTap: () => setState(() => _filter = f),
                                  ),
                                  const SizedBox(width: 8),
                                ],
                              ],
                            ),
                          ),
                        ),
                        Expanded(
                          child: docs.isEmpty
                              ? _empty()
                              : ListView.builder(
                                  padding: const EdgeInsets.all(16),
                                  itemCount: docs.length,
                                  itemBuilder: (ctx, i) => Reveal(
                                    // new key per tab so the cards animate in again
                                    key: ValueKey('$_filter-${docs[i].id}'),
                                    delay: Duration(
                                        milliseconds: 80 * math.min(i, 6)),
                                    child: _orderCard(ctx, docs[i]),
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _empty() {
    const msgs = {
      'All': 'No orders yet.',
      'Pending': 'No pending orders.',
      'Cancelled': 'No cancelled orders.',
    };
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.receipt_long_outlined,
              size: 64, color: AppColors.muted),
          const SizedBox(height: 16),
          Text(msgs[_filter] ?? 'No orders.',
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _orderCard(
      BuildContext context, QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    final items = (d['items'] is List) ? (d['items'] as List) : const [];
    final total = (d['total'] as num?)?.toInt() ?? 0;
    final status = _statusOf(d);
    final id = doc.id.length >= 8 ? doc.id.substring(0, 8) : doc.id;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => OrderDetailScreen(ref: doc.reference)),
        ),
        child: Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.mist,
            border: Border.all(color: AppColors.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('ORDER #${id.toUpperCase()}',
                      style: const TextStyle(
                          color: AppColors.gold,
                          fontSize: 12,
                          letterSpacing: 2,
                          fontWeight: FontWeight.w700)),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(status.toUpperCase(),
                          style: TextStyle(
                              fontSize: 10,
                              letterSpacing: 1.5,
                              color: status == 'cancelled'
                                  ? Colors.red.shade700
                                  : AppColors.ink)),
                      const SizedBox(width: 4),
                      const Icon(Icons.chevron_right,
                          size: 18, color: AppColors.muted),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(OrdersScreen._date(d['createdAt']),
                  style: const TextStyle(fontSize: 12, color: AppColors.muted)),
              if (status == 'cancelled') ...[
                const SizedBox(height: 14),
                OrderTracker(status: status),
              ],
              const Divider(height: 24, color: AppColors.line),
              for (final it in items)
                if (it is Map)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Photo of the watch that was ordered (looked up by id)
                        Container(
                          width: 64,
                          height: 64,
                          decoration: cardDecoration(),
                          padding: const EdgeInsets.all(4),
                          child:
                              WatchImage(url: OrdersScreen._imageOf(it['id'])),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if ((it['brand'] ?? '').toString().isNotEmpty)
                                Text(it['brand'].toString().toUpperCase(),
                                    style: const TextStyle(
                                        fontSize: 10,
                                        letterSpacing: 1.5,
                                        color: AppColors.gold)),
                              Text('${it['name'] ?? ''}',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 13, height: 1.3)),
                              const SizedBox(height: 2),
                              Text(
                                  '${it['size'] != null ? 'Size ${it['size']}  •  ' : ''}Qty: ${it['qty'] ?? 1}',
                                  style: const TextStyle(
                                      fontSize: 12, color: AppColors.muted)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
              const SizedBox(height: 6),
              if (((d['discount'] as num?) ?? 0) > 0)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Voucher ${d['voucher'] ?? ''}',
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.muted)),
                      Text('-${peso((d['discount'] as num).toInt())}',
                          style: const TextStyle(fontSize: 13)),
                    ],
                  ),
                ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(OrdersScreen._paymentLabel(d),
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.muted)),
                  Text(peso(total),
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700)),
                ],
              ),
              const Divider(height: 24, color: AppColors.line),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: () => OrdersScreen._orderAgain(context, d),
                    icon: const Icon(Icons.replay, size: 16),
                    label: const Text('ORDER AGAIN',
                        style: TextStyle(fontSize: 12, letterSpacing: 1)),
                  ),
                  const Spacer(),
                  if (status == 'pending')
                    TextButton.icon(
                      onPressed: () =>
                          OrdersScreen._cancel(context, doc.reference),
                      icon: Icon(Icons.close,
                          size: 16, color: Colors.red.shade700),
                      label: Text('CANCEL ORDER',
                          style: TextStyle(
                              color: Colors.red.shade700,
                              fontSize: 12,
                              letterSpacing: 1)),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// ORDER DETAILS (full information about one order, updates live)
// ============================================================

class OrderDetailScreen extends StatelessWidget {
  final DocumentReference<Map<String, dynamic>> ref;
  const OrderDetailScreen({super.key, required this.ref});

  Widget _box(String title, Widget child) => Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.mist,
          border: Border.all(color: AppColors.line),
        ),
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

  Widget _row(String l, String r, {bool bold = false, Color? color}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(l,
                style: TextStyle(
                    fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
                    fontSize: bold ? 16 : 14,
                    color: color)),
            Text(r,
                style: TextStyle(
                    fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
                    fontSize: bold ? 16 : 14,
                    color: color)),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('ORDER DETAILS')),
        body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: ref.snapshots(),
          builder: (context, snap) {
            if (snap.hasError) {
              return const Center(
                  child: Text('Could not load this order.',
                      style: TextStyle(color: AppColors.muted)));
            }
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final d = snap.data!.data();
            if (d == null) {
              return const Center(child: Text('Order not found.'));
            }
            return _content(context, snap.data!.id, d);
          },
        ),
      );

  Widget _content(BuildContext context, String docId, Map<String, dynamic> d) {
    final items = (d['items'] is List) ? (d['items'] as List) : const [];
    final status = (d['status'] ?? 'pending').toString();
    final discount = (d['discount'] as num?)?.toInt() ?? 0;
    final total = (d['total'] as num?)?.toInt() ?? 0;
    final shippingFee = (d['shippingFee'] as num?)?.toInt() ?? 0;
    final shipping = ShippingAddress.fromMap(d['shipping']);
    final id = docId.length >= 8 ? docId.substring(0, 8) : docId;

    // Older orders may not have a saved subtotal: add up the items instead
    var itemsTotal = 0;
    for (final it in items) {
      if (it is Map) {
        itemsTotal += ((it['price'] as num?)?.toInt() ?? 0) *
            ((it['qty'] as num?)?.toInt() ?? 1);
      }
    }
    final subtotal = (d['subtotal'] as num?)?.toInt() ?? itemsTotal;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ----- Header + status -----
            Reveal(
              child: _box(
                'Order #${id.toUpperCase()}',
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(OrdersScreen._date(d['createdAt']),
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.muted)),
                    if (status == 'cancelled') ...[
                      const SizedBox(height: 14),
                      OrderTracker(status: status),
                    ],
                  ],
                ),
              ),
            ),

            // ----- Items -----
            Reveal(
              delay: const Duration(milliseconds: 100),
              child: _box(
                'Items',
                Column(
                  children: [
                    for (final it in items)
                      if (it is Map)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 64,
                                height: 64,
                                decoration: cardDecoration(),
                                padding: const EdgeInsets.all(4),
                                child: WatchImage(
                                    url: OrdersScreen._imageOf(it['id'])),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if ((it['brand'] ?? '')
                                        .toString()
                                        .isNotEmpty)
                                      Text(
                                          it['brand'].toString().toUpperCase(),
                                          style: const TextStyle(
                                              fontSize: 10,
                                              letterSpacing: 1.5,
                                              color: AppColors.gold)),
                                    Text('${it['name'] ?? ''}',
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            fontSize: 13, height: 1.3)),
                                    const SizedBox(height: 2),
                                    Text(
                                        '${it['size'] != null ? 'Size ${it['size']}  •  ' : ''}Qty: ${it['qty'] ?? 1}',
                                        style: const TextStyle(
                                            fontSize: 12,
                                            color: AppColors.muted)),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                  peso(((it['price'] as num?)?.toInt() ?? 0) *
                                      ((it['qty'] as num?)?.toInt() ?? 1)),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                  ],
                ),
              ),
            ),

            // ----- Shipping address -----
            if (shipping != null)
              Reveal(
                delay: const Duration(milliseconds: 200),
                child: _box(
                  'Shipping address',
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 2),
                        child: Icon(Icons.location_on_outlined,
                            color: AppColors.ink),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${shipping.name}  •  ${shipping.phone}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                            const SizedBox(height: 4),
                            Text(shipping.fullAddress,
                                style:
                                    const TextStyle(fontSize: 13, height: 1.4)),
                            if (shipping.notes.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text('Note: ${shipping.notes}',
                                  style: const TextStyle(
                                      fontSize: 12, color: AppColors.muted)),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // ----- Payment -----
            Reveal(
              delay: const Duration(milliseconds: 300),
              child: _box(
                'Payment',
                Column(
                  children: [
                    _row('Method', OrdersScreen._paymentLabel(d)),
                    const Divider(color: AppColors.line),
                    _row('Subtotal', peso(subtotal)),
                    _row('Shipping',
                        shippingFee == 0 ? 'FREE' : peso(shippingFee)),
                    if (discount > 0)
                      _row('Voucher (${d['voucher'] ?? ''})',
                          '-${peso(discount)}'),
                    const Divider(color: AppColors.line),
                    _row('Total', peso(total), bold: true),
                  ],
                ),
              ),
            ),

            // ----- Actions -----
            Reveal(
              delay: const Duration(milliseconds: 400),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton.icon(
                    onPressed: () => OrdersScreen._orderAgain(context, d),
                    icon: const Icon(Icons.replay, size: 18),
                    label: const Text('ORDER AGAIN'),
                  ),
                  if (status == 'pending') ...[
                    const SizedBox(height: 10),
                    OutlinedButton(
                      onPressed: () => OrdersScreen._cancel(context, ref),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                        foregroundColor: Colors.red.shade700,
                        side: BorderSide(color: Colors.red.shade700),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4)),
                      ),
                      child: const Text('CANCEL ORDER'),
                    ),
                  ],
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Order progress: Placed -> Confirmed -> Shipped -> Delivered.
/// The progress line and dots animate smoothly when the status changes.
class OrderTracker extends StatelessWidget {
  final String status;
  const OrderTracker({super.key, required this.status});

  static const _steps = ['pending', 'confirmed', 'shipped', 'delivered'];
  static const _labels = ['Placed', 'Confirmed', 'Shipped', 'Delivered'];

  @override
  Widget build(BuildContext context) {
    if (status == 'cancelled') {
      return Row(
        children: [
          Icon(Icons.cancel_outlined, size: 18, color: Colors.red.shade700),
          const SizedBox(width: 8),
          Text('This order was cancelled.',
              style: TextStyle(fontSize: 13, color: Colors.red.shade700)),
        ],
      );
    }

    const dur = Duration(milliseconds: 600);
    final idx = math.max(0, _steps.indexOf(status));
    return Column(
      children: [
        Row(
          children: [
            for (var i = 0; i < _steps.length; i++) ...[
              if (i > 0)
                Expanded(
                  child: AnimatedContainer(
                      duration: dur,
                      curve: kLuxuryCurve,
                      height: 2,
                      color: i <= idx ? AppColors.ink : AppColors.line),
                ),
              AnimatedContainer(
                duration: dur,
                curve: kLuxuryCurve,
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i <= idx ? AppColors.ink : Colors.transparent,
                  border: Border.all(
                      color: i <= idx ? AppColors.ink : AppColors.line,
                      width: 2),
                ),
                child: i <= idx
                    ? const Icon(Icons.check, size: 13, color: Colors.white)
                    : null,
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (var i = 0; i < _labels.length; i++)
              Text(_labels[i],
                  style: TextStyle(
                      fontSize: 10,
                      color: i <= idx ? AppColors.ink : AppColors.muted)),
          ],
        ),
      ],
    );
  }
}