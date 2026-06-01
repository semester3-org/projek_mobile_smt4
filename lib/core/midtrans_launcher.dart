import 'package:url_launcher/url_launcher.dart';

Future<bool> launchMidtransPaymentUrl(String url) async {
  final uri = Uri.tryParse(url.trim());
  if (uri == null || !uri.hasScheme) return false;

  final config = const WebViewConfiguration(enableJavaScript: true);

  if (await _tryLaunchMidtransUri(
    uri,
    LaunchMode.inAppBrowserView,
    config,
  )) {
    return true;
  }

  if (await _tryLaunchMidtransUri(
    uri,
    LaunchMode.inAppWebView,
    config,
  )) {
    return true;
  }

  return _tryLaunchMidtransUri(
    uri,
    LaunchMode.platformDefault,
    config,
  );
}

Future<bool> _tryLaunchMidtransUri(
  Uri uri,
  LaunchMode mode,
  WebViewConfiguration config,
) async {
  try {
    return launchUrl(uri, mode: mode, webViewConfiguration: config);
  } catch (_) {
    return false;
  }
}
