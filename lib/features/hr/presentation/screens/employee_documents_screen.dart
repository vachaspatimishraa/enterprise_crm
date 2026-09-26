import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../auth/domain/entities/current_user.dart';
import '../../../auth/presentation/screens/access_restricted_screen.dart';
import '../../domain/entities/employee.dart';
import '../../domain/entities/employee_document.dart';
import '../../domain/policies/hr_access_policy.dart';
import '../../domain/repositories/employee_document_repository.dart';
import '../bloc/employee_documents_cubit.dart';
import '../bloc/employee_documents_state.dart';
import '../services/employee_document_file_picker.dart';
import 'employee_document_details_screen.dart';
import 'upload_document_screen.dart';

/// Screen displaying the list of documents associated with a specific employee.
///
/// Supports responsive presentation (cards on mobile, table on desktop/web),
/// case-insensitive search, type filtering, reload, and navigation to details/upload.
class EmployeeDocumentsScreen extends StatelessWidget {
  final CurrentUser user;
  final Employee employee;
  final EmployeeDocumentRepository repository;
  final EmployeeDocumentFilePicker? filePicker;

  const EmployeeDocumentsScreen({
    super.key,
    required this.user,
    required this.employee,
    required this.repository,
    this.filePicker,
  });

  @override
  Widget build(BuildContext context) {
    if (!HrAccessPolicy.canViewHrRecords(user)) {
      return const AccessRestrictedScreen();
    }

    return BlocProvider(
      create: (_) =>
          EmployeeDocumentsCubit(repository, employeeId: employee.id)
            ..loadDocuments(),
      child: _EmployeeDocumentsView(
        user: user,
        employee: employee,
        repository: repository,
        filePicker: filePicker,
      ),
    );
  }
}

class _EmployeeDocumentsView extends StatefulWidget {
  final CurrentUser user;
  final Employee employee;
  final EmployeeDocumentRepository repository;
  final EmployeeDocumentFilePicker? filePicker;

  const _EmployeeDocumentsView({
    required this.user,
    required this.employee,
    required this.repository,
    this.filePicker,
  });

  @override
  State<_EmployeeDocumentsView> createState() => _EmployeeDocumentsViewState();
}

class _EmployeeDocumentsViewState extends State<_EmployeeDocumentsView> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openDetails(BuildContext context, EmployeeDocument document) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EmployeeDocumentDetailsScreen(
          user: widget.user,
          employee: widget.employee,
          document: document,
          repository: widget.repository,
        ),
      ),
    );
  }

  void _openUpload() async {
    final uploaded = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => UploadDocumentScreen(
          user: widget.user,
          employee: widget.employee,
          repository: widget.repository,
          filePicker: widget.filePicker,
        ),
      ),
    );

    if (uploaded == true && mounted) {
      context.read<EmployeeDocumentsCubit>().refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final canUpload = widget.user.isAdmin;

    return Scaffold(
      key: const Key('employee_documents_scaffold'),
      appBar: AppBar(
        title: Text('${widget.employee.fullName} — Documents'),
        actions: [
          IconButton(
            key: const Key('employee_documents_refresh_button'),
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: () => context.read<EmployeeDocumentsCubit>().refresh(),
          ),
        ],
      ),
      floatingActionButton: canUpload
          ? FloatingActionButton.extended(
              key: const Key('employee_documents_add_button'),
              icon: const Icon(Icons.upload_file_outlined),
              label: const Text('Add Document'),
              onPressed: _openUpload,
            )
          : null,
      body: BlocBuilder<EmployeeDocumentsCubit, EmployeeDocumentsState>(
        builder: (context, state) {
          return Column(
            children: [
              _buildFilterHeader(context, state),
              Expanded(child: _buildBody(context, state)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFilterHeader(
    BuildContext context,
    EmployeeDocumentsState state,
  ) {
    final hasActiveFilter =
        state.searchQuery.isNotEmpty || state.filterType != null;

    final allTypes = {'Identity', 'Contract', 'Certificate', 'Resume', 'Other'}
      ..addAll(state.availableTypes);

    return Material(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              key: const Key('employee_documents_search_field'),
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search documents by title, file name, or type...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        key: const Key('employee_documents_search_clear'),
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                          context.read<EmployeeDocumentsCubit>().setSearchQuery(
                            '',
                          );
                        },
                      )
                    : null,
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onChanged: (value) {
                setState(() {});
                context.read<EmployeeDocumentsCubit>().setSearchQuery(value);
              },
            ),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ChoiceChip(
                    key: const Key('filter_chip_all_docs'),
                    label: const Text('All Types'),
                    selected: state.filterType == null,
                    onSelected: (_) {
                      context.read<EmployeeDocumentsCubit>().setFilterType(
                        null,
                      );
                    },
                  ),
                  for (final type in allTypes) ...[
                    const SizedBox(width: 8),
                    ChoiceChip(
                      key: Key('filter_chip_${type.toLowerCase()}'),
                      label: Text(type),
                      selected: state.filterType == type,
                      onSelected: (_) {
                        context.read<EmployeeDocumentsCubit>().setFilterType(
                          type,
                        );
                      },
                    ),
                  ],
                  if (hasActiveFilter) ...[
                    const SizedBox(width: 8),
                    TextButton.icon(
                      key: const Key('employee_documents_reset_filters_button'),
                      icon: const Icon(Icons.filter_alt_off, size: 16),
                      label: const Text('Reset'),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {});
                        context.read<EmployeeDocumentsCubit>().resetFilters();
                      },
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, EmployeeDocumentsState state) {
    if (state.isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          key: Key('employee_documents_loading_indicator'),
        ),
      );
    }

    if (state.isFailure) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                size: 48,
                color: Colors.redAccent,
                key: Key('employee_documents_error_icon'),
              ),
              const SizedBox(height: 12),
              Text(
                state.errorMessage ?? 'An error occurred loading documents.',
                style: const TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                key: const Key('employee_documents_retry_button'),
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                onPressed: () =>
                    context.read<EmployeeDocumentsCubit>().refresh(),
              ),
            ],
          ),
        ),
      );
    }

    if (state.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.folder_open_outlined,
                size: 48,
                color: Colors.grey,
                key: Key('employee_documents_empty_icon'),
              ),
              const SizedBox(height: 12),
              const Text(
                'No documents found',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              const Text(
                'Upload a document or adjust your search filters.',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 600;
        return isDesktop
            ? _buildDesktopTable(context, state.filteredDocuments)
            : _buildMobileCards(context, state.filteredDocuments);
      },
    );
  }

  Widget _buildMobileCards(
    BuildContext context,
    List<EmployeeDocument> documents,
  ) {
    return ListView.separated(
      key: const Key('employee_documents_mobile_list'),
      padding: const EdgeInsets.all(16.0),
      itemCount: documents.length,
      separatorBuilder: (_, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final doc = documents[index];
        return _DocumentCard(
          key: Key('employee_document_card_${doc.id}'),
          document: doc,
          onTap: () => _openDetails(context, doc),
        );
      },
    );
  }

  Widget _buildDesktopTable(
    BuildContext context,
    List<EmployeeDocument> documents,
  ) {
    return SingleChildScrollView(
      key: const Key('employee_documents_desktop_table_scroll'),
      padding: const EdgeInsets.all(16.0),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: const [
              DataColumn(label: Text('Document Title')),
              DataColumn(label: Text('Type')),
              DataColumn(label: Text('File Name')),
              DataColumn(label: Text('Size')),
              DataColumn(label: Text('Uploaded')),
              DataColumn(label: Text('Expiry')),
              DataColumn(label: Text('Action')),
            ],
            rows: [
              for (final doc in documents)
                DataRow(
                  key: ValueKey('employee_document_row_${doc.id}'),
                  onSelectChanged: (_) => _openDetails(context, doc),
                  cells: [
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _iconForExtension(doc.fileExtension),
                            size: 20,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            doc.title,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .secondaryContainer
                              .withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          doc.documentType,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSecondaryContainer,
                          ),
                        ),
                      ),
                    ),
                    DataCell(Text(doc.fileName)),
                    DataCell(Text(doc.formattedFileSize)),
                    DataCell(
                      Text(
                        '${doc.uploadedAt.year}-${doc.uploadedAt.month.toString().padLeft(2, '0')}-${doc.uploadedAt.day.toString().padLeft(2, '0')}',
                      ),
                    ),
                    DataCell(
                      doc.hasExpiryDate
                          ? Text(
                              '${doc.expiryDate!.year}-${doc.expiryDate!.month.toString().padLeft(2, '0')}-${doc.expiryDate!.day.toString().padLeft(2, '0')}',
                              style: TextStyle(
                                color: doc.isExpired() ? Colors.red : null,
                                fontWeight: doc.isExpired()
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            )
                          : const Text('—'),
                    ),
                    DataCell(
                      TextButton(
                        key: Key('view_doc_button_${doc.id}'),
                        child: const Text('View'),
                        onPressed: () => _openDetails(context, doc),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DocumentCard extends StatelessWidget {
  final EmployeeDocument document;
  final VoidCallback onTap;

  const _DocumentCard({super.key, required this.document, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isExpired = document.isExpired();

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      _iconForExtension(document.fileExtension),
                      color: colorScheme.onPrimaryContainer,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          document.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          document.fileName,
                          style: TextStyle(
                            fontSize: 13,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      document.documentType,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSecondaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 10),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                runSpacing: 4,
                children: [
                  Text(
                    'Size: ${document.formattedFileSize}',
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (document.hasExpiryDate)
                    Text(
                      isExpired
                          ? 'EXPIRED: ${document.expiryDate!.year}-${document.expiryDate!.month.toString().padLeft(2, '0')}-${document.expiryDate!.day.toString().padLeft(2, '0')}'
                          : 'Expires: ${document.expiryDate!.year}-${document.expiryDate!.month.toString().padLeft(2, '0')}-${document.expiryDate!.day.toString().padLeft(2, '0')}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isExpired
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: isExpired
                            ? Colors.red
                            : colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

IconData _iconForExtension(String ext) {
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
