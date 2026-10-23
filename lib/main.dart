import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_state.dart';
import 'pages.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
    systemNavigationBarColor: C.yellow,
    systemNavigationBarIconBrightness: Brightness.dark,
  ));
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final state = AppState();
  await state.load();
  runApp(ModalKuApp(state: state));
}

class ModalKuApp extends StatelessWidget {
  final AppState state;
  const ModalKuApp({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ModalKu',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: SplashPage(state: state),
    );
  }
}

/// Pembuka: logo di latar kuning, lalu masuk ke halaman utama.
class SplashPage extends StatefulWidget {
  final AppState state;
  const SplashPage({super.key, required this.state});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1900), () {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 400),
          pageBuilder: (_, __, ___) => HomePage(state: widget.state),
          transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.yellow,
      body: Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 700),
          builder: (_, v, child) => Opacity(opacity: v, child: child),
          child: Image.asset('assets/logo.png', width: 320, semanticLabel: 'ModalKu'),
        ),
      ),
    );
  }
}
