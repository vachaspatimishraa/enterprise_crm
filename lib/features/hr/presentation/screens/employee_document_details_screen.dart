import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../auth/domain/entities/current_user.dart';
import '../../../auth/presentation/screens/access_restricted_screen.dart';
import '../../domain/entities/employee.dart';
import '../../domain/entities/employee_document.dart';
import '../../domain/policies/hr_access_policy.dart';
import '../../domain/repositories/employee_document_repository.dart';

/// Screen displaying the complete metadata, preview status, and download action
/// for a specific employee document.
class EmployeeDocumentDetailsScreen extends StatefulWidget {
  final CurrentUser user;
  final Employee employee;
  final EmployeeDocument document;
  final EmployeeDocumentRepository repository;

  const EmployeeDocumentDetailsScreen({
    super.key,
    required this.user,
    required this.employee,
    required this.document,
    required this.repository,
  });

  @override
  State<EmployeeDocumentDetailsScreen> createState() =>
      _EmployeeDocumentDetailsScreenState();
}

class _EmployeeDocumentDetailsScreenState
    extends State<EmployeeDocumentDetailsScreen> {
  bool _isDownloading = false;
  String? _downloadMessage;
  bool _isDownloadSuccess = false;

  Uint8List? _previewBytes;
  bool _isLoadingPreview = false;

  bool get _isImage => [
    'png',
    'jpg',
    'jpeg',
  ].contains(widget.document.fileExtension.toLowerCase());

  @override
  void initState() {
    super.initState();
    if (_isImage) {
      _loadPreview();
    }
  }

  Future<void> _loadPreview() async {
    setState(() => _isLoadingPreview = true);
    try {
      final bytes = await widget.repository.downloadDocumentFile(
        widget.document.id,
      );
      if (mounted) {
        setState(() {
          _previewBytes = bytes;
          _isLoadingPreview = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoadingPreview = false;
        });
      }
    }
  }

  Future<void> _download() async {
    if (_isDownloading) return;

    setState(() {
      _isDownloading = true;
      _downloadMessage = null;
    });

    try {
      final bytes = await widget.repository.downloadDocumentFile(
        widget.document.id,
      );
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _isDownloadSuccess = true;
          _downloadMessage =
              'Document ready: ${widget.document.fileName} (${bytes.length} bytes downloaded).';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            key: const Key('document_download_success_snackbar'),
            content: Text('Downloaded ${widget.document.fileName}'),
            backgroundColor: Colors.green.shade700,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _isDownloadSuccess = false;
          _downloadMessage = e is EmployeeDocumentException
              ? e.message
              : 'Failed to download document.';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            key: const Key('document_download_error_snackbar'),
            content: Text(_downloadMessage!),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!HrAccessPolicy.canViewHrRecords(widget.user)) {
      return const AccessRestrictedScreen();
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final doc = widget.document;
    final isExpired = doc.isExpired();

    return Scaffold(
      key: const Key('employee_document_details_scaffold'),
      appBar: AppBar(title: const Text('Document Details')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header Card
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: colorScheme.outlineVariant),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            _iconForExt(doc.fileExtension),
                            size: 36,
                            color: colorScheme.onPrimaryContainer,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                doc.title,
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Employee: ${widget.employee.fullName} (${widget.employee.employeeCode ?? widget.employee.id})',
                                style: TextStyle(
                                  color: colorScheme.onSurfaceVariant,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: colorScheme.secondaryContainer,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      doc.documentType,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: colorScheme.onSecondaryContainer,
                                      ),
                                    ),
                                  ),
                                  if (doc.hasExpiryDate) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isExpired
                                            ? Colors.red.shade100
                                            : Colors.green.shade100,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        isExpired ? 'EXPIRED' : 'ACTIVE',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: isExpired
                                              ? Colors.red.shade900
                                              : Colors.green.shade900,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Download Action Card
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: colorScheme.outlineVariant),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 16,
                      runSpacing: 12,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Authorized File Access',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Retrieve verified binary document payload',
                              style: TextStyle(
                                color: colorScheme.onSurfaceVariant,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        ElevatedButton.icon(
                          key: const Key('document_download_button'),
                          icon: _isDownloading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.download_outlined),
                          label: Text(
                            _isDownloading ? 'Downloading...' : 'Download File',
                          ),
                          onPressed: _isDownloading ? null : _download,
                        ),
                      ],
                    ),
                  ),
                ),
                if (_downloadMessage != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    key: const Key('document_download_status_box'),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _isDownloadSuccess
                          ? Colors.green.shade50
                          : colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _downloadMessage!,
                      style: TextStyle(
                        color: _isDownloadSuccess
                            ? Colors.green.shade900
                            : colorScheme.onErrorContainer,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 20),

                // Preview Section (Truthful handling)
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: colorScheme.outlineVariant),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'DOCUMENT PREVIEW',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (_isImage && _previewBytes != null) ...[
                          Center(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.memory(
                                _previewBytes!,
                                fit: BoxFit.contain,
                                height: 240,
                                errorBuilder: (context, error, stackTrace) =>
                                    _buildPreviewUnavailableNotice(
                                      colorScheme,
                                      'Image preview unavailable for this format.',
                                    ),
                              ),
                            ),
                          ),
                        ] else if (_isLoadingPreview) ...[
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.all(24.0),
                              child: CircularProgressIndicator(),
                            ),
                          ),
                        ] else ...[
                          _buildPreviewUnavailableNotice(
                            colorScheme,
                            doc.fileExtension.toLowerCase() == 'pdf'
                                ? 'PDF preview requires dedicated backend rendering. Please download the file to inspect its contents.'
                                : 'In-browser preview is unavailable for .${doc.fileExtension.toUpperCase()} files. Please download the file to inspect its contents.',
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Metadata Details Card
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: colorScheme.outlineVariant),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'FILE METADATA',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildDetailRow('Original File Name', doc.fileName),
                        _buildDetailRow(
                          'File Format',
                          doc.fileExtension.toUpperCase(),
                        ),
                        _buildDetailRow('File Size', doc.formattedFileSize),
                        _buildDetailRow(
                          'Uploaded On',
                          '${doc.uploadedAt.year}-${doc.uploadedAt.month.toString().padLeft(2, '0')}-${doc.uploadedAt.day.toString().padLeft(2, '0')}',
                        ),
                        if (doc.uploadedBy != null)
                          _buildDetailRow('Uploaded By', doc.uploadedBy!),
                        if (doc.hasExpiryDate)
                          _buildDetailRow(
                            'Expiry Date',
                            '${doc.expiryDate!.year}-${doc.expiryDate!.month.toString().padLeft(2, '0')}-${doc.expiryDate!.day.toString().padLeft(2, '0')}',
                          ),
                        if (doc.fileReference != null)
                          _buildDetailRow(
                            'Storage Reference',
                            doc.fileReference!,
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPreviewUnavailableNotice(
    ColorScheme colorScheme,
    String message,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 160,
            child: Text(
              label,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}

IconData _iconForExt(String ext) {
  switch (ext.toLowerCase()) {
    case 'pdf':
      return Icons.picture_as_pdf_outlined;
    case 'png':
    case 'jpg':
    case 'jpeg':
      return Icons.image_outlined;
    case 'doc':
    case 'docx':
      return Icons.description_outlined;
    default:
      return Icons.insert_drive_file_outlined;
  }
}
