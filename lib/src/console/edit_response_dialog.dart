import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:logarte/logarte.dart';
import 'package:logarte/src/console/logarte_theme_wrapper.dart';
import 'package:logarte/src/models/response_override.dart';

class EditResponseDialog extends StatefulWidget {
  final NetworkLogarteEntry entry;

  const EditResponseDialog({
    Key? key,
    required this.entry,
  }) : super(key: key);

  @override
  State<EditResponseDialog> createState() => _EditResponseDialogState();
}

class _EditResponseDialogState extends State<EditResponseDialog> {
  late TextEditingController _statusCodeController;
  late TextEditingController _bodyController;
  late TextEditingController _headersController;
  final _formKey = GlobalKey<FormState>();
  String? _bodyError;
  String? _headersError;

  @override
  void initState() {
    super.initState();
    final manager = ResponseOverrideManager();
    final existingOverride = manager.getOverride(
      method: widget.entry.request.method,
      url: widget.entry.request.url,
    );

    _statusCodeController = TextEditingController(
      text: (existingOverride?.statusCode ??
              widget.entry.response.statusCode ??
              200)
          .toString(),
    );
    _bodyController = TextEditingController(
      text: _formatJson(
        existingOverride?.body ?? widget.entry.response.body,
      ),
    );
    _headersController = TextEditingController(
      text: _formatJson(
        existingOverride?.headers ?? widget.entry.response.headers,
      ),
    );
  }

  String _formatJson(dynamic data) {
    try {
      if (data == null) return '';
      if (data is String) {
        // Try to parse and re-format if it's already JSON
        try {
          final parsed = jsonDecode(data);
          return const JsonEncoder.withIndent('  ').convert(parsed);
        } catch (_) {
          return data;
        }
      }
      return const JsonEncoder.withIndent('  ').convert(data);
    } catch (_) {
      return data.toString();
    }
  }

  dynamic _parseJson(String text) {
    if (text.trim().isEmpty) return null;
    try {
      return jsonDecode(text);
    } catch (_) {
      return text;
    }
  }

  bool _validateJson(String text, String fieldName) {
    if (text.trim().isEmpty) return true;
    try {
      jsonDecode(text);
      return true;
    } catch (e) {
      if (fieldName == 'body') {
        setState(() {
          _bodyError = 'Invalid JSON: ${e.toString()}';
        });
      } else {
        setState(() {
          _headersError = 'Invalid JSON: ${e.toString()}';
        });
      }
      return false;
    }
  }

  void _saveOverride() {
    setState(() {
      _bodyError = null;
      _headersError = null;
    });

    if (!_formKey.currentState!.validate()) return;

    final bodyText = _bodyController.text.trim();
    final headersText = _headersController.text.trim();

    if (!_validateJson(bodyText, 'body')) return;
    if (!_validateJson(headersText, 'headers')) return;

    final statusCode = int.tryParse(_statusCodeController.text);
    if (statusCode == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid status code')),
      );
      return;
    }

    final body = _parseJson(bodyText);
    final headersData = _parseJson(headersText);
    Map<String, dynamic>? headers;
    if (headersData != null && headersData is Map) {
      headers = Map<String, dynamic>.from(headersData);
    }

    final manager = ResponseOverrideManager();
    manager.setOverride(
      method: widget.entry.request.method,
      url: widget.entry.request.url,
      override: ResponseOverride(
        statusCode: statusCode,
        body: body,
        headers: headers,
      ),
    );

    Navigator.of(context).pop(true);
  }

  void _removeOverride() {
    final manager = ResponseOverrideManager();
    manager.removeOverride(
      method: widget.entry.request.method,
      url: widget.entry.request.url,
    );
    Navigator.of(context).pop(true);
  }

  @override
  void dispose() {
    _statusCodeController.dispose();
    _bodyController.dispose();
    _headersController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final manager = ResponseOverrideManager();
    final hasExistingOverride = manager.hasOverride(
      method: widget.entry.request.method,
      url: widget.entry.request.url,
    );

    return LogarteThemeWrapper(
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close),
          ),
          title: const Text('Edit Response'),
          actions: [
            if (hasExistingOverride)
              IconButton(
                onPressed: _removeOverride,
                icon: const Icon(Icons.delete),
                tooltip: 'Remove Override',
              ),
            IconButton(
              onPressed: _saveOverride,
              icon: const Icon(Icons.check),
              tooltip: 'Save',
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              if (hasExistingOverride)
                Container(
                  padding: const EdgeInsets.all(12.0),
                  margin: const EdgeInsets.only(bottom: 16.0),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8.0),
                    border: Border.all(color: Colors.orange),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning, color: Colors.orange),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'This response is currently overridden',
                          style: TextStyle(color: Colors.orange[700]),
                        ),
                      ),
                    ],
                  ),
                ),
              const Text(
                'STATUS CODE',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _statusCodeController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  hintText: '200',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Status code is required';
                  }
                  final code = int.tryParse(value);
                  if (code == null || code < 100 || code > 599) {
                    return 'Enter a valid HTTP status code (100-599)';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              const Text(
                'RESPONSE BODY (JSON)',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _bodyController,
                maxLines: 10,
                decoration: InputDecoration(
                  hintText: '{"key": "value"}',
                  border: const OutlineInputBorder(),
                  errorText: _bodyError,
                  errorMaxLines: 3,
                ),
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'RESPONSE HEADERS (JSON)',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _headersController,
                maxLines: 6,
                decoration: InputDecoration(
                  hintText: '{"content-type": "application/json"}',
                  border: const OutlineInputBorder(),
                  errorText: _headersError,
                  errorMaxLines: 3,
                ),
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(12.0),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8.0),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.info_outline, size: 20, color: Colors.blue),
                        SizedBox(width: 8),
                        Text(
                          'Note',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'This override will apply to all future requests matching:\n'
                      '${widget.entry.request.method} ${widget.entry.request.url}\n\n'
                      'Make sure response interception is enabled in the dashboard.',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
