import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'services/auth_service.dart';
import 'services/session_manager.dart';
import 'design_system/design_system.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/session_conflict_dialog.dart';
import 'screens/app_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Firebase initialization safely handled for local development
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint("Firebase initialization info: $e");
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => ThemeController()),
      ],
      child: const NotifyApp(),
    ),
  );
}

class NotifyApp extends StatefulWidget {
  const NotifyApp({super.key});

  @override
  State<NotifyApp> createState() => _NotifyAppState();
}

class _NotifyAppState extends State<NotifyApp> with WidgetsBindingObserver {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  final SessionManager _sessionManager = SessionManager();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Listen to session conflicts from another device
    _sessionManager.onSessionConflict.listen((reason) {
      final context = _navigatorKey.currentContext;
      if (context != null) {
        SessionConflictDialog.show(context, reason, () {
          _navigatorKey.currentState?.pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const LoginScreen()),
            (route) => false,
          );
        });
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final authService = Provider.of<AuthService>(_navigatorKey.currentContext ?? context, listen: false);
      if (authService.isAuthenticated && authService.currentUser != null) {
        _sessionManager.validateSessionOnResume(authService.currentUser!.uid);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeController = Provider.of<ThemeController>(context);

    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'Notify',
      debugShowCheckedModeBanner: false,
      theme: NotifyTheme.lightTheme,
      darkTheme: NotifyTheme.darkTheme,
      themeMode: themeController.themeMode,
      home: Consumer<AuthService>(
        builder: (context, auth, _) {
          if (auth.isAuthenticated) {
            return const AppShell();
          }
          return const LoginScreen();
        },
      ),
    );
  }
}
