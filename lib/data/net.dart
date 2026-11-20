import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// True for errors that mean "no connection" (not a bad response).
bool isNetworkError(Object e) => e is SocketException || e is TimeoutException || e is http.ClientException || e is HandshakeException;

/// Connection status, learned passively from map tiles and route requests.
/// While offline it probes every few seconds and flips back on its own.
class NetStatus extends ChangeNotifier {
  bool online = true;
  Timer? _probe;
  bool _checking = false;

  void report(bool ok) {
    if (ok == online) return;
    online = ok;
    _probe?.cancel();
    if (!ok) _probe = Timer.periodic(const Duration(seconds: 6), (_) => retry());
    notifyListeners();
  }

  /// Checks the connection now. Returns whether we're online.
  Future<bool> retry() async {
    if (_checking) return online;
    _checking = true;
    try {
      await http.head(Uri.parse('https://router.project-osrm.org/')).timeout(const Duration(seconds: 4));
      report(true);
    } catch (e) {
      if (isNetworkError(e)) report(false);
    } finally {
      _checking = false;
    }
    return online;
  }

  /// Back to the initial state (used when signing out and in tests).
  void reset() {
    _probe?.cancel();
    _probe = null;
    online = true;
  }
}

final net = NetStatus();
