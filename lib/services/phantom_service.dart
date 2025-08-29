import 'dart:convert';
import 'dart:developer';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;

class PhantomService {
  static PhantomService? _instance;
  static PhantomService get instance => _instance ??= PhantomService._();

  PhantomService._();

  // Connection state
  bool _isConnected = false;
  String? _connectedPublicKey;
  String? _status;

  // Getters
  bool get isInitialized => true;
  bool get isConnected => _isConnected;
  String? get currentAccount => _connectedPublicKey;
  String? get status => _status;

  // Initialize (no-op for URL-based implementation)
  Future<void> initialize() async {
    log('Phantom service initialized (URL-based)');
  }

  // Connect to Phantom wallet using deep link
  Future<void> connectWallet() async {
    try {
      _status = 'Opening Phantom wallet...';
      
      // Create a connection request URL
      const String appUrl = 'https://metamask-wallet-flutter.app';
      const String redirectLink = 'metamask-wallet-flutter://connected';
      
      // Phantom deep link for connection
      final Uri phantomUri = Uri.parse(
        'phantom://v1/connect?'
        'app_url=${Uri.encodeComponent(appUrl)}&'
        'redirect_link=${Uri.encodeComponent(redirectLink)}'
      );
      
      log('Launching Phantom with URI: $phantomUri');
      
      // Try to launch Phantom app
      if (await canLaunchUrl(phantomUri)) {
        await launchUrl(phantomUri, mode: LaunchMode.externalApplication);
        
        // Simulate connection for demo purposes
        // In a real app, you'd handle the redirect and parse the response
        await Future.delayed(const Duration(seconds: 2));
        
        // Mock successful connection
        _mockSuccessfulConnection();
        
      } else {
        // Fallback to Phantom web app
        final Uri webUri = Uri.parse('https://phantom.app/ul/v1/connect?app_url=$appUrl');
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
        
        // Mock connection after web redirect
        await Future.delayed(const Duration(seconds: 3));
        _mockSuccessfulConnection();
      }
      
    } catch (e) {
      _status = 'Failed to connect to Phantom: $e';
      log('Phantom connection error: $e');
      rethrow;
    }
  }

  // Mock successful connection for demo
  void _mockSuccessfulConnection() {
    _isConnected = true;
    _connectedPublicKey = 'DemoPhantomPublicKey123456789';
    _status = 'Connected to Phantom wallet';
    log('Phantom wallet connected (demo mode)');
  }

  // Disconnect wallet
  Future<void> disconnect() async {
    try {
      _isConnected = false;
      _connectedPublicKey = null;
      _status = 'Disconnected from Phantom wallet';
      log('Phantom wallet disconnected');
    } catch (e) {
      _status = 'Failed to disconnect: $e';
      rethrow;
    }
  }

  // Get SOL balance (mock implementation)
  Future<String> getBalance() async {
    try {
      if (!isConnected) {
        throw Exception('Wallet not connected');
      }

      // Mock balance retrieval
      await Future.delayed(const Duration(seconds: 1));
      
      // Return mock balance
      const double mockBalance = 1.234567;
      _status = 'Balance retrieved successfully';
      
      log('Balance retrieved: $mockBalance SOL');
      return mockBalance.toStringAsFixed(6);
    } catch (e) {
      _status = 'Failed to get balance: $e';
      log('Balance retrieval error: $e');
      return '0.000000';
    }
  }

  // Sign message using Phantom deep link
  Future<String> signMessage(String message) async {
    try {
      if (!isConnected) {
        throw Exception('Wallet not connected');
      }

      _status = 'Opening Phantom for message signing...';
      
      // Create sign message deep link
      final Uri signUri = Uri.parse(
        'phantom://v1/signMessage?'
        'message=${Uri.encodeComponent(message)}&'
        'redirect_link=${Uri.encodeComponent('metamask-wallet-flutter://signed')}'
      );
      
      log('Launching Phantom for signing: $signUri');
      
      if (await canLaunchUrl(signUri)) {
        await launchUrl(signUri, mode: LaunchMode.externalApplication);
      } else {
        // Fallback to web
        final Uri webSignUri = Uri.parse(
          'https://phantom.app/ul/v1/signMessage?message=${Uri.encodeComponent(message)}'
        );
        await launchUrl(webSignUri, mode: LaunchMode.externalApplication);
      }
      
      // Mock successful signing
      await Future.delayed(const Duration(seconds: 2));
      const String mockSignature = 'MockPhantomSignature123456789ABCDEF';
      
      _status = 'Message signed successfully';
      log('Message signed: $mockSignature');
      return mockSignature;
      
    } catch (e) {
      _status = 'Failed to sign message: $e';
      log('Message signing error: $e');
      rethrow;
    }
  }

  // Send SOL transaction using Phantom deep link
  Future<String> sendTransaction({
    required String toAddress,
    required double amount,
  }) async {
    try {
      if (!isConnected) {
        throw Exception('Wallet not connected');
      }

      _status = 'Opening Phantom for transaction...';
      
      // Convert SOL to lamports (1 SOL = 1,000,000,000 lamports)
      final int lamports = (amount * 1000000000).round();
      
      // Create transaction deep link
      final Uri transactionUri = Uri.parse(
        'phantom://v1/signAndSendTransaction?'
        'transaction=${Uri.encodeComponent(_createMockTransaction(toAddress, lamports))}&'
        'redirect_link=${Uri.encodeComponent('metamask-wallet-flutter://transaction')}'
      );
      
      log('Launching Phantom for transaction: $transactionUri');
      
      if (await canLaunchUrl(transactionUri)) {
        await launchUrl(transactionUri, mode: LaunchMode.externalApplication);
      } else {
        // Fallback to web
        const String webTransactionUrl = 'https://phantom.app/ul/v1/signAndSendTransaction';
        await launchUrl(Uri.parse(webTransactionUrl), mode: LaunchMode.externalApplication);
      }
      
      // Mock successful transaction
      await Future.delayed(const Duration(seconds: 3));
      const String mockTxSignature = 'MockTransactionSignature123456789ABCDEF';
      
      _status = 'Transaction sent successfully';
      log('Transaction signature: $mockTxSignature');
      return mockTxSignature;
      
    } catch (e) {
      _status = 'Failed to send transaction: $e';
      log('Transaction error: $e');
      rethrow;
    }
  }

  // Create mock transaction data
  String _createMockTransaction(String toAddress, int lamports) {
    final Map<String, dynamic> transaction = {
      'from': _connectedPublicKey,
      'to': toAddress,
      'lamports': lamports,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
    
    return base64Encode(utf8.encode(json.encode(transaction)));
  }

  // Update status
  void updateStatus(String newStatus) {
    _status = newStatus;
    log('Phantom service status updated: $newStatus');
  }

  // Check if Phantom app is installed
  Future<bool> isPhantomInstalled() async {
    try {
      return await canLaunchUrl(Uri.parse('phantom://'));
    } catch (e) {
      log('Error checking Phantom installation: $e');
      return false;
    }
  }

  // Open Phantom app store page
  Future<void> installPhantom() async {
    try {
      const String playStoreUrl = 'https://play.google.com/store/apps/details?id=app.phantom';
      const String appStoreUrl = 'https://apps.apple.com/app/phantom-solana-wallet/id1598432977';
      
      // Try Play Store first (Android)
      if (await canLaunchUrl(Uri.parse(playStoreUrl))) {
        await launchUrl(Uri.parse(playStoreUrl), mode: LaunchMode.externalApplication);
      } else {
        // Fallback to App Store
        await launchUrl(Uri.parse(appStoreUrl), mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      log('Error opening app store: $e');
      rethrow;
    }
  }
}