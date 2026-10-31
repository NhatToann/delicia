// UC-06 — UserBloc unit tests. Uses an in-memory [_FakeUserService].

import 'dart:async';
import 'dart:typed_data';

import 'package:bloc_test/bloc_test.dart';
import 'package:delicia/domain/bloc/user/user_bloc.dart';
import 'package:delicia/domain/models/user.dart';
import 'package:delicia/domain/services/client_user_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeUserService implements ClientUserService {
  _FakeUserService({this.user});
  User? user;
  bool throwOnLoad = false;
  bool throwOnUpdate = false;
  bool throwOnAvatar = false;

  /// Bytes returned by [loadAvatarBytes] — used to exercise the inline
  /// (Realtime Database fallback) avatar rendering.
  Uint8List? avatarBytes;

  @override
  Future<User> loadProfile(String uid) async {
    if (throwOnLoad) throw ClientUserServiceException('load failed');
    return user ??
        User(
          uid: uid,
          email: 'a@b.com',
          firstName: 'A',
          lastName: 'B',
          rolId: 2,
        );
  }

  @override
  Future<User> updateProfile(
    String uid, {
    String? firstName,
    String? lastName,
    String? phone,
  }) async {
    if (throwOnUpdate) throw ClientUserServiceException('update failed');
    user = User(
      uid: uid,
      email: user?.email ?? 'a@b.com',
      firstName: firstName ?? user?.firstName ?? 'A',
      lastName: lastName ?? user?.lastName ?? 'B',
      phone: phone ?? user?.phone,
      image: user?.image,
      rolId: user?.rolId ?? 2,
    );
    return user!;
  }

  @override
  Future<User> uploadAvatar(String uid, Uint8List bytes, {String? mime}) async {
    if (throwOnAvatar) throw ClientUserServiceException('avatar failed');
    user = User(
      uid: uid,
      email: user?.email ?? 'a@b.com',
      firstName: user?.firstName ?? 'A',
      lastName: user?.lastName ?? 'B',
      phone: user?.phone,
      image: 'https://example.com/avatar.jpg',
      rolId: user?.rolId ?? 2,
    );
    return user!;
  }

  @override
  Future<User> uploadAvatarFile(String uid, dynamic file) async {
    return uploadAvatar(uid, Uint8List(0));
  }

  @override
  Stream<User?> watchProfile(String uid) {
    return Stream<User?>.value(user);
  }

  @override
  Future<Uint8List?> loadAvatarBytes(String uid) async => avatarBytes;
}

void main() {
  group('UserBloc', () {
    test('initial state is empty', () {
      final bloc = UserBloc(userService: _FakeUserService());
      expect(bloc.state.user, isNull);
      expect(bloc.state.isLoading, isFalse);
      expect(bloc.state.error, isNull);
    });

    blocTest<UserBloc, UserState>(
      'loads the user profile',
      build: () => UserBloc(
        userService: _FakeUserService(
          user: User(
            uid: 'u1',
            email: 'a@b.com',
            firstName: 'Alice',
            lastName: 'Doe',
            phone: '+8412345',
            rolId: 2,
          ),
        ),
      ),
      act: (bloc) => bloc.add(const OnLoadUserProfileEvent(uid: 'u1')),
      expect: () => [
        isA<UserState>().having((s) => s.isLoading, 'loading', true),
        isA<UserState>()
            .having((s) => s.isLoading, 'loading', false)
            .having((s) => s.user?.firstName, 'first', 'Alice')
            .having((s) => s.activeUid, 'uid', 'u1'),
      ],
    );

    blocTest<UserBloc, UserState>(
      'surfaces a user-friendly error when load fails',
      build: () =>
          UserBloc(userService: _FakeUserService()..throwOnLoad = true),
      act: (bloc) => bloc.add(const OnLoadUserProfileEvent(uid: 'u1')),
      expect: () => [
        isA<UserState>().having((s) => s.isLoading, 'loading', true),
        isA<UserState>()
            .having((s) => s.isLoading, 'loading', false)
            .having((s) => s.error, 'error', contains('load failed')),
      ],
    );

    blocTest<UserBloc, UserState>(
      'returns an error when invoked without a uid',
      build: () => UserBloc(userService: _FakeUserService()),
      act: (bloc) => bloc.add(const OnLoadUserProfileEvent(uid: '')),
      expect: () => [
        isA<UserState>()
            .having((s) => s.isLoading, 'loading', false)
            .having((s) => s.error, 'error', contains('Sign in'))
            .having((s) => s.user, 'user', isNull),
      ],
    );

    blocTest<UserBloc, UserState>(
      'updates profile fields and persists them in state',
      build: () => UserBloc(
        userService: _FakeUserService(
          user: User(
            uid: 'u1',
            email: 'a@b.com',
            firstName: 'A',
            lastName: 'B',
            rolId: 2,
          ),
        ),
      ),
      act: (bloc) => bloc.add(
        const OnUpdateUserProfileEvent(
          uid: 'u1',
          firstName: 'Alice',
          lastName: 'Doe',
          phone: '+8412345',
        ),
      ),
      expect: () => [
        isA<UserState>().having((s) => s.isSaving, 'saving', true),
        isA<UserState>()
            .having((s) => s.isSaving, 'saving', false)
            .having((s) => s.user?.firstName, 'first', 'Alice')
            .having((s) => s.user?.phone, 'phone', '+8412345')
            .having((s) => s.lastSavedAt, 'saved', isNotNull),
      ],
    );

    blocTest<UserBloc, UserState>(
      'surfaces a user-friendly error when update fails',
      build: () =>
          UserBloc(userService: _FakeUserService()..throwOnUpdate = true),
      act: (bloc) => bloc.add(
        const OnUpdateUserProfileEvent(
          uid: 'u1',
          firstName: 'X',
          lastName: 'Y',
        ),
      ),
      expect: () => [
        isA<UserState>().having((s) => s.isSaving, 'saving', true),
        isA<UserState>()
            .having((s) => s.isSaving, 'saving', false)
            .having((s) => s.error, 'error', contains('update failed')),
      ],
    );

    blocTest<UserBloc, UserState>(
      'avatar upload persists the new URL',
      build: () => UserBloc(
        userService: _FakeUserService(
          user: User(
            uid: 'u1',
            email: 'a@b.com',
            firstName: 'A',
            lastName: 'B',
            rolId: 2,
          ),
        ),
      ),
      act: (bloc) => bloc.add(
        OnUploadAvatarBytesEvent(
          uid: 'u1',
          bytes: Uint8List.fromList([1, 2, 3]),
          mime: 'image/jpeg',
        ),
      ),
      verify: (bloc) {
        expect(bloc.state.user?.image, isNotNull);
        expect(bloc.state.isUploadingAvatar, isFalse);
      },
    );

    blocTest<UserBloc, UserState>(
      'avatar upload failure surfaces a user-friendly error',
      build: () =>
          UserBloc(userService: _FakeUserService()..throwOnAvatar = true),
      act: (bloc) => bloc.add(
        OnUploadAvatarBytesEvent(uid: 'u1', bytes: Uint8List.fromList([1])),
      ),
      expect: () => [
        isA<UserState>().having((s) => s.isUploadingAvatar, 'busy', true),
        isA<UserState>()
            .having((s) => s.isUploadingAvatar, 'busy', false)
            .having((s) => s.error, 'error', contains('avatar failed')),
      ],
    );

    blocTest<UserBloc, UserState>(
      'exposes the inline avatar bytes after loading the profile',
      build: () => UserBloc(
        userService: _FakeUserService(
          user: User(
            uid: 'u1',
            email: 'a@b.com',
            firstName: 'A',
            lastName: 'B',
            rolId: 2,
          ),
        )..avatarBytes = Uint8List.fromList([9, 8, 7]),
      ),
      act: (bloc) => bloc.add(const OnLoadUserProfileEvent(uid: 'u1')),
      verify: (bloc) {
        expect(bloc.state.avatarBytes, isNotNull);
        expect(bloc.state.avatarBytes!.length, 3);
      },
    );
  });
}
