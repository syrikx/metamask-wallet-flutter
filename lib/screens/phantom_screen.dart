import 'dart:developer';
import 'package:flutter/material.dart';
import '../services/phantom_service.dart';

class PhantomScreen extends StatefulWidget {
  const PhantomScreen({super.key});

  @override
  State<PhantomScreen> createState() => _PhantomScreenState();
}

class _PhantomScreenState extends State<PhantomScreen> {
  late final Future<void> _future;
  final PhantomService _phantomService = PhantomService.instance;
  String? _balance;
  bool _isLoading = false;
  bool _isPhantomInstalled = false;

  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _toAddressController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _future = _initializePhantom();
    _messageController.text = 'Hello Phantom Wallet!';
    _amountController.text = '0.001';
    _toAddressController.text = 'SampleSolanaAddress123456789';
  }
  
  Future<void> _initializePhantom() async {
    await _phantomService.initialize();
    _isPhantomInstalled = await _phantomService.isPhantomInstalled();
    setState(() {});
  }

  @override
  void dispose() {
    _messageController.dispose();
    _toAddressController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await _phantomService.connectWallet();
      await _updateBalance();
      setState(() {});
    } catch (e) {
      _showSnackBar('연결 실패: $e');
      log('Connection error: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _disconnect() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await _phantomService.disconnect();
      setState(() {
        _balance = null;
      });
      _showSnackBar('Phantom 지갑 연결이 해제되었습니다');
    } catch (e) {
      _showSnackBar('연결 해제 실패: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _updateBalance() async {
    if (!_phantomService.isConnected) return;

    try {
      final balance = await _phantomService.getBalance();
      setState(() {
        _balance = balance;
      });
    } catch (e) {
      log('Balance update error: $e');
    }
  }

  Future<void> _signMessage() async {
    if (_messageController.text.isEmpty) {
      _showSnackBar('서명할 메시지를 입력해주세요');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final signature = await _phantomService.signMessage(_messageController.text);
      _showSignatureDialog('메시지 서명', signature);
      _showSnackBar('메시지가 성공적으로 서명되었습니다');
    } catch (e) {
      _showSnackBar('메시지 서명 실패: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _sendTransaction() async {
    if (_toAddressController.text.isEmpty || _amountController.text.isEmpty) {
      _showSnackBar('받는 주소와 전송 금액을 입력해주세요');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final amount = double.parse(_amountController.text);
      final signature = await _phantomService.sendTransaction(
        toAddress: _toAddressController.text,
        amount: amount,
      );
      
      _showSignatureDialog('거래 서명', signature);
      _showSnackBar('거래가 성공적으로 전송되었습니다');
      await _updateBalance();
    } catch (e) {
      _showSnackBar('거래 전송 실패: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _showSignatureDialog(String title, String signature) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SelectableText(signature),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionSection() {
    if (_phantomService.isConnected) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green[200]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '지갑 연결됨',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '주소: ${_phantomService.currentAccount ?? 'Unknown'}',
                  style: const TextStyle(fontSize: 12),
                ),
                if (_balance != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    '잔액: $_balance SOL',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _disconnect,
                  icon: const Icon(Icons.logout),
                  label: const Text('연결 해제'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _updateBalance,
                  icon: const Icon(Icons.refresh),
                  label: const Text('잔액 새로고침'),
                ),
              ),
            ],
          ),
        ],
      );
    }

    // Not connected - show connection options
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!_isPhantomInstalled) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange[200]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Phantom 앱이 설치되지 않았습니다',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Phantom 지갑 기능을 사용하려면 앱을 먼저 설치해주세요.',
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () => _phantomService.installPhantom(),
                  icon: const Icon(Icons.download),
                  label: const Text('Phantom 설치'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        
        ElevatedButton.icon(
          onPressed: _isLoading ? null : _connect,
          icon: const Icon(Icons.wallet),
          label: Text(_isPhantomInstalled ? 'Phantom 연결' : 'Phantom 연결 (웹)'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.purple,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
        
        if (!_isPhantomInstalled) ...[
          const SizedBox(height: 8),
          const Text(
            '* Phantom 앱이 없으면 웹 브라우저로 연결됩니다',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }

  Widget _buildActionSection() {
    if (!_phantomService.isConnected) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(height: 32),
        
        // Message Signing Section
        const Text(
          '메시지 서명',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _messageController,
          decoration: const InputDecoration(
            labelText: '서명할 메시지',
            border: OutlineInputBorder(),
            hintText: '메시지를 입력하세요',
          ),
          maxLines: 2,
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: _isLoading ? null : _signMessage,
          icon: const Icon(Icons.edit),
          label: const Text('메시지 서명'),
        ),
        
        const SizedBox(height: 24),
        
        // Transaction Section
        const Text(
          'SOL 전송',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _toAddressController,
          decoration: const InputDecoration(
            labelText: '받는 주소',
            border: OutlineInputBorder(),
            hintText: '받는 사람의 Solana 주소',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _amountController,
          decoration: const InputDecoration(
            labelText: '전송 금액 (SOL)',
            border: OutlineInputBorder(),
            hintText: '0.001',
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: _isLoading ? null : _sendTransaction,
          icon: const Icon(Icons.send),
          label: const Text('SOL 전송'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusSection() {
    final String? currentStatus = _phantomService.status;
    
    if (currentStatus == null && !_isLoading) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Row(
        children: [
          if (_isLoading) ...[
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Text(
              currentStatus ?? (_isLoading ? '처리 중...' : ''),
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _builder(BuildContext context, AsyncSnapshot snapshot) {
    if (snapshot.connectionState != ConnectionState.done) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Phantom 지갑 초기화 중...'),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Phantom 지갑'),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
        actions: [
          if (_phantomService.isConnected)
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: _disconnect,
              tooltip: '연결 해제',
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildConnectionSection(),
            _buildActionSection(),
            _buildStatusSection(),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _future,
      builder: _builder,
    );
  }
}