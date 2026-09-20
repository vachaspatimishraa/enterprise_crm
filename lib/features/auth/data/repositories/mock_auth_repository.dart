import '../../domain/entities/account_type.dart';
import '../../domain/entities/crm_module.dart';
import '../../domain/entities/current_user.dart';
import '../../domain/repositories/auth_repository.dart';

/// Temporary in-memory mock authentication repository for frontend testing.
class MockAuthRepository implements AuthRepository {
  CurrentUser? _currentUser;

  /// Predefined mock admin user.
  static const CurrentUser mockAdmin = CurrentUser(
    id: 'admin',
    displayName: 'Administrator',
    accountType: AccountType.admin,
    modules: {
      CrmModule.leadManagement,
      CrmModule.calling,
      CrmModule.inventory,
      CrmModule.dispatch,
      CrmModule.purchase,
      CrmModule.hrPayroll,
      CrmModule.approvalsNotifications,
      CrmModule.vendorManagement,
    },
    permissions: {},
  );

  /// Predefined mock standard user with limited module access.
  static const CurrentUser mockUser = CurrentUser(
    id: 'user',
    displayName: 'Standard User',
    accountType: AccountType.user,
    modules: {CrmModule.leadManagement, CrmModule.calling},
    permissions: {'leads.view'},
  );

  MockAuthRepository({CurrentUser? initialUser}) : _currentUser = initialUser;

  @override
  CurrentUser? get currentUser => _currentUser;

  @override
  Future<CurrentUser> login({
    required String userId,
    required String password,
  }) async {
    await Future<void>.delayed(Duration.zero);
    final trimmedId = userId.trim();
    final trimmedPassword = password.trim();

    if (trimmedId == 'admin' && trimmedPassword == 'admin123') {
      _currentUser = mockAdmin;
      return mockAdmin;
    }

    if (trimmedId == 'user' && trimmedPassword == 'user123') {
      _currentUser = mockUser;
      return mockUser;
    }

    throw const AuthException('Invalid User ID or password.');
  }

  @override
  Future<void> logout() async {
    await Future<void>.delayed(Duration.zero);
    _currentUser = null;
  }
}
