import 'package:flutter/material.dart';
import 'app_shell.dart';

/// Legacy HomeScreen entrypoint now gracefully delegating to the responsive AppShell
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppShell();
  }
}
