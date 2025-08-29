import 'package:flutter/material.dart';
import 'services/wallet_service.dart';
import 'services/phantom_service.dart';
import 'screens/wallet_screen.dart';
import 'screens/phantom_screen.dart';
import 'screens/wallet_selection_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize WalletService
  try {
    await WalletService.instance.initialize();
    debugPrint('WalletService initialized successfully');
  } catch (e) {
    debugPrint('Failed to initialize WalletService: $e');
  }
  
  // Initialize PhantomService
  try {
    await PhantomService.instance.initialize();
    debugPrint('PhantomService initialized successfully');
  } catch (e) {
    debugPrint('Failed to initialize PhantomService: $e');
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
      home: const WalletSelectionScreen(),
    );
  }
}

