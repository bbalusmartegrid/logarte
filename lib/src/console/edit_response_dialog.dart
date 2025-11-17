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
  late List<FieldEntry> _bodyFields;
  late List<FieldEntry> _headerFields;
  final _formKey = GlobalKey<FormState>();

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

    // Parse body fields
    _bodyFields = _parseToFields(
      existingOverride?.body ?? widget.entry.response.body,
    );

    // Parse header fields
    _headerFields = _parseToFields(
      existingOverride?.headers ?? widget.entry.response.headers,
    );
  }

  List<FieldEntry> _parseToFields(dynamic data) {
    final fields = <FieldEntry>[];

    if (data == null) return fields;

    try {
      Map<String, dynamic> map;

      if (data is String) {
        try {
          final parsed = jsonDecode(data);
          if (parsed is Map) {
            map = Map<String, dynamic>.from(parsed);
          } else {
            // If it's not a map, create a single field
            fields.add(FieldEntry(
              keyController: TextEditingController(text: 'value'),
              valueController: TextEditingController(text: data),
            ));
            return fields;
          }
        } catch (_) {
          // Not JSON, treat as single value
          fields.add(FieldEntry(
            keyController: TextEditingController(text: 'value'),
            valueController: TextEditingController(text: data),
          ));
          return fields;
        }
      } else if (data is Map) {
        map = Map<String, dynamic>.from(data);
      } else {
        // For other types, create a single field
        fields.add(FieldEntry(
          keyController: TextEditingController(text: 'value'),
          valueController: TextEditingController(text: data.toString()),
        ));
        return fields;
      }

      // Convert map to field entries
      _flattenMap(map, fields);

    } catch (_) {
      // If parsing fails, return empty or default
    }

    return fields;
  }

  void _flattenMap(Map<String, dynamic> map, List<FieldEntry> fields, [String prefix = '']) {
    map.forEach((key, value) {
      final fullKey = prefix.isEmpty ? key : '$prefix.$key';

      if (value is Map) {
        // Recursively flatten nested objects
        _flattenMap(Map<String, dynamic>.from(value), fields, fullKey);
      } else if (value is List) {
        // Convert list to JSON string for editing
        fields.add(FieldEntry(
          keyController: TextEditingController(text: fullKey),
          valueController: TextEditingController(
            text: jsonEncode(value),
          ),
          isArray: true,
        ));
      } else {
        fields.add(FieldEntry(
          keyController: TextEditingController(text: fullKey),
          valueController: TextEditingController(
            text: value?.toString() ?? '',
          ),
        ));
      }
    });
  }

  Map<String, dynamic> _buildMapFromFields(List<FieldEntry> fields) {
    final result = <String, dynamic>{};

    for (final field in fields) {
      final key = field.keyController.text.trim();
      if (key.isEmpty) continue;

      final valueText = field.valueController.text.trim();
      dynamic value;

      // Try to parse as JSON for arrays or objects
      if (field.isArray || valueText.startsWith('[') || valueText.startsWith('{')) {
        try {
          value = jsonDecode(valueText);
        } catch (_) {
          value = valueText;
        }
      } else if (valueText.isEmpty) {
        value = null;
      } else if (valueText.toLowerCase() == 'true') {
        value = true;
      } else if (valueText.toLowerCase() == 'false') {
        value = false;
      } else if (valueText.toLowerCase() == 'null') {
        value = null;
      } else {
        // Try to parse as number
        final numValue = num.tryParse(valueText);
        value = numValue ?? valueText;
      }

      // Handle nested keys (e.g., "user.name" -> {"user": {"name": value}})
      if (key.contains('.')) {
        final parts = key.split('.');
        Map<String, dynamic> current = result;

        for (int i = 0; i < parts.length - 1; i++) {
          current.putIfAbsent(parts[i], () => <String, dynamic>{});
          if (current[parts[i]] is! Map) {
            current[parts[i]] = <String, dynamic>{};
          }
          current = current[parts[i]] as Map<String, dynamic>;
        }

        current[parts.last] = value;
      } else {
        result[key] = value;
      }
    }

    return result;
  }

  void _addBodyField() {
    setState(() {
      _bodyFields.add(FieldEntry(
        keyController: TextEditingController(),
        valueController: TextEditingController(),
      ));
    });
  }

  void _addHeaderField() {
    setState(() {
      _headerFields.add(FieldEntry(
        keyController: TextEditingController(),
        valueController: TextEditingController(),
      ));
    });
  }

  void _removeBodyField(int index) {
    setState(() {
      _bodyFields[index].dispose();
      _bodyFields.removeAt(index);
    });
  }

  void _removeHeaderField(int index) {
    setState(() {
      _headerFields[index].dispose();
      _headerFields.removeAt(index);
    });
  }

  void _saveOverride() {
    if (!_formKey.currentState!.validate()) return;

    final statusCode = int.tryParse(_statusCodeController.text);
    if (statusCode == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid status code')),
      );
      return;
    }

    final bodyMap = _buildMapFromFields(_bodyFields);
    final headersMap = _buildMapFromFields(_headerFields);

    final manager = ResponseOverrideManager();
    manager.setOverride(
      method: widget.entry.request.method,
      url: widget.entry.request.url,
      override: ResponseOverride(
        statusCode: statusCode,
        body: bodyMap.isEmpty ? null : bodyMap,
        headers: headersMap.isEmpty ? null : headersMap,
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
    for (final field in _bodyFields) {
      field.dispose();
    }
    for (final field in _headerFields) {
      field.dispose();
    }
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

              // Status Code Section
              Row(
                children: [
                  const Text(
                    'STATUS CODE',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: 100,
                    child: TextFormField(
                      controller: _statusCodeController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        hintText: '200',
                        isDense: true,
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Required';
                        }
                        final code = int.tryParse(value);
                        if (code == null || code < 100 || code > 599) {
                          return 'Invalid';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),

              // Response Body Section
              Row(
                children: [
                  const Text(
                    'RESPONSE BODY',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _addBodyField,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add Field'),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              if (_bodyFields.isEmpty)
                Container(
                  padding: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  child: const Center(
                    child: Text(
                      'No fields. Tap "Add Field" to create one.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                )
              else
                ...List.generate(_bodyFields.length, (index) {
                  return _FieldRow(
                    field: _bodyFields[index],
                    onRemove: () => _removeBodyField(index),
                    index: index,
                  );
                }),

              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),

              // Response Headers Section
              Row(
                children: [
                  const Text(
                    'RESPONSE HEADERS',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _addHeaderField,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add Field'),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              if (_headerFields.isEmpty)
                Container(
                  padding: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  child: const Center(
                    child: Text(
                      'No fields. Tap "Add Field" to create one.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                )
              else
                ...List.generate(_headerFields.length, (index) {
                  return _FieldRow(
                    field: _headerFields[index],
                    onRemove: () => _removeHeaderField(index),
                    index: index,
                  );
                }),

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
                          'Tips',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '• Use dot notation for nested objects (e.g., "user.name")\n'
                      '• Values are auto-typed: numbers, booleans (true/false), null\n'
                      '• Arrays/objects: use JSON format [1,2,3] or {"key":"value"}\n'
                      '• Override applies to: ${widget.entry.request.method} ${widget.entry.request.url}',
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

class FieldEntry {
  final TextEditingController keyController;
  final TextEditingController valueController;
  final bool isArray;

  FieldEntry({
    required this.keyController,
    required this.valueController,
    this.isArray = false,
  });

  void dispose() {
    keyController.dispose();
    valueController.dispose();
  }
}

class _FieldRow extends StatelessWidget {
  final FieldEntry field;
  final VoidCallback onRemove;
  final int index;

  const _FieldRow({
    required this.field,
    required this.onRemove,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: TextFormField(
              controller: field.keyController,
              decoration: InputDecoration(
                labelText: 'Key',
                hintText: 'field_name',
                isDense: true,
                border: const OutlineInputBorder(),
                suffixIcon: field.isArray
                    ? const Tooltip(
                        message: 'Array field',
                        child: Icon(Icons.list, size: 16),
                      )
                    : null,
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Required';
                }
                return null;
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: TextFormField(
              controller: field.valueController,
              decoration: const InputDecoration(
                labelText: 'Value',
                hintText: 'value',
                isDense: true,
                border: OutlineInputBorder(),
              ),
              maxLines: field.isArray ? 3 : 1,
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: onRemove,
            icon: const Icon(Icons.remove_circle_outline),
            color: Colors.red,
            tooltip: 'Remove field',
          ),
        ],
      ),
    );
  }
}
