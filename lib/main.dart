import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';
import 'dart:io';
import 'splash_screen.dart';

void main() {
  runApp(const AirValenciaApp());
}

class AirValenciaApp extends StatelessWidget {
  const AirValenciaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Air Valencia',
      theme: ThemeData(
        primaryColor: const Color(0xFF1053A2),
        useMaterial3: true,
      ),
      home: const SplashScreen(nextScreen: WebViewScreen()),
      debugShowCheckedModeBanner: false,
    );
  }
}

class WebViewScreen extends StatefulWidget {
  const WebViewScreen({super.key});

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _hasInternet = true;
  StreamSubscription? _connectivitySubscription;
  bool _canGoBack = false;
  DateTime? _lastBackPress;

  final String _webUrl = 'https://airvalencia.com';

  @override
  void initState() {
    super.initState();
    _initializeWebView();
    _checkInitialConnectivity();
    _listenToConnectivityChanges();
  }

  void _initializeWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setUserAgent('Mozilla/5.0 (Linux; Android 10; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.120 Mobile Safari/537.36')
      ..enableZoom(true)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            if (progress > 90) {
              if (mounted) setState(() => _isLoading = false);
            }
          },
          onPageStarted: (String url) {
            if (mounted) setState(() => _isLoading = true);
          },
          onPageFinished: (String url) async {
            if (mounted) setState(() => _isLoading = false);
            _canGoBack = await _controller.canGoBack();
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint('WebView Error: ${error.description}');
            if (mounted) setState(() => _isLoading = false);
          },
        ),
      );
  }

  Future<void> _checkInitialConnectivity() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    bool hasConnection = _isConnected(connectivityResult);
    
    if (hasConnection) {
      hasConnection = await _hasRealInternet();
    }
    
    if (mounted) {
      setState(() {
        _hasInternet = hasConnection;
      });
    }

    if (_hasInternet) {
      _loadWebPage();
    }
  }

  bool _isConnected(dynamic result) {
    if (result is List<ConnectivityResult>) {
      return result.isNotEmpty && !result.contains(ConnectivityResult.none);
    }
    return result != ConnectivityResult.none;
  }

  Future<bool> _hasRealInternet() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  void _listenToConnectivityChanges() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((result) async {
      final bool currentlyConnected = _isConnected(result);
      
      if (currentlyConnected && !_hasInternet) {
        final bool hasRealInternet = await _hasRealInternet();
        if (hasRealInternet) {
          if (mounted) {
            setState(() {
              _hasInternet = true;
            });
          }
          _loadWebPage();
        }
      } else if (!currentlyConnected && _hasInternet) {
        if (mounted) {
          setState(() {
            _hasInternet = false;
          });
        }
      }
    });
  }

  void _loadWebPage() {
    _controller.loadRequest(Uri.parse(_webUrl));
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  Future<bool> _onWillPop() async {
    if (_hasInternet && _canGoBack) {
      _controller.goBack();
      return false;
    }

    final now = DateTime.now();
    if (_lastBackPress == null ||
        now.difference(_lastBackPress!) > const Duration(seconds: 2)) {
      _lastBackPress = now;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Press back again to exit'),
          duration: Duration(seconds: 2),
          backgroundColor: Color(0xFF1053A2),
        ),
      );
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    // স্ট্যাটাস বার: নীল ব্যাকগ্রাউন্ড + সাদা আইকন
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Color(0xFF1053A2),           // নীল ব্যাকগ্রাউন্ড
      statusBarIconBrightness: Brightness.light,    // সাদা আইকন (Android)
      statusBarBrightness: Brightness.dark,         // সাদা আইকন (iOS)
    ));

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        if (!didPop) {
          bool shouldExit = await _onWillPop();
          if (shouldExit) {
            SystemNavigator.pop();
          }
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF1053A2), // SafeArea-র বাইরে নীল থাকবে
        body: SafeArea(
          // SafeArea নিশ্চিত করে কন্টেন্ট স্ট্যাটাস বারের নিচে থাকে
          child: _hasInternet
              ? _buildWebView()
              : _buildNoInternetScreen(),
        ),
      ),
    );
  }

  Widget _buildWebView() {
    return Stack(
      children: [
        WebViewWidget(controller: _controller),
        // লোডিং স্ক্রিন
        if (_isLoading)
          Container(
            color: Colors.white.withAlpha(230),
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1053A2)),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Loading Air Valencia...',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
        // ট্রান্সপ্যারেন্ট রিফ্রেশ বাটন — উপরে-ডান কোনায় overlay
        if (_hasInternet && !_isLoading)
          Positioned(
            top: 4,
            right: 4,
            child: Material(
              color: Colors.transparent, // ট্রান্সপ্যারেন্ট ব্যাকগ্রাউন্ড
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () {
                  _controller.reload();
                },
                child: const Padding(
                  padding: EdgeInsets.all(6),
                  child: Icon(
                    Icons.refresh,
                    color: Color(0xFF1053A2),
                    size: 22,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildNoInternetScreen() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.white,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.wifi_off, size: 100, color: Colors.grey),
          const SizedBox(height: 24),
          const Text(
            'No Internet Connection',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Please check your internet connection and try again.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () {
              _checkInitialConnectivity();
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Try Again'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1053A2),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
