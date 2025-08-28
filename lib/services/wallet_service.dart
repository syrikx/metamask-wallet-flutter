import 'dart:convert';
import 'dart:developer';
import 'package:url_launcher/url_launcher.dart';
import 'package:walletconnect_flutter_v2/walletconnect_flutter_v2.dart';
import 'package:http/http.dart' as http;

class WalletService {
  static WalletService? _instance;
  static WalletService get instance => _instance ??= WalletService._();

  WalletService._();

  Web3App? _web3App;
  String? _currentSession;
  String? _currentAccount;

  // Getters
  bool get isInitialized => _web3App != null;
  bool get isConnected => _currentSession != null && _currentAccount != null;
  String? get currentAccount => _currentAccount;
  String? get currentSession => _currentSession;

  // Initialize WalletConnect
  Future<void> initialize() async {
    try {
      _web3App = await Web3App.createInstance(
        projectId: 'YOUR_PROJECT_ID', // Replace with your WalletConnect project ID
        metadata: const PairingMetadata(
          name: 'MetaMask Flutter App',
          description: 'A simple Flutter app with MetaMask integration',
          url: 'https://your-app-url.com',
          icons: ['https://your-app-url.com/icon.png'],
        ),
      );
      
      _web3App!.onSessionConnect.subscribe(_onSessionConnect);
      _web3App!.onSessionDelete.subscribe(_onSessionDelete);
      
      log('WalletConnect initialized successfully');
    } catch (e) {
      log('Failed to initialize WalletConnect: $e');
      rethrow;
    }
  }

  // Connect to MetaMask
  Future<void> connectWallet() async {
    try {
      if (_web3App == null) {
        throw Exception('WalletConnect not initialized');
      }

      // Create connection URI
      final ConnectResponse connectResponse = await _web3App!.connect(
        requiredNamespaces: {
          'eip155': const RequiredNamespace(
            chains: ['eip155:1'], // Ethereum mainnet
            methods: [
              'eth_sendTransaction',
              'eth_signTransaction',
              'eth_sign',
              'personal_sign',
              'eth_signTypedData',
            ],
            events: ['chainChanged', 'accountsChanged'],
          ),
        },
      );

      final uri = connectResponse.uri;
      
      // Launch MetaMask with the connection URI
      await _launchMetaMask(uri.toString());
      
    } catch (e) {
      log('Failed to connect wallet: $e');
      rethrow;
    }
  }

  // Launch MetaMask app
  Future<void> _launchMetaMask(String wcUri) async {
    try {
      // Try to open MetaMask mobile app first
      final metamaskUri = 'metamask://wc?uri=${Uri.encodeComponent(wcUri)}';
      final canLaunchMetaMask = await canLaunchUrl(Uri.parse(metamaskUri));
      
      if (canLaunchMetaMask) {
        await launchUrl(Uri.parse(metamaskUri));
      } else {
        // Fallback to browser
        await launchUrl(Uri.parse(wcUri));
      }
    } catch (e) {
      log('Failed to launch MetaMask: $e');
      // Fallback to copying URL to clipboard or showing it to user
      rethrow;
    }
  }

  // Disconnect wallet
  Future<void> disconnect() async {
    try {
      if (_currentSession != null && _web3App != null) {
        await _web3App!.disconnectSession(
          topic: _currentSession!,
          reason: const WalletConnectError(
            code: 6000,
            message: 'User disconnected',
          ),
        );
      }
      _currentSession = null;
      _currentAccount = null;
    } catch (e) {
      log('Failed to disconnect: $e');
      rethrow;
    }
  }

  // Send transaction
  Future<String> sendTransaction({
    required String to,
    required String value,
    String? data,
  }) async {
    try {
      if (!isConnected || _web3App == null || _currentSession == null) {
        throw Exception('Wallet not connected');
      }

      final transaction = {
        'from': _currentAccount,
        'to': to,
        'value': value,
        'data': data ?? '0x',
      };

      final result = await _web3App!.request(
        topic: _currentSession!,
        chainId: 'eip155:1',
        request: SessionRequestParams(
          method: 'eth_sendTransaction',
          params: [transaction],
        ),
      );

      return result.toString();
    } catch (e) {
      log('Failed to send transaction: $e');
      rethrow;
    }
  }

  // Sign message
  Future<String> signMessage(String message) async {
    try {
      if (!isConnected || _web3App == null || _currentSession == null) {
        throw Exception('Wallet not connected');
      }

      final result = await _web3App!.request(
        topic: _currentSession!,
        chainId: 'eip155:1',
        request: SessionRequestParams(
          method: 'personal_sign',
          params: [message, _currentAccount],
        ),
      );

      return result.toString();
    } catch (e) {
      log('Failed to sign message: $e');
      rethrow;
    }
  }

  // Get balance
  Future<String> getBalance() async {
    try {
      if (!isConnected) {
        throw Exception('Wallet not connected');
      }

      final response = await http.post(
        Uri.parse('https://eth-mainnet.g.alchemy.com/v2/YOUR_ALCHEMY_KEY'), // Replace with your Alchemy key
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'jsonrpc': '2.0',
          'method': 'eth_getBalance',
          'params': [_currentAccount, 'latest'],
          'id': 1,
        }),
      );

      final data = jsonDecode(response.body);
      final balanceWei = BigInt.parse(data['result'].substring(2), radix: 16);
      final balanceEth = balanceWei / BigInt.from(1000000000000000000); // Convert Wei to ETH

      return balanceEth.toStringAsFixed(6);
    } catch (e) {
      log('Failed to get balance: $e');
      return '0.0';
    }
  }

  // Session connect callback
  void _onSessionConnect(SessionConnect? args) {
    if (args != null) {
      _currentSession = args.session.topic;
      _currentAccount = args.session.namespaces['eip155']?.accounts.first.split(':').last;
      log('Session connected: ${args.session.topic}');
      log('Account: $_currentAccount');
    }
  }

  // Session delete callback
  void _onSessionDelete(SessionDelete? args) {
    _currentSession = null;
    _currentAccount = null;
    log('Session deleted');
  }

  // Dispose
  void dispose() {
    _web3App?.onSessionConnect.unsubscribe(_onSessionConnect);
    _web3App?.onSessionDelete.unsubscribe(_onSessionDelete);
  }
}