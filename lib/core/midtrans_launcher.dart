import 'package:url_launcher/url_launcher.dart';

Future<bool> launchMidtransPaymentUrl(String url) async {
  final uri = Uri.tryParse(url.trim());
  if (uri == null || !uri.hasScheme) return false;

  if (await _tryLaunchMidtransUri(uri, LaunchMode.inAppBrowserView)) {
    return true;
  }

  if (await _tryLaunchMidtransUri(uri, LaunchMode.inAppWebView)) {
    return true;
  }

  return _tryLaunchMidtransUri(uri, LaunchMode.platformDefault);
}

Future<bool> _tryLaunchMidtransUri(
  Uri uri,
  LaunchMode mode,
) async {
  try {
    return launchUrl(uri, mode: mode);
  } catch (_) {
    return false;
  }
}
