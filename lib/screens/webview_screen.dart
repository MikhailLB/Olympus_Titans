import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class WebViewScreen extends StatefulWidget {
  final String url;
  final String title;

  const WebViewScreen({super.key, required this.url, required this.title});

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) => setState(() => _isLoading = true),
          onPageFinished: (_) => setState(() => _isLoading = false),
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050E1A),
      body: SafeArea(
        child: Column(
          children: [
            // Custom top bar
            Container(
              height: 56,
              decoration: const BoxDecoration(
                color: Color(0xFF0D1B2A),
                border: Border(
                  bottom: BorderSide(color: Color(0xFF1E3A5F), width: 1),
                ),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: const Color(0xFF1E3A5F),
                          width: 1.5,
                        ),
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: Color(0xFF4FC3F7),
                        size: 16,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    widget.title.toUpperCase(),
                    style: const TextStyle(
                      color: Color(0xFFC9A84C),
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2,
                    ),
                  ),
                  const Spacer(),
                  const SizedBox(width: 48),
                ],
              ),
            ),

            // WebView
            Expanded(
              child: Stack(
                children: [
                  WebViewWidget(controller: _controller),
                  if (_isLoading)
                    const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFFC9A84C),
                        strokeWidth: 2,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
