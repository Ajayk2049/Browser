import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

/// Controller for interacting with native Mozilla GeckoView.
class GeckoBrowserController {
  MethodChannel? _channel;

  void _attach(int viewId) {
    _channel = MethodChannel('com.dab/geckoview_$viewId');
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

/// Native AndroidView embedding official Mozilla GeckoView with Hybrid Composition.
class GeckoBrowserView extends StatefulWidget {
  final String initialUrl;
  final GeckoBrowserController controller;
  final ValueChanged<String>? onPageStarted;
  final ValueChanged<bool>? onPageFinished;
  final ValueChanged<int>? onProgressChanged;
  final ValueChanged<String>? onLocationChanged;
  final ValueChanged<String>? onTitleChanged;
  final ValueChanged<bool>? onCanGoBack;
  final ValueChanged<bool>? onCanGoForward;
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
    this.onCanGoBack,
    this.onCanGoForward,
    this.onWebResourceError,
  });

  @override
  State<GeckoBrowserView> createState() => _GeckoBrowserViewState();
}

class _GeckoBrowserViewState extends State<GeckoBrowserView> {
  MethodChannel? _channel;

  void _onPlatformViewCreated(int id) {
    widget.controller._attach(id);
    _channel = MethodChannel('com.dab/geckoview_$id')
      ..setMethodCallHandler(_handleMethodCall);
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    final args = (call.arguments as Map?) ?? const {};
    switch (call.method) {
      case 'onPageStart':
        widget.onPageStarted?.call(args['url'] as String? ?? '');
        break;
      case 'onPageStop':
        widget.onPageFinished?.call(args['success'] as bool? ?? true);
        break;
      case 'onProgressChange':
        widget.onProgressChanged?.call((args['progress'] as num?)?.toInt() ?? 0);
        break;
      case 'onLocationChange':
        widget.onLocationChanged?.call(args['url'] as String? ?? '');
        break;
      case 'onTitleChange':
        widget.onTitleChanged?.call(args['title'] as String? ?? '');
        break;
      case 'onCanGoBack':
        widget.onCanGoBack?.call(args['canGoBack'] as bool? ?? false);
        break;
      case 'onCanGoForward':
        widget.onCanGoForward?.call(args['canGoForward'] as bool? ?? false);
        break;
      case 'onWebResourceError':
        widget.onWebResourceError?.call(
          args['uri'] as String? ?? '',
          (args['code'] as num?)?.toInt() ?? 0,
          args['category'] as String? ?? '',
        );
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

    const viewType = 'com.dab/geckoview';
    final creationParams = {'initialUrl': widget.initialUrl};

    return PlatformViewLink(
      viewType: viewType,
      surfaceFactory: (context, controller) {
        return AndroidViewSurface(
          controller: controller as AndroidViewController,
          gestureRecognizers: const <Factory<OneSequenceGestureRecognizer>>{
            Factory<EagerGestureRecognizer>(EagerGestureRecognizer.new),
          },
          hitTestBehavior: PlatformViewHitTestBehavior.opaque,
        );
      },
      onCreatePlatformView: (params) {
        return PlatformViewsService.initExpensiveAndroidView(
          id: params.id,
          viewType: viewType,
          layoutDirection: TextDirection.ltr,
          creationParams: creationParams,
          creationParamsCodec: const StandardMessageCodec(),
          onFocus: () => params.onFocusChanged(true),
        )
          ..addOnPlatformViewCreatedListener((id) {
            params.onPlatformViewCreated(id);
            _onPlatformViewCreated(id);
          })
          ..create();
      },
    );
  }
}
