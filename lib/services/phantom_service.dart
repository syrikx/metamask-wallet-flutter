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
      _logger.phantomConnection('connection_start');
      
      // Create a connection request URL
      const String appUrl = 'https://metamask-wallet-flutter.app';
      const String redirectLink = 'metamask-wallet-flutter://connected';
      
      _logger.phantomConnection('creating_connection_params', 
        uri: 'phantom://v1/connect');
      
      // Generate session nonce for security
      final String nonce = DateTime.now().millisecondsSinceEpoch.toString();
      _logger.phantomConnection('session_nonce_generated');
      
      // Phantom deep link for connection
      final Uri phantomUri = Uri.parse(
        'phantom://v1/connect?'
        'app_url=${Uri.encodeComponent(appUrl)}&'
        'redirect_link=${Uri.encodeComponent(redirectLink)}&'
        'cluster=devnet'
      );
      
      log('Launching Phantom with URI: $phantomUri');
      _logger.phantomConnection('connection_uri_generated', uri: phantomUri.toString());
      
      // Check if Phantom app can be launched
      _logger.phantomConnection('checking_phantom_app_availability');
      final canLaunch = await canLaunchUrl(phantomUri);
      _logger.phantomConnection('phantom_app_availability_result', canLaunch: canLaunch);
      
      // Try to launch Phantom app
      if (canLaunch) {
        _logger.phantomConnection('attempting_phantom_app_launch');
        
        try {
          await launchUrl(phantomUri, mode: LaunchMode.externalApplication);
          _logger.phantomConnection('phantom_app_launched_successfully');
          
          // Set status to waiting for user interaction
          _status = 'Waiting for Phantom approval...';
          _logger.phantomConnection('waiting_for_user_approval_in_phantom_app');
          
          // Start monitoring for connection timeout
          _startConnectionTimeout();
          
        } catch (launchError) {
          _logger.phantomConnection('phantom_app_launch_failed', error: launchError.toString());
          throw Exception('Failed to launch Phantom app: $launchError');
        }
        
      } else {
        // Fallback to Phantom web app
        _logger.phantomConnection('phantom_app_not_available_trying_web_fallback');
        
        final Uri webUri = Uri.parse(
          'https://phantom.app/ul/v1/connect?'
          'app_url=${Uri.encodeComponent(appUrl)}&'
          'redirect_link=${Uri.encodeComponent(redirectLink)}&'
          'cluster=devnet'
        );
        
        _logger.phantomConnection('web_fallback_uri_generated', uri: webUri.toString());
        
        try {
          await launchUrl(webUri, mode: LaunchMode.externalApplication);
          _logger.phantomConnection('phantom_web_launched_successfully');
          
          _status = 'Waiting for web approval...';
          _logger.phantomConnection('waiting_for_user_approval_in_phantom_web');
          
          // Start monitoring for connection timeout (longer for web)
          _startConnectionTimeout(timeoutSeconds: 60);
          
        } catch (webLaunchError) {
          _logger.phantomConnection('phantom_web_launch_failed', error: webLaunchError.toString());
          throw Exception('Failed to launch Phantom web: $webLaunchError');
        }
      }
      
    } catch (e) {
      _status = 'Failed to connect to Phantom: $e';
      log('Phantom connection error: $e');
      _logger.phantomConnection('connection_attempt_failed', error: e.toString());
      rethrow;
    }
  }

  // Start connection timeout monitoring
  void _startConnectionTimeout({int timeoutSeconds = 30}) {
    _logger.phantomConnection('connection_timeout_timer_started', uri: '${timeoutSeconds}s');
    
    Future.delayed(Duration(seconds: timeoutSeconds), () {
      if (!_isConnected) {
        _logger.phantomConnection('connection_timeout_reached');
        handleConnectionTimeout();
      }
    });
    
    // For testing purposes: simulate success after some time
    // TODO: Remove this in production when deep link handling is implemented
    Future.delayed(const Duration(seconds: 8), () {
      if (!_isConnected) {
        _logger.phantomConnection('test_simulation_triggering_success');
        handleConnectionSuccess('TestPhantomPublicKey123456789ABCDEF');
      }
    });
  }

  // Handle successful connection (should be called when actual response is received)
  void handleConnectionSuccess(String publicKey) {
    _logger.phantomConnection('connection_response_received', account: publicKey);
    
    _isConnected = true;
    _connectedPublicKey = publicKey;
    _status = 'Connected to Phantom wallet';
    
    log('Phantom wallet connected successfully: $publicKey');
    _logger.phantomConnection('connection_successfully_established', account: _connectedPublicKey);
  }
  
  // Handle connection rejection
  void handleConnectionRejection(String reason) {
    _logger.phantomConnection('connection_rejected_by_user', error: reason);
    
    _isConnected = false;
    _connectedPublicKey = null;
    _status = 'Connection rejected: $reason';
    
    log('Phantom wallet connection rejected: $reason');
  }
  
  // Handle connection timeout
  void handleConnectionTimeout() {
    _logger.phantomConnection('connection_timeout_handling');
    
    _isConnected = false;
    _connectedPublicKey = null;
    _status = 'Connection timeout - please try again';
    
    log('Phantom wallet connection timeout');
  }

  // Handle incoming deep link (should be called from app delegate)
  void handleDeepLink(Uri uri) {
    _logger.phantomConnection('deep_link_received', uri: uri.toString());
    
    try {
      final params = uri.queryParameters;
      _logger.phantomConnection('deep_link_params_parsed');
      
      if (uri.scheme == 'metamask-wallet-flutter' && uri.host == 'connected') {
        if (params.containsKey('phantom_encryption_public_key')) {
          final publicKey = params['phantom_encryption_public_key'] ?? '';
          _logger.phantomConnection('phantom_public_key_received', account: publicKey);
          handleConnectionSuccess(publicKey);
        } else if (params.containsKey('errorMessage')) {
          final error = params['errorMessage'] ?? 'Unknown error';
          _logger.phantomConnection('phantom_error_received', error: error);
          handleConnectionRejection(error);
        } else {
          _logger.phantomConnection('phantom_response_missing_required_params');
          handleConnectionRejection('Invalid response format');
        }
      } else {
        _logger.phantomConnection('unexpected_deep_link_scheme_or_host', uri: uri.toString());
      }
      
    } catch (e) {
      _logger.phantomConnection('deep_link_parsing_error', error: e.toString());
      handleConnectionRejection('Failed to parse response: $e');
    }
  }

  // Disconnect wallet
  Future<void> disconnect() async {
    try {
      _logger.phantomConnection('disconnect_initiated');
      
      _isConnected = false;
      _connectedPublicKey = null;
      _status = 'Disconnected from Phantom wallet';
      
      _logger.phantomConnection('disconnect_completed');
      log('Phantom wallet disconnected');
    } catch (e) {
      _status = 'Failed to disconnect: $e';
      _logger.phantomConnection('disconnect_failed', error: e.toString());
      rethrow;
    }
  }

  // Get SOL balance (mock implementation for now)
  Future<String> getBalance() async {
    try {
      if (!isConnected) {
        _logger.phantomConnection('balance_check_not_connected');
        throw Exception('Wallet not connected');
      }

      _logger.phantomConnection('balance_check_started');
      
      // Mock balance retrieval
      await Future.delayed(const Duration(seconds: 1));
      
      // Return mock balance
      const double mockBalance = 2.456789;
      _status = 'Balance retrieved successfully';
      
      _logger.phantomConnection('balance_retrieved', account: mockBalance.toString());
      log('Balance retrieved: $mockBalance SOL');
      return mockBalance.toStringAsFixed(6);
    } catch (e) {
      _status = 'Failed to get balance: $e';
      _logger.phantomConnection('balance_retrieval_failed', error: e.toString());
      log('Balance retrieval error: $e');
      return '0.000000';
    }
  }

  // Sign message using Phantom deep link
  Future<String> signMessage(String message) async {
    try {
      if (!isConnected) {
        _logger.phantomSign('sign_attempt_not_connected');
        throw Exception('Wallet not connected');
      }

      _status = 'Opening Phantom for message signing...';
      _logger.phantomSign('sign_message_started', message: message);
      
      // Create sign message deep link
      final Uri signUri = Uri.parse(
        'phantom://v1/signMessage?'
        'message=${Uri.encodeComponent(message)}&'
        'redirect_link=${Uri.encodeComponent('metamask-wallet-flutter://signed')}'
      );
      
      log('Launching Phantom for signing: $signUri');
      _logger.phantomSign('sign_uri_generated', message: signUri.toString());
      
      if (await canLaunchUrl(signUri)) {
        _logger.phantomSign('launching_phantom_for_signing');
        await launchUrl(signUri, mode: LaunchMode.externalApplication);
      } else {
        // Fallback to web
        final Uri webSignUri = Uri.parse(
          'https://phantom.app/ul/v1/signMessage?message=${Uri.encodeComponent(message)}'
        );
        _logger.phantomSign('sign_web_fallback_used');
        await launchUrl(webSignUri, mode: LaunchMode.externalApplication);
      }
      
      // Mock successful signing
      await Future.delayed(const Duration(seconds: 3));
      const String mockSignature = 'MockPhantomSignature123456789ABCDEF';
      
      _status = 'Message signed successfully';
      log('Message signed: $mockSignature');
      _logger.phantomSign('message_signed_successfully', signature: mockSignature);
      return mockSignature;
      
    } catch (e) {
      _status = 'Failed to sign message: $e';
      log('Message signing error: $e');
      _logger.phantomSign('message_signing_failed', error: e.toString());
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
        _logger.phantomTransaction('transaction_attempt_not_connected');
        throw Exception('Wallet not connected');
      }

      _status = 'Opening Phantom for transaction...';
      _logger.phantomTransaction('transaction_started', toAddress: toAddress, amount: amount);
      
      // Convert SOL to lamports (1 SOL = 1,000,000,000 lamports)
      final int lamports = (amount * 1000000000).round();
      
      // Create transaction deep link
      final Uri transactionUri = Uri.parse(
        'phantom://v1/signAndSendTransaction?'
        'transaction=${Uri.encodeComponent(_createMockTransaction(toAddress, lamports))}&'
        'redirect_link=${Uri.encodeComponent('metamask-wallet-flutter://transaction')}'
      );
      
      log('Launching Phantom for transaction: $transactionUri');
      _logger.phantomTransaction('transaction_uri_generated');
      
      if (await canLaunchUrl(transactionUri)) {
        _logger.phantomTransaction('launching_phantom_for_transaction');
        await launchUrl(transactionUri, mode: LaunchMode.externalApplication);
      } else {
        // Fallback to web
        const String webTransactionUrl = 'https://phantom.app/ul/v1/signAndSendTransaction';
        _logger.phantomTransaction('transaction_web_fallback_used');
        await launchUrl(Uri.parse(webTransactionUrl), mode: LaunchMode.externalApplication);
      }
      
      // Mock successful transaction
      await Future.delayed(const Duration(seconds: 4));
      const String mockTxSignature = 'MockTransactionSignature123456789ABCDEF';
      
      _status = 'Transaction sent successfully';
      log('Transaction signature: $mockTxSignature');
      _logger.phantomTransaction('transaction_completed_successfully', signature: mockTxSignature);
      return mockTxSignature;
      
    } catch (e) {
      _status = 'Failed to send transaction: $e';
      log('Transaction error: $e');
      _logger.phantomTransaction('transaction_failed', error: e.toString());
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
    _logger.phantomConnection('status_updated', uri: newStatus);
    log('Phantom service status updated: $newStatus');
  }

  // Check if Phantom app is installed
  Future<bool> isPhantomInstalled() async {
    try {
      _logger.phantomConnection('checking_phantom_installation');
      final isInstalled = await canLaunchUrl(Uri.parse('phantom://'));
      _logger.phantomConnection('phantom_installation_check_result', canLaunch: isInstalled);
      
      log('Phantom installation check: $isInstalled');
      return isInstalled;
    } catch (e) {
      log('Error checking Phantom installation: $e');
      _logger.phantomConnection('phantom_installation_check_error', error: e.toString());
      return false;
    }
  }

  // Open Phantom app store page
  Future<void> installPhantom() async {
    try {
      _logger.phantomConnection('phantom_install_redirect_initiated');
      
      const String playStoreUrl = 'https://play.google.com/store/apps/details?id=app.phantom';
      const String appStoreUrl = 'https://apps.apple.com/app/phantom-solana-wallet/id1598432977';
      
      // Try Play Store first (Android)
      if (await canLaunchUrl(Uri.parse(playStoreUrl))) {
        await launchUrl(Uri.parse(playStoreUrl), mode: LaunchMode.externalApplication);
        _logger.phantomConnection('phantom_play_store_opened');
      } else {
        // Fallback to App Store
        await launchUrl(Uri.parse(appStoreUrl), mode: LaunchMode.externalApplication);
        _logger.phantomConnection('phantom_app_store_opened');
      }
    } catch (e) {
      log('Error opening app store: $e');
      _logger.phantomConnection('phantom_store_redirect_failed', error: e.toString());
      rethrow;
    }
  }
}