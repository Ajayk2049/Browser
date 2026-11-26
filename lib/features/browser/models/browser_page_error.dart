/// Structured page-load error details mapped from GeckoView WebRequestError.
class BrowserPageError {
  final String uri;
  final String errorKey;
  final String categoryName;
  final int code;

  const BrowserPageError({
    required this.uri,
    required this.errorKey,
    required this.categoryName,
    required this.code,
  });

  bool get isSecurityError =>
      errorKey == 'SECURITY_SSL' ||
      errorKey == 'SECURITY_BAD_CERT' ||
      errorKey == 'HTTPS_ONLY' ||
      errorKey == 'BAD_HSTS_CERT';

  String get insecureFallbackUrl {
    if (uri.toLowerCase().startsWith('https://')) {
      return 'http://${uri.substring(8)}';
    }
    return uri;
  }

  String get host {
    final parsed = Uri.tryParse(uri);
    if (parsed != null && parsed.host.isNotEmpty) return parsed.host;
    return uri.isNotEmpty ? uri : 'Unknown address';
  }

  String get title {
    switch (errorKey) {
      case 'OFFLINE':
        return 'No internet connection';
      case 'UNKNOWN_HOST':
        return "This site can't be reached";
      case 'NET_TIMEOUT':
        return 'Connection timed out';
      case 'CONNECTION_REFUSED':
        return 'Connection refused';
      case 'NET_RESET':
      case 'NET_INTERRUPT':
        return 'Connection interrupted';
      case 'MALFORMED_URI':
      case 'UNSUPPORTED_PROTOCOL':
        return 'Invalid web address';
      case 'SECURITY_SSL':
      case 'SECURITY_BAD_CERT':
      case 'HTTPS_ONLY':
      case 'BAD_HSTS_CERT':
        return 'Secure connection failed';
      case 'REDIRECT_LOOP':
        return 'Too many redirects';
      case 'UNKNOWN_PROXY_HOST':
      case 'PROXY_CONNECTION_REFUSED':
        return 'Proxy connection failed';
      case 'SAFEBROWSING':
        return 'Deceptive or unsafe site';
      case 'CONTENT_CRASHED':
        return 'Page crashed';
      default:
        return 'Unable to load page';
    }
  }

  String get description {
    switch (errorKey) {
      case 'OFFLINE':
        return 'Your device appears to be offline. Check your Wi-Fi or mobile data connection and try again.';
      case 'UNKNOWN_HOST':
        return "$host's server IP address could not be found. Check for typos in the address or verify your DNS connection.";
      case 'NET_TIMEOUT':
        return '$host took too long to respond. The server may be overloaded or your connection is unstable.';
      case 'CONNECTION_REFUSED':
        return '$host refused to connect. The server may be down or blocking requests on this port.';
      case 'NET_RESET':
      case 'NET_INTERRUPT':
        return 'The network connection to $host was unexpectedly closed before the page finished loading.';
      case 'MALFORMED_URI':
      case 'UNSUPPORTED_PROTOCOL':
        return 'The address "$uri" is not formatted correctly or uses an unsupported protocol.';
      case 'SECURITY_SSL':
      case 'SECURITY_BAD_CERT':
      case 'HTTPS_ONLY':
      case 'BAD_HSTS_CERT':
        return "A secure HTTPS connection to $host couldn't be established because its security certificate is invalid, untrusted, or HTTPS is not supported.";
      case 'REDIRECT_LOOP':
        return '$host redirected you too many times. Try clearing cookies for this site or reloading.';
      case 'UNKNOWN_PROXY_HOST':
      case 'PROXY_CONNECTION_REFUSED':
        return 'The browser could not connect through the configured proxy server.';
      case 'SAFEBROWSING':
        return '$host was flagged as potentially harmful or deceptive.';
      case 'CONTENT_CRASHED':
        return 'The rendering process for this tab stopped unexpectedly. Tap Reload to restore the page.';
      default:
        return 'Something went wrong while trying to load $host. Check your connection and try reloading.';
    }
  }

  String get errorCodeLabel => '$categoryName · ERR_$errorKey ($code)';
}
