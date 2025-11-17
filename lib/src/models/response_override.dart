import 'package:flutter/foundation.dart';

/// Represents an overridden/edited response for a specific network request
class ResponseOverride {
  final int? statusCode;
  final Map<String, dynamic>? headers;
  final dynamic body;

  const ResponseOverride({
    this.statusCode,
    this.headers,
    this.body,
  });

  ResponseOverride copyWith({
    int? statusCode,
    Map<String, dynamic>? headers,
    dynamic body,
  }) {
    return ResponseOverride(
      statusCode: statusCode ?? this.statusCode,
      headers: headers ?? this.headers,
      body: body ?? this.body,
    );
  }
}

/// Manager for storing and retrieving response overrides
class ResponseOverrideManager {
  static final ResponseOverrideManager _instance =
      ResponseOverrideManager._internal();

  factory ResponseOverrideManager() => _instance;

  ResponseOverrideManager._internal();

  /// Whether response interception is globally enabled
  final ValueNotifier<bool> isEnabled = ValueNotifier(false);

  /// Storage for response overrides (key: "METHOD:URL")
  final Map<String, ResponseOverride> _overrides = {};

  /// Get all stored overrides
  Map<String, ResponseOverride> get overrides =>
      Map.unmodifiable(_overrides);

  /// Set a response override for a specific request
  void setOverride({
    required String method,
    required String url,
    required ResponseOverride override,
  }) {
    final key = _createKey(method, url);
    _overrides[key] = override;
  }

  /// Get a response override for a specific request
  ResponseOverride? getOverride({
    required String method,
    required String url,
  }) {
    final key = _createKey(method, url);
    return _overrides[key];
  }

  /// Check if a response override exists for a specific request
  bool hasOverride({
    required String method,
    required String url,
  }) {
    final key = _createKey(method, url);
    return _overrides.containsKey(key);
  }

  /// Remove a response override for a specific request
  void removeOverride({
    required String method,
    required String url,
  }) {
    final key = _createKey(method, url);
    _overrides.remove(key);
  }

  /// Clear all response overrides
  void clearAll() {
    _overrides.clear();
  }

  /// Create a unique key from method and URL
  String _createKey(String method, String url) {
    return '$method:$url';
  }

  /// Toggle the enabled state
  void toggleEnabled() {
    isEnabled.value = !isEnabled.value;
  }
}
