import 'dart:convert';
import 'dart:developer' as dev;
import 'package:http/http.dart' as http;

class RemoteLogger {
  static RemoteLogger? _instance;
  static RemoteLogger get instance => _instance ??= RemoteLogger._();

  RemoteLogger._();

  static const String _baseUrl = 'https://gunsiya.com/console';
  static const int _maxRetries = 3;
  static const Duration _timeout = Duration(seconds: 5);

  // Device info for context
  String? _deviceId;
  String? _appVersion;

  // Initialize logger with device info
  void initialize({
    String? deviceId,
    String? appVersion,
  }) {
    _deviceId = deviceId ?? 'Unknown';
    _appVersion = appVersion ?? '1.1.0';
    
    // Test connection
    log('RemoteLogger', 'Initialized', {
      'deviceId': _deviceId,
      'appVersion': _appVersion,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  // Log different types of events
  void log(String service, String event, [Map<String, dynamic>? data]) {
    _sendLog('LOG', service, event, data);
  }

  void error(String service, String error, [Map<String, dynamic>? data]) {
    _sendLog('ERROR', service, error, data);
  }

  void debug(String service, String message, [Map<String, dynamic>? data]) {
    _sendLog('DEBUG', service, message, data);
  }

  void phantom(String event, [Map<String, dynamic>? data]) {
    _sendLog('PHANTOM', 'phantom_wallet', event, data);
  }

  void metamask(String event, [Map<String, dynamic>? data]) {
    _sendLog('METAMASK', 'metamask_wallet', event, data);
  }

  // Internal method to send logs
  Future<void> _sendLog(
    String level,
    String service,
    String message,
    Map<String, dynamic>? data,
  ) async {
    try {
      // Also log locally for fallback
      dev.log('[$level] $service: $message', 
               name: 'RemoteLogger',
               error: data);

      final logData = {
        'timestamp': DateTime.now().toIso8601String(),
        'level': level,
        'service': service,
        'message': message,
        'data': data ?? {},
        'device': {
          'id': _deviceId,
          'version': _appVersion,
          'platform': 'flutter_android',
        },
        'session': DateTime.now().millisecondsSinceEpoch.toString(),
      };

      await _postWithRetry(logData);

    } catch (e) {
      // Fail silently for logging errors to avoid infinite loops
      dev.log('Failed to send remote log: $e', name: 'RemoteLogger');
    }
  }

  // Send HTTP POST with retry logic
  Future<void> _postWithRetry(Map<String, dynamic> logData) async {
    int retryCount = 0;
    
    while (retryCount < _maxRetries) {
      try {
        final response = await http.post(
          Uri.parse(_baseUrl),
          headers: {
            'Content-Type': 'application/json',
            'User-Agent': 'MetaMaskFlutterApp/${_appVersion ?? '1.1.0'}',
            'X-App-Version': _appVersion ?? '1.1.0',
            'X-Device-ID': _deviceId ?? 'unknown',
          },
          body: json.encode(logData),
        ).timeout(_timeout);

        if (response.statusCode >= 200 && response.statusCode < 300) {
          // Success
          return;
        } else {
          throw Exception('HTTP ${response.statusCode}: ${response.body}');
        }

      } catch (e) {
        retryCount++;
        if (retryCount >= _maxRetries) {
          dev.log('Remote logging failed after $retryCount attempts: $e', 
                  name: 'RemoteLogger');
          break;
        }
        
        // Wait before retry with exponential backoff
        await Future.delayed(Duration(milliseconds: 100 * (retryCount * retryCount)));
      }
    }
  }

  // Specific methods for wallet debugging
  void phantomConnection(String event, {
    String? uri,
    String? error,
    bool? canLaunch,
    String? fallback,
    String? account,
  }) {
    phantom('connection_$event', {
      'uri': uri,
      'error': error,
      'canLaunch': canLaunch,
      'fallback': fallback,
      'account': account,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  void phantomTransaction(String event, {
    String? toAddress,
    double? amount,
    String? signature,
    String? error,
  }) {
    phantom('transaction_$event', {
      'toAddress': toAddress,
      'amount': amount,
      'signature': signature,
      'error': error,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  void phantomSign(String event, {
    String? message,
    String? signature,
    String? error,
  }) {
    phantom('sign_$event', {
      'message': message,
      'signature': signature,
      'error': error,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  void metamaskConnection(String event, {
    String? uri,
    String? error,
    String? account,
    String? session,
  }) {
    metamask('connection_$event', {
      'uri': uri,
      'error': error,
      'account': account,
      'session': session,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  // Batch logging for multiple events
  void logBatch(List<Map<String, dynamic>> logs) {
    for (final logEntry in logs) {
      _sendLog(
        logEntry['level'] ?? 'LOG',
        logEntry['service'] ?? 'unknown',
        logEntry['message'] ?? '',
        logEntry['data'],
      );
    }
  }

  // Test connection to remote server
  Future<bool> testConnection() async {
    try {
      final response = await http.get(
        Uri.parse('https://gunsiya.com'),
        headers: {'User-Agent': 'MetaMaskFlutterApp/${_appVersion ?? '1.1.0'}'},
      ).timeout(_timeout);
      
      final isConnected = response.statusCode >= 200 && response.statusCode < 400;
      log('RemoteLogger', 'Connection test', {
        'success': isConnected,
        'statusCode': response.statusCode,
      });
      
      return isConnected;
    } catch (e) {
      error('RemoteLogger', 'Connection test failed', {'error': e.toString()});
      return false;
    }
  }

  // Log app lifecycle events
  void appLifecycle(String event) {
    log('App', event, {
      'timestamp': DateTime.now().toIso8601String(),
      'deviceId': _deviceId,
      'version': _appVersion,
    });
  }

  // Clear any cached logs (if implementing offline storage later)
  void clearLogs() {
    log('RemoteLogger', 'Logs cleared');
  }
}