import 'package:flutter/material.dart';
import 'services/wallet_service.dart';
import 'screens/wallet_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize WalletService
  try {
    await WalletService.instance.initialize();
  } catch (e) {
    debugPrint('Failed to initialize WalletService: $e');
  }
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MetaMask Wallet App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.orange),
        useMaterial3: true,
      ),
      home: const WalletScreen(),
    );
  }
}

