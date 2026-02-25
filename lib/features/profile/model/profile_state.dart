import 'package:webrtc_app/features/auth/model/user_model.dart';

enum ProfileStatus { idle, loading, success, error }

class ProfileState {
  final ProfileStatus status;
  final UserModel? user;
  final String? errorMessage;
  final String? successMessage;

  const ProfileState({
    required this.status,
    this.user,
    this.errorMessage,
    this.successMessage,
  });

  factory ProfileState.initial() =>
      const ProfileState(status: ProfileStatus.idle);

  factory ProfileState.loading(UserModel? user) =>
      ProfileState(status: ProfileStatus.loading, user: user);

  factory ProfileState.success(UserModel user, String message) => ProfileState(
    status: ProfileStatus.success,
    user: user,
    successMessage: message,
  );

  factory ProfileState.error(UserModel? user, String message) => ProfileState(
    status: ProfileStatus.error,
    user: user,
    errorMessage: message,
  );

  bool get isLoading => status == ProfileStatus.loading;
}
