part of 'user_bloc.dart';

@immutable
abstract class UserEvent {
  const UserEvent();
}

class OnLoadUserProfileEvent extends UserEvent {
  final String uid;
  const OnLoadUserProfileEvent({required this.uid});
}

class OnWatchUserProfileEvent extends UserEvent {
  final String uid;
  const OnWatchUserProfileEvent({required this.uid});
}

class OnUpdateUserProfileEvent extends UserEvent {
  final String uid;
  final String? firstName;
  final String? lastName;
  final String? phone;
  const OnUpdateUserProfileEvent({
    required this.uid,
    this.firstName,
    this.lastName,
    this.phone,
  });
}

class OnUploadAvatarEvent extends UserEvent {
  final String uid;
  final File file;
  const OnUploadAvatarEvent({required this.uid, required this.file});
}

class OnUploadAvatarBytesEvent extends UserEvent {
  final String uid;
  final Uint8List bytes;
  final String? mime;
  const OnUploadAvatarBytesEvent({
    required this.uid,
    required this.bytes,
    this.mime,
  });
}

class OnClearUserProfileEvent extends UserEvent {
  const OnClearUserProfileEvent();
}
