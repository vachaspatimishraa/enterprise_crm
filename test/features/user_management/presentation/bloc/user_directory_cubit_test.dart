import 'package:enterprise_crm/features/auth/domain/entities/account_type.dart';
import 'package:enterprise_crm/features/user_management/domain/entities/managed_user.dart';
import 'package:enterprise_crm/features/user_management/domain/entities/user_account_status.dart';
import 'package:enterprise_crm/features/user_management/domain/repositories/user_management_repository.dart';
import 'package:enterprise_crm/features/user_management/presentation/bloc/user_directory_cubit.dart';
import 'package:enterprise_crm/features/user_management/presentation/bloc/user_directory_state.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeUserRepository implements UserManagementRepository {
  List<ManagedUser> users = [];
  bool shouldThrow = false;

  @override
  Future<List<ManagedUser>> getUsers() async {
    await Future<void>.delayed(Duration.zero);
    if (shouldThrow) throw Exception('Network error');
    return users;
  }

  @override
  Future<ManagedUser?> getUserById(String id) async => null;
}

void main() {
  group('UserDirectoryCubit Tests', () {
    late _FakeUserRepository repository;
    late UserDirectoryCubit cubit;

    final testUsers = [
      const ManagedUser(
        id: '1',
        userId: 'admin',
        displayName: 'Administrator',
        accountType: AccountType.admin,
        status: UserAccountStatus.active,
      ),
      const ManagedUser(
        id: '2',
        userId: 'john_doe',
        displayName: 'John Doe',
        accountType: AccountType.user,
        status: UserAccountStatus.active,
      ),
      const ManagedUser(
        id: '3',
        userId: 'jane_smith',
        displayName: 'Jane Smith',
        accountType: AccountType.user,
        status: UserAccountStatus.disabled,
      ),
    ];

    setUp(() {
      repository = _FakeUserRepository()..users = testUsers;
      cubit = UserDirectoryCubit(repository);
    });

    tearDown(() {
      cubit.close();
    });

    test('initial state is UserDirectoryInitial', () {
      expect(cubit.state, const UserDirectoryInitial());
    });

    test('loadUsers successfully emits loading and loaded states', () async {
      final expectation = expectLater(
        cubit.stream,
        emitsInOrder([
          const UserDirectoryLoading(),
          isA<UserDirectoryLoaded>(),
        ]),
      );

      await cubit.loadUsers();
      await expectation;

      final loaded = cubit.state as UserDirectoryLoaded;
      expect(loaded.allUsers, testUsers);
      expect(loaded.filteredUsers, testUsers);
      expect(loaded.searchQuery, '');
      expect(loaded.statusFilter, isNull);
    });

    test(
      'loadUsers emits UserDirectoryFailure when repository throws',
      () async {
        repository.shouldThrow = true;
        final expectation = expectLater(
          cubit.stream,
          emitsInOrder([
            const UserDirectoryLoading(),
            const UserDirectoryFailure('Unable to load users.'),
          ]),
        );

        await cubit.loadUsers();
        await expectation;
      },
    );

    test(
      'setSearchQuery filters by displayName or userId case-insensitively',
      () async {
        await cubit.loadUsers();

        // Search by displayName 'Jane'
        cubit.setSearchQuery('jane');
        var loaded = cubit.state as UserDirectoryLoaded;
        expect(loaded.filteredUsers.length, 1);
        expect(loaded.filteredUsers.first.userId, 'jane_smith');

        // Search by userId 'john'
        cubit.setSearchQuery('JOHN');
        loaded = cubit.state as UserDirectoryLoaded;
        expect(loaded.filteredUsers.length, 1);
        expect(loaded.filteredUsers.first.displayName, 'John Doe');

        // Clear search
        cubit.clearSearch();
        loaded = cubit.state as UserDirectoryLoaded;
        expect(loaded.filteredUsers.length, 3);
      },
    );

    test('setStatusFilter filters active vs disabled users', () async {
      await cubit.loadUsers();

      // Filter active
      cubit.setStatusFilter(UserAccountStatus.active);
      var loaded = cubit.state as UserDirectoryLoaded;
      expect(loaded.filteredUsers.length, 2);
      expect(loaded.filteredUsers.every((u) => u.isActive), isTrue);

      // Filter disabled
      cubit.setStatusFilter(UserAccountStatus.disabled);
      loaded = cubit.state as UserDirectoryLoaded;
      expect(loaded.filteredUsers.length, 1);
      expect(loaded.filteredUsers.first.userId, 'jane_smith');

      // Reset filter (null)
      cubit.setStatusFilter(null);
      loaded = cubit.state as UserDirectoryLoaded;
      expect(loaded.filteredUsers.length, 3);
    });

    test('combines search and status filtering', () async {
      await cubit.loadUsers();

      // Filter active and search 'admin'
      cubit.setStatusFilter(UserAccountStatus.active);
      cubit.setSearchQuery('admin');
      var loaded = cubit.state as UserDirectoryLoaded;
      expect(loaded.filteredUsers.length, 1);
      expect(loaded.filteredUsers.first.userId, 'admin');

      // Filter disabled and search 'admin' -> no match
      cubit.setStatusFilter(UserAccountStatus.disabled);
      loaded = cubit.state as UserDirectoryLoaded;
      expect(loaded.filteredUsers, isEmpty);
    });
  });
}
