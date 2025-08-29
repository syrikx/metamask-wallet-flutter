import 'package:flutter/material.dart';
import 'services/wallet_service.dart';
import 'services/phantom_service.dart';
import 'services/remote_logger.dart';
import 'screens/wallet_screen.dart';
import 'screens/phantom_screen.dart';
import 'screens/wallet_selection_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize RemoteLogger first
  RemoteLogger.instance.initialize(
    deviceId: 'android_debug_${DateTime.now().millisecondsSinceEpoch}',
    appVersion: '1.1.1-debug',
  );
  RemoteLogger.instance.appLifecycle('app_start');
  
  // Test remote logging connection
  final connectionSuccess = await RemoteLogger.instance.testConnection();
  debugPrint('Remote logging connection: ${connectionSuccess ? 'SUCCESS' : 'FAILED'}');
  
  // Initialize WalletService
  try {
    await WalletService.instance.initialize();
    debugPrint('WalletService initialized successfully');
    RemoteLogger.instance.log('WalletService', 'initialized_successfully');
  } catch (e) {
    debugPrint('Failed to initialize WalletService: $e');
    RemoteLogger.instance.error('WalletService', 'initialization_failed', {'error': e.toString()});
  }
  
  // Initialize PhantomService
  try {
    await PhantomService.instance.initialize();
    debugPrint('PhantomService initialized successfully');
    RemoteLogger.instance.log('PhantomService', 'initialized_successfully');
  } catch (e) {
    debugPrint('Failed to initialize PhantomService: $e');
    RemoteLogger.instance.error('PhantomService', 'initialization_failed', {'error': e.toString()});
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

