
import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart'; // 웹/앱 구분용
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'services/ai_service.dart';
import 'screens/home_screen.dart'; // Import HomeScreen

const Color kPaperColor = Color(0xFFF9F7F1);
const Color kInkBlack = Color(0xFF1A1A1A);
const Color kInkBlue = Color(0xFF1B3A57);
const Color kInkLight = Color(0xFF8C8C8C);
const Color kBorderColor = Color(0xFFE0DCD5);
const Color kAccentRed = Color(0xFFB71C1C);

enum PeriodType { daily, weekly, monthly }

// 🌊 지렁이 페인터
class WavyLinePainter extends CustomPainter {
  final Color color;
  WavyLinePainter({required this.color});
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 2.0..isAntiAlias = true;
    final path = Path();
    path.moveTo(0, size.height / 2);
    for (double i = 0; i < size.width; i++) {
      path.lineTo(i, size.height / 2 + sin((i / size.width) * 4 * pi) * 2.5);
    }
    canvas.drawPath(path, paint);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class UserState extends InheritedWidget {
  final Function() onUserChanged;
  const UserState({super.key, required this.onUserChanged, required super.child});
  static UserState? of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<UserState>();
  @override
  bool updateShouldNotify(UserState oldWidget) => false;
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ko_KR', null);
  // TODO: Set your Supabase URL and Key via --dart-define=SUPABASE_URL=... and --dart-define=SUPABASE_KEY=...
  const String supaUrl = String.fromEnvironment('SUPABASE_URL', defaultValue: 'YOUR_SUPABASE_URL');
  const String supaKey = String.fromEnvironment('SUPABASE_KEY', defaultValue: 'YOUR_SUPABASE_KEY');
  await Supabase.initialize(url: supaUrl, anonKey: supaKey);

  if (!kIsWeb) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(statusBarColor: Colors.transparent, statusBarIconBrightness: Brightness.dark, systemNavigationBarColor: kPaperColor));
  }

  runApp(const NeuroxusApp());
}

class NeuroxusApp extends StatelessWidget {
  const NeuroxusApp({super.key});
  @override
  Widget build(BuildContext context) {
    return UserState(
      onUserChanged: () {},
      child: MaterialApp(
        debugShowCheckedModeBanner: false, title: 'Neuroxus Ink',
        theme: ThemeData(
          useMaterial3: true, scaffoldBackgroundColor: kPaperColor, primaryColor: kInkBlack,
          colorScheme: ColorScheme.fromSeed(seedColor: kInkBlue, surface: kPaperColor, background: kPaperColor),
          textTheme: GoogleFonts.nanumMyeongjoTextTheme().copyWith(
            headlineMedium: GoogleFonts.nanumMyeongjo(color: kInkBlack, fontWeight: FontWeight.bold),
            bodyLarge: GoogleFonts.nanumMyeongjo(color: kInkBlack, fontSize: 16, height: 1.6),
            bodyMedium: GoogleFonts.nanumMyeongjo(color: kInkBlack, fontSize: 14),
          ),
          appBarTheme: AppBarTheme(backgroundColor: kPaperColor, elevation: 0, centerTitle: true, titleTextStyle: GoogleFonts.nanumMyeongjo(color: kInkBlack, fontSize: 20, fontWeight: FontWeight.bold), iconTheme: const IconThemeData(color: kInkBlack)),
          dividerColor: kBorderColor,
        ),
        home: StreamBuilder<AuthState>(
          stream: Supabase.instance.client.auth.onAuthStateChange,
          builder: (context, snapshot) {
            final session = Supabase.instance.client.auth.currentSession;
            // If logged in, show the new HomeScreen (The Awakening)
            if (session != null) return const HomeScreen();
            return const LoginPage();
          },
        ),
      ),
    );
  }
}

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  Future<void> _signInWithGoogle() async {
    await Supabase.instance.client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: kIsWeb
          ? 'https://preeminent-cat-7deaaa.netlify.app/' // 웹용 주소
          : 'io.supabase.neuroxus://login-callback' // 앱용 주소
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.auto_stories, size: 60, color: kInkBlack), const SizedBox(height: 24),
            Text("N E U R O X U S", style: GoogleFonts.nanumMyeongjo(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 4)),
            const SizedBox(height: 12),
            Text("당신의 두 번째 뇌, 생각의 지평을 넓히다.", style: GoogleFonts.nanumMyeongjo(fontSize: 14, color: kInkLight)),
            const SizedBox(height: 60),
            OutlinedButton.icon(onPressed: _signInWithGoogle, icon: const Icon(Icons.login, color: kInkBlack), label: Text("Google 계정으로 시작하기", style: GoogleFonts.notoSansKr(color: kInkBlack, fontWeight: FontWeight.bold)), style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16), side: const BorderSide(color: kInkBlack), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)))),
          ]),
      ),
    );
  }
}
