import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Controller for interacting with native Mozilla GeckoView.
/// Complies with rules.md §25.1, §25.2, §25.7, and §29.2 (< 200 lines).
class GeckoBrowserController {
  MethodChannel? _channel;

  void _attach(int viewId) {
    _channel = MethodChannel('com.yourdomain/geckoview_$viewId');
  }

  void _detach() {
    _channel = null;
  }

  Future<void> loadUrl(String url) async {
    await _channel?.invokeMethod('loadUrl', {'url': url});
  }

  Future<void> goBack() async {
    await _channel?.invokeMethod('goBack');
  }

  Future<void> goForward() async {
    await _channel?.invokeMethod('goForward');
  }

  Future<void> reload() async {
    await _channel?.invokeMethod('reload');
  }
}

/// Native AndroidView embedding official Mozilla GeckoView.
/// Replaces unmaintained third-party wrapper and solves the onWebResourceError blocking bug.
class GeckoBrowserView extends StatefulWidget {
  final String initialUrl;
  final GeckoBrowserController controller;
  final ValueChanged<String>? onPageStarted;
  final ValueChanged<bool>? onPageFinished;
  final ValueChanged<int>? onProgressChanged;
  final ValueChanged<String>? onLocationChanged;
  final ValueChanged<String>? onTitleChanged;
  final void Function(String uri, int code, String category)? onWebResourceError;

  const GeckoBrowserView({
    super.key,
    required this.initialUrl,
    required this.controller,
    this.onPageStarted,
    this.onPageFinished,
    this.onProgressChanged,
    this.onLocationChanged,
    this.onTitleChanged,
    this.onWebResourceError,
  });

  @override
  State<GeckoBrowserView> createState() => _GeckoBrowserViewState();
}

class _GeckoBrowserViewState extends State<GeckoBrowserView> {
  MethodChannel? _channel;

  void _onPlatformViewCreated(int id) {
    widget.controller._attach(id);
    _channel = MethodChannel('com.yourdomain/geckoview_$id')
      ..setMethodCallHandler(_handleMethodCall);
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    final args = (call.arguments as Map?) ?? const {};
    switch (call.method) {
      case 'onPageStart':
        final url = args['url'] as String? ?? '';
        widget.onPageStarted?.call(url);
        break;
      case 'onPageStop':
        final success = args['success'] as bool? ?? true;
        widget.onPageFinished?.call(success);
        break;
      case 'onProgressChange':
        final progress = (args['progress'] as num?)?.toInt() ?? 0;
        widget.onProgressChanged?.call(progress);
        break;
      case 'onLocationChange':
        final url = args['url'] as String? ?? '';
        widget.onLocationChanged?.call(url);
        break;
      case 'onTitleChange':
        final title = args['title'] as String? ?? '';
        widget.onTitleChanged?.call(title);
        break;
      case 'onWebResourceError':
        final uri = args['uri'] as String? ?? '';
        final code = (args['code'] as num?)?.toInt() ?? 0;
        final category = args['category'] as String? ?? '';
        widget.onWebResourceError?.call(uri, code, category);
        break;
    }
  }

  @override
  void dispose() {
    _channel?.setMethodCallHandler(null);
    widget.controller._detach();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return const Center(child: Text('GeckoView is supported on Android only'));
    }

    return AndroidView(
      viewType: 'com.yourdomain/geckoview',
      creationParams: {'initialUrl': widget.initialUrl},
      creationParamsCodec: const StandardMessageCodec(),
      onPlatformViewCreated: _onPlatformViewCreated,
    );
  }
}

