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
        primarySwatch: MaterialColor(
          0xFF1053A2,
          <int, Color>{
            50: Color(0xFFE3EDF7),
            100: Color(0xFFBAD2EB),
            200: Color(0xFF8DB4DE),
            300: Color(0xFF5F96D1),
            400: Color(0xFF3C80C7),
            500: Color(0xFF1053A2),
            600: Color(0xFF0E4C9A),
            700: Color(0xFF0C4290),
            800: Color(0xFF093986),
            900: Color(0xFF052974),
          },
        ),
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
  late StreamSubscription<ConnectivityResult> _connectivitySubscription;
  bool _canGoBack = false;
  DateTime? _lastBackPress;

  final String _webUrl = 'https://airvalencia.com';

  @override
  void initState() {
    super.initState();
    _initializeWebView();
    _checkConnectivity();
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
            if (progress == 100) {
              setState(() {
                _isLoading = false;
              });
            }
          },
          onPageStarted: (String url) {
            setState(() {
              _isLoading = true;
            });
          },
          onPageFinished: (String url) async {
            setState(() {
              _isLoading = false;
            });
            _canGoBack = await _controller.canGoBack();
            setState(() {});
          },
          onWebResourceError: (WebResourceError error) {
            print('WebView Error: ${error.description}');
            setState(() {
              _isLoading = false;
            });
            // Don't immediately set _hasInternet to false, let connectivity check handle it
            _checkConnectivity();
          },
        ),
      );
  }

  Future<void> _checkConnectivity() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    bool hasConnection = connectivityResult != ConnectivityResult.none;
    
    // Additional real internet check
    if (hasConnection) {
      try {
        final result = await InternetAddress.lookup('google.com');
        hasConnection = result.isNotEmpty && result[0].rawAddress.isNotEmpty;
      } catch (_) {
        hasConnection = false;
      }
    }
    
    setState(() {
      _hasInternet = hasConnection;
    });

    if (_hasInternet) {
      _loadWebPage();
    }
  }

  void _listenToConnectivityChanges() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((
      ConnectivityResult result,
    ) {
      final hasInternet = result != ConnectivityResult.none;
      setState(() {
        _hasInternet = hasInternet;
      });

      if (hasInternet && !_isLoading) {
        _loadWebPage();
      }
    });
  }

  void _loadWebPage() {
    _controller.loadRequest(Uri.parse(_webUrl));
  }

  @override
  void dispose() {
    _connectivitySubscription.cancel();
    super.dispose();
  }

  Future<bool> _onWillPop() async {
    // If there's internet and webview can go back, handle webview navigation first
    if (_hasInternet && _canGoBack) {
      _controller.goBack();
      return false;
    }

    // Handle app exit confirmation
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
        appBar: AppBar(
          title: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF1053A2),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: Image.asset(
                    'assets/logo.png',
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(
                        Icons.flight,
                        size: 20,
                        color: Color(0xFF1053A2),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Air Valencia',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF1053A2),
          elevation: 0,
          systemOverlayStyle: SystemUiOverlayStyle.light,
          automaticallyImplyLeading: false,
          actions: [
            if (_hasInternet && !_isLoading)
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white),
                onPressed: () {
                  _controller.reload();
                },
              ),
          ],
        ),
        body: _hasInternet ? _buildWebView() : _buildNoInternetScreen(),
      ),
    );
  }

  Widget _buildWebView() {
    return Stack(
      children: [
        WebViewWidget(controller: _controller),
        if (_isLoading)
          const Center(
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
              _checkConnectivity();
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
