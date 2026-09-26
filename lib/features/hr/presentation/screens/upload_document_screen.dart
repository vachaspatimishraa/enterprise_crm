import 'package:flutter/material.dart';

import '../../../auth/domain/entities/current_user.dart';
import '../../../auth/presentation/screens/access_restricted_screen.dart';
import '../../domain/entities/employee.dart';
import '../../domain/inputs/upload_document_input.dart';
import '../../domain/repositories/employee_document_repository.dart';
import '../services/employee_document_file_picker.dart';

/// Screen allowing authorized administrators to upload a document for an employee.
class UploadDocumentScreen extends StatefulWidget {
  final CurrentUser user;
  final Employee employee;
  final EmployeeDocumentRepository repository;
  final EmployeeDocumentFilePicker? filePicker;

  const UploadDocumentScreen({
    super.key,
    required this.user,
    required this.employee,
    required this.repository,
    this.filePicker,
  });

  @override
  State<UploadDocumentScreen> createState() => _UploadDocumentScreenState();
}

class _UploadDocumentScreenState extends State<UploadDocumentScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _titleController;
  late final TextEditingController _customTypeController;
  late final EmployeeDocumentFilePicker _filePicker;

  String _selectedType = 'Identity';
  DateTime? _selectedExpiryDate;
  EmployeeDocumentPickedFile? _pickedFile;

  bool _isSubmitting = false;
  String? _submissionError;
  bool _hasUnsavedChanges = false;

  static const List<String> _standardTypes = [
    'Identity',
    'Contract',
    'Certificate',
    'Resume',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _customTypeController = TextEditingController();
    _filePicker =
        widget.filePicker ?? const DefaultEmployeeDocumentFilePicker();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _customTypeController.dispose();
    super.dispose();
  }

  void _markChanged() {
    if (!_hasUnsavedChanges) {
      setState(() => _hasUnsavedChanges = true);
    }
  }

  Future<void> _pickFile() async {
    setState(() => _submissionError = null);
    try {
      final file = await _filePicker.pickDocumentFile();
      if (file != null) {
        if (file.sizeBytes > 10 * 1024 * 1024) {
          setState(() {
            _submissionError = 'Selected file exceeds the maximum 10 MB limit.';
          });
          return;
        }
        if (file.sizeBytes <= 0) {
          setState(() {
            _submissionError = 'Selected file is empty.';
          });
          return;
        }

        setState(() {
          _pickedFile = file;
          _hasUnsavedChanges = true;
          // Auto-fill title from file name if title is empty
          if (_titleController.text.trim().isEmpty) {
            final dotIndex = file.name.lastIndexOf('.');
            final baseName = dotIndex > 0
                ? file.name.substring(0, dotIndex)
                : file.name;
            _titleController.text = baseName;
          }
        });
      }
    } catch (e) {
      setState(() {
        _submissionError = 'Failed to select file: $e';
      });
    }
  }

  Future<void> _pickExpiryDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedExpiryDate ?? now.add(const Duration(days: 365)),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() {
        _selectedExpiryDate = picked;
        _hasUnsavedChanges = true;
      });
    }
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;

    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_pickedFile == null) {
      setState(() {
        _submissionError = 'Please select a file to upload.';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _submissionError = null;
    });

    final effectiveType =
        _selectedType == 'Other' && _customTypeController.text.trim().isNotEmpty
        ? _customTypeController.text.trim()
        : _selectedType;

    final input = UploadDocumentInput(
      employeeId: widget.employee.id,
      title: _titleController.text.trim(),
      documentType: effectiveType,
      fileName: _pickedFile!.name,
      fileExtension: _pickedFile!.extension,
      fileSizeBytes: _pickedFile!.sizeBytes,
      fileBytes: _pickedFile!.bytes,
      expiryDate: _selectedExpiryDate,
      uploadedBy: widget.user.id,
    );

    try {
      await widget.repository.uploadDocument(input);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Document uploaded successfully.')),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _submissionError = e is EmployeeDocumentException
              ? e.message
              : 'Failed to upload document. Please try again.';
        });
      }
    }
  }

  Future<void> _handlePop() async {
    final shouldLeave = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Discard Unsaved Changes?'),
        content: const Text(
          'You have selected a file or modified fields. Are you sure you want to discard your changes?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: const Text('Keep Editing'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    if (shouldLeave == true && mounted) {
      Navigator.of(context).pop(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.user.isAdmin) {
      return const AccessRestrictedScreen();
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return PopScope(
      canPop: !_hasUnsavedChanges || _isSubmitting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _handlePop();
        }
      },
      child: Scaffold(
        key: const Key('upload_document_scaffold'),
        appBar: AppBar(
          title: Text('Upload Document — ${widget.employee.fullName}'),
        ),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_submissionError != null) ...[
                      Container(
                        key: const Key('upload_doc_error_banner'),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: colorScheme.errorContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.error_outline, color: colorScheme.error),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _submissionError!,
                                style: TextStyle(
                                  color: colorScheme.onErrorContainer,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // File Selection Card
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: _pickedFile != null
                              ? colorScheme.primary
                              : colorScheme.outlineVariant,
                          width: _pickedFile != null ? 2 : 1,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          children: [
                            Icon(
                              _pickedFile != null
                                  ? Icons.check_circle_outline
                                  : Icons.cloud_upload_outlined,
                              size: 48,
                              color: _pickedFile != null
                                  ? colorScheme.primary
                                  : colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _pickedFile != null
                                  ? _pickedFile!.name
                                  : 'Select Document File',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            if (_pickedFile != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                '${(_pickedFile!.sizeBytes / 1024).toStringAsFixed(1)} KB • ${_pickedFile!.extension.toUpperCase()}',
                                style: TextStyle(
                                  color: colorScheme.onSurfaceVariant,
                                  fontSize: 13,
                                ),
                              ),
                            ] else ...[
                              const SizedBox(height: 4),
                              Text(
                                'Supported formats: PDF, PNG, JPG, DOC, DOCX (Max 10 MB)',
                                style: TextStyle(
                                  color: colorScheme.onSurfaceVariant,
                                  fontSize: 12,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                            const SizedBox(height: 16),
                            OutlinedButton.icon(
                              key: const Key('upload_doc_select_file_button'),
                              icon: const Icon(Icons.file_open_outlined),
                              label: Text(
                                _pickedFile != null
                                    ? 'Change File'
                                    : 'Choose File',
                              ),
                              onPressed: _isSubmitting ? null : _pickFile,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Document Title
                    TextFormField(
                      key: const Key('upload_doc_title_field'),
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: 'Document Title *',
                        hintText: 'e.g. Master Services Agreement',
                        prefixIcon: Icon(Icons.title),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter a document title.';
                        }
                        return null;
                      },
                      onChanged: (_) => _markChanged(),
                    ),
                    const SizedBox(height: 16),

                    // Document Type Dropdown
                    DropdownButtonFormField<String>(
                      key: const Key('upload_doc_type_dropdown'),
                      initialValue: _selectedType,
                      decoration: const InputDecoration(
                        labelText: 'Document Category *',
                        prefixIcon: Icon(Icons.category_outlined),
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        for (final type in _standardTypes)
                          DropdownMenuItem(value: type, child: Text(type)),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _selectedType = val);
                          _markChanged();
                        }
                      },
                    ),
                    if (_selectedType == 'Other') ...[
                      const SizedBox(height: 16),
                      TextFormField(
                        key: const Key('upload_doc_custom_type_field'),
                        controller: _customTypeController,
                        decoration: const InputDecoration(
                          labelText: 'Specify Category *',
                          hintText: 'e.g. Training Certificate',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (_selectedType == 'Other' &&
                              (value == null || value.trim().isEmpty)) {
                            return 'Please specify the category.';
                          }
                          return null;
                        },
                        onChanged: (_) => _markChanged(),
                      ),
                    ],
                    const SizedBox(height: 16),

                    // Expiry Date (Optional)
                    InkWell(
                      key: const Key('upload_doc_expiry_date_picker'),
                      onTap: _isSubmitting ? null : _pickExpiryDate,
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Expiry Date (Optional)',
                          prefixIcon: const Icon(Icons.calendar_today_outlined),
                          border: const OutlineInputBorder(),
                          suffixIcon: _selectedExpiryDate != null
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    setState(() => _selectedExpiryDate = null);
                                    _markChanged();
                                  },
                                )
                              : null,
                        ),
                        child: Text(
                          _selectedExpiryDate != null
                              ? '${_selectedExpiryDate!.year}-${_selectedExpiryDate!.month.toString().padLeft(2, '0')}-${_selectedExpiryDate!.day.toString().padLeft(2, '0')}'
                              : 'No expiration date',
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Submit Button
                    ElevatedButton(
                      key: const Key('upload_doc_submit_button'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      onPressed: _isSubmitting ? null : _submit,
                      child: _isSubmitting
                          ? const SizedBox(
                              key: Key('upload_doc_submitting_indicator'),
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text(
                              'Upload Document',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
