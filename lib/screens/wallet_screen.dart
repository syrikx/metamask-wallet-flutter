import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/wallet_service.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  final WalletService _walletService = WalletService.instance;
  bool _isConnecting = false;
  String _balance = '0.0';
  String _signedMessage = '';

  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _toAddressController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _checkConnection();
  }

  void _checkConnection() {
    if (_walletService.isConnected) {
      _loadBalance();
    }
  }

  Future<void> _connectWallet() async {
    setState(() {
      _isConnecting = true;
    });

    try {
      await _walletService.connectWallet();
      _showSnackBar('지갑 연결을 시도 중입니다. MetaMask 앱에서 연결을 승인해주세요.');
      
      // Wait for connection and then load balance
      await Future.delayed(const Duration(seconds: 3));
      if (_walletService.isConnected) {
        await _loadBalance();
        _showSnackBar('지갑이 성공적으로 연결되었습니다!');
      }
    } catch (e) {
      _showSnackBar('지갑 연결 실패: $e');
    } finally {
      setState(() {
        _isConnecting = false;
      });
    }
  }

  Future<void> _disconnectWallet() async {
    try {
      await _walletService.disconnect();
      setState(() {
        _balance = '0.0';
        _signedMessage = '';
      });
      _showSnackBar('지갑 연결이 해제되었습니다.');
    } catch (e) {
      _showSnackBar('지갑 연결 해제 실패: $e');
    }
  }

  Future<void> _loadBalance() async {
    try {
      final balance = await _walletService.getBalance();
      setState(() {
        _balance = balance;
      });
    } catch (e) {
      _showSnackBar('잔고 조회 실패: $e');
    }
  }

  Future<void> _signMessage() async {
    if (_messageController.text.isEmpty) {
      _showSnackBar('서명할 메시지를 입력해주세요.');
      return;
    }

    try {
      final signature = await _walletService.signMessage(_messageController.text);
      setState(() {
        _signedMessage = signature;
      });
      _showSnackBar('메시지가 성공적으로 서명되었습니다!');
    } catch (e) {
      _showSnackBar('메시지 서명 실패: $e');
    }
  }

  Future<void> _sendTransaction() async {
    if (_toAddressController.text.isEmpty || _amountController.text.isEmpty) {
      _showSnackBar('받는 주소와 금액을 입력해주세요.');
      return;
    }

    try {
      final valueInWei = (double.parse(_amountController.text) * 1e18).toInt().toString();
      final txHash = await _walletService.sendTransaction(
        to: _toAddressController.text,
        value: '0x${valueInWei.substring(0, valueInWei.length - 2)}',
      );
      _showSnackBar('트랜잭션이 전송되었습니다! 해시: ${txHash.substring(0, 20)}...');
      await _loadBalance(); // Refresh balance
    } catch (e) {
      _showSnackBar('트랜잭션 전송 실패: $e');
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    _showSnackBar('클립보드에 복사되었습니다.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MetaMask 지갑'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Connection Status Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Icon(
                      _walletService.isConnected ? Icons.account_balance_wallet : Icons.wallet,
                      size: 48,
                      color: _walletService.isConnected ? Colors.green : Colors.grey,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _walletService.isConnected ? '지갑 연결됨' : '지갑 연결 안됨',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    if (_walletService.isConnected) ...[
                      Text(
                        '주소: ${_walletService.currentAccount?.substring(0, 20)}...',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '잔고: $_balance ETH',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                    const SizedBox(height: 16),
                    if (!_walletService.isConnected)
                      ElevatedButton(
                        onPressed: _isConnecting ? null : _connectWallet,
                        child: _isConnecting
                            ? const CircularProgressIndicator()
                            : const Text('MetaMask 연결'),
                      )
                    else
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _loadBalance,
                              child: const Text('잔고 새로고침'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _disconnectWallet,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('연결 해제'),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Sign Message Section
            if (_walletService.isConnected) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '메시지 서명',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _messageController,
                        decoration: const InputDecoration(
                          labelText: '서명할 메시지',
                          border: OutlineInputBorder(),
                          hintText: '예: Hello MetaMask!',
                        ),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _signMessage,
                        child: const Text('메시지 서명'),
                      ),
                      if (_signedMessage.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('서명 결과:'),
                              const SizedBox(height: 4),
                              GestureDetector(
                                onTap: () => _copyToClipboard(_signedMessage),
                                child: Text(
                                  _signedMessage.length > 100
                                      ? '${_signedMessage.substring(0, 100)}...'
                                      : _signedMessage,
                                  style: const TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                '탭하여 복사',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Send Transaction Section
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ETH 전송',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _toAddressController,
                        decoration: const InputDecoration(
                          labelText: '받는 주소',
                          border: OutlineInputBorder(),
                          hintText: '0x...',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _amountController,
                        decoration: const InputDecoration(
                          labelText: '금액 (ETH)',
                          border: OutlineInputBorder(),
                          hintText: '0.001',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _sendTransaction,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('ETH 전송'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _toAddressController.dispose();
    _amountController.dispose();
    super.dispose();
  }
}