import 'package:dio/dio.dart';
import 'package:logarte/logarte.dart';
import 'package:logarte/src/models/response_override.dart';

class LogarteDioInterceptor extends Interceptor {
  final Logarte _logarte;
  final ResponseOverrideManager _overrideManager = ResponseOverrideManager();

  LogarteDioInterceptor(this._logarte);

  final _cache = <RequestOptions, DateTime>{};

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    _cache[options] = DateTime.now();

    return super.onRequest(options, handler);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    final Map<String, String> responseHeaders = response.headers.map.map(
      (key, value) => MapEntry(key, value.join(', ')),
    );
    final sentAt = _cache[response.requestOptions];
    final receivedAt = DateTime.now();

    // Check if response interception is enabled and if there's an override
    if (_overrideManager.isEnabled.value) {
      final override = _overrideManager.getOverride(
        method: response.requestOptions.method,
        url: response.requestOptions.uri.toString(),
      );

      if (override != null) {
        // Create a modified response with overridden values
        final modifiedResponse = Response(
          requestOptions: response.requestOptions,
          data: override.body ?? response.data,
          statusCode: override.statusCode ?? response.statusCode,
          statusMessage: response.statusMessage,
          headers: override.headers != null
              ? Headers.fromMap(override.headers!)
              : response.headers,
          extra: response.extra,
        );

        // Log the modified response
        _logarte.network(
          request: NetworkRequestLogarteEntry(
            url: response.requestOptions.uri.toString(),
            method: response.requestOptions.method,
            headers: response.requestOptions.headers,
            body: response.requestOptions.data,
            sentAt: sentAt,
          ),
          response: NetworkResponseLogarteEntry(
            statusCode: modifiedResponse.statusCode,
            headers: modifiedResponse.headers.map.map(
              (key, value) => MapEntry(key, value.join(', ')),
            ),
            body: modifiedResponse.data,
            receivedAt: receivedAt,
          ),
          write: false,
        );

        // Return the modified response to the app
        return handler.resolve(modifiedResponse);
      }
    }

    _logarte.network(
      request: NetworkRequestLogarteEntry(
        url: response.requestOptions.uri.toString(),
        method: response.requestOptions.method,
        headers: response.requestOptions.headers,
        body: response.requestOptions.data,
        sentAt: sentAt,
      ),
      response: NetworkResponseLogarteEntry(
        statusCode: response.statusCode,
        headers: responseHeaders,
        body: response.data,
        receivedAt: receivedAt,
      ),
      write: false,
    );

    return super.onResponse(response, handler);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final Map<String, String>? responseHeaders = err.response?.headers.map.map(
      (key, value) => MapEntry(key, value.join(', ')),
    );

    _logarte.network(
      request: NetworkRequestLogarteEntry(
        url: err.requestOptions.uri.toString(),
        method: err.requestOptions.method,
        headers: err.requestOptions.headers,
        body: err.requestOptions.data,
      ),
      response: NetworkResponseLogarteEntry(
        statusCode: err.response?.statusCode ?? 0,
        headers: responseHeaders,
        body: err.response?.data,
      ),
      write: false,
    );

    return super.onError(err, handler);
  }
}
