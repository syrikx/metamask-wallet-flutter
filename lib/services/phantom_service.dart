import 'dart:convert';
import 'dart:developer';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'remote_logger.dart';

class PhantomService {
  static PhantomService? _instance;
  static PhantomService get instance => _instance ??= PhantomService._();

  PhantomService._();

  // Connection state
  bool _isConnected = false;
  String? _connectedPublicKey;
  String? _status;
  
  // Remote logger for debugging
  final RemoteLogger _logger = RemoteLogger.instance;

  // Getters
  bool get isInitialized => true;
  bool get isConnected => _isConnected;
  String? get currentAccount => _connectedPublicKey;
  String? get status => _status;

  // Initialize (no-op for URL-based implementation)
  Future<void> initialize() async {
    log('Phantom service initialized (URL-based)');
    _logger.phantom('service_initialized', {
      'method': 'URL-based',
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  // Connect to Phantom wallet using deep link
  Future<void> connectWallet() async {
    try {
      _status = 'Opening Phantom wallet...';
      _logger.phantomConnection('start');
      
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
      _logger.phantomConnection('uri_generated', uri: phantomUri.toString());
      
      // Check if Phantom app can be launched
      final canLaunch = await canLaunchUrl(phantomUri);
      _logger.phantomConnection('can_launch_check', canLaunch: canLaunch);
      
      // Try to launch Phantom app
      if (canLaunch) {
        _logger.phantomConnection('launching_app', uri: phantomUri.toString());
        await launchUrl(phantomUri, mode: LaunchMode.externalApplication);
        
        _logger.phantomConnection('app_launched_waiting');
        // Simulate connection for demo purposes
        // In a real app, you'd handle the redirect and parse the response
        await Future.delayed(const Duration(seconds: 2));
        
        // Mock successful connection
        _mockSuccessfulConnection();
        
      } else {
        // Fallback to Phantom web app
        final Uri webUri = Uri.parse('https://phantom.app/ul/v1/connect?app_url=$appUrl');
        _logger.phantomConnection('fallback_to_web', uri: webUri.toString());
        
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
        
        _logger.phantomConnection('web_launched_waiting');
        // Mock connection after web redirect
        await Future.delayed(const Duration(seconds: 3));
        _mockSuccessfulConnection();
      }
      
    } catch (e) {
      _status = 'Failed to connect to Phantom: $e';
      log('Phantom connection error: $e');
      _logger.phantomConnection('error', error: e.toString());
      rethrow;
    }
  }

  // Mock successful connection for demo
  void _mockSuccessfulConnection() {
    _isConnected = true;
    _connectedPublicKey = 'DemoPhantomPublicKey123456789';
    _status = 'Connected to Phantom wallet';
    log('Phantom wallet connected (demo mode)');
    
    _logger.phantomConnection('success', account: _connectedPublicKey);
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
        _logger.phantomSign('not_connected');
        throw Exception('Wallet not connected');
      }

      _status = 'Opening Phantom for message signing...';
      _logger.phantomSign('start', message: message);
      
      // Create sign message deep link
      final Uri signUri = Uri.parse(
        'phantom://v1/signMessage?'
        'message=${Uri.encodeComponent(message)}&'
        'redirect_link=${Uri.encodeComponent('metamask-wallet-flutter://signed')}'
      );
      
      log('Launching Phantom for signing: $signUri');
      _logger.phantomSign('uri_generated', message: signUri.toString());
      
      if (await canLaunchUrl(signUri)) {
        _logger.phantomSign('launching_app');
        await launchUrl(signUri, mode: LaunchMode.externalApplication);
      } else {
        // Fallback to web
        final Uri webSignUri = Uri.parse(
          'https://phantom.app/ul/v1/signMessage?message=${Uri.encodeComponent(message)}'
        );
        _logger.phantomSign('fallback_to_web');
        await launchUrl(webSignUri, mode: LaunchMode.externalApplication);
      }
      
      // Mock successful signing
      await Future.delayed(const Duration(seconds: 2));
      const String mockSignature = 'MockPhantomSignature123456789ABCDEF';
      
      _status = 'Message signed successfully';
      log('Message signed: $mockSignature');
      _logger.phantomSign('success', signature: mockSignature);
      return mockSignature;
      
    } catch (e) {
      _status = 'Failed to sign message: $e';
      log('Message signing error: $e');
      _logger.phantomSign('error', error: e.toString());
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