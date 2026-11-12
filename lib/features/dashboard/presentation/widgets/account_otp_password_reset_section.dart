import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../auth/domain/repositories/auth_repository.dart';
import '../../../auth/presentation/bloc/forgot_password_cubit.dart';
import '../../../auth/presentation/bloc/forgot_password_state.dart';

/// Inline 3-step OTP verification and password reset flow for an
/// authenticated user inside the account profile dialog.
///
/// Steps:
/// 1. Request OTP for the current authenticated user's account.
/// 2. Verify the received 6-digit OTP (with resend cooldown support).
/// 3. Enter and confirm the new password once OTP verification succeeds.
class AccountOtpPasswordResetSection extends StatelessWidget {
  final String userId;
  final AuthRepository? authRepository;
  final VoidCallback onPasswordChanged;

  const AccountOtpPasswordResetSection({
    super.key,
    required this.userId,
    required this.authRepository,
    required this.onPasswordChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (authRepository == null) {
      return Container(
        key: const Key('account_otp_flow_container'),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: Container(
          key: const Key('account_otp_error_banner'),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: colorScheme.errorContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                Icons.error_outline,
                size: 18,
                color: colorScheme.onErrorContainer,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'OTP verification service is unavailable. Please sign in again or contact an administrator.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onErrorContainer,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return BlocProvider<ForgotPasswordCubit>(
      create: (_) => ForgotPasswordCubit(
        repository: authRepository!,
        initialIdentifier: userId,
      ),
      child: _AccountOtpPasswordResetContent(
        onPasswordChanged: onPasswordChanged,
      ),
    );
  }
}

class _AccountOtpPasswordResetContent extends StatefulWidget {
  final VoidCallback onPasswordChanged;

  const _AccountOtpPasswordResetContent({required this.onPasswordChanged});

  @override
  State<_AccountOtpPasswordResetContent> createState() =>
      _AccountOtpPasswordResetContentState();
}

class _AccountOtpPasswordResetContentState
    extends State<_AccountOtpPasswordResetContent> {
  final TextEditingController _otpController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _otpController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _clearInputs() {
    _otpController.clear();
    _newPasswordController.clear();
    _confirmPasswordController.clear();
  }

  int _resolveStepIndex(ForgotPasswordState state) {
    return switch (state) {
      ForgotPasswordIdentifyState() => 1,
      ForgotPasswordVerifyOtpState() => 2,
      ForgotPasswordSetNewPasswordState() => 3,
      ForgotPasswordSuccessState() => 3,
    };
  }

  String? _extractErrorMessage(ForgotPasswordState state) {
    return switch (state) {
      ForgotPasswordIdentifyState(:final errorMessage) => errorMessage,
      ForgotPasswordVerifyOtpState(:final errorMessage) => errorMessage,
      ForgotPasswordSetNewPasswordState(:final errorMessage) => errorMessage,
      ForgotPasswordSuccessState() => null,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return BlocConsumer<ForgotPasswordCubit, ForgotPasswordState>(
      listener: (context, state) {
        if (state is ForgotPasswordSuccessState) {
          _clearInputs();
          widget.onPasswordChanged();
        } else if (state is ForgotPasswordIdentifyState) {
          _clearInputs();
        }
      },
      builder: (context, state) {
        final currentStep = _resolveStepIndex(state);
        final errorMessage = _extractErrorMessage(state);

        return Container(
          key: const Key('account_otp_flow_container'),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colorScheme.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildStepTracker(context, currentStep),
              const SizedBox(height: 12),
              if (errorMessage != null) ...[
                Container(
                  key: const Key('account_otp_error_banner'),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 18,
                        color: colorScheme.onErrorContainer,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          errorMessage,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onErrorContainer,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              _buildStepContent(context, state),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStepTracker(BuildContext context, int currentStep) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    Widget buildPill(int step, String label) {
      final isDone = currentStep > step;
      final isActive = currentStep == step;

      final bg = isActive
          ? colorScheme.primaryContainer
          : (isDone
                ? colorScheme.surfaceContainerHighest
                : colorScheme.surface);
      final fg = isActive
          ? colorScheme.onPrimaryContainer
          : (isDone ? colorScheme.primary : colorScheme.onSurfaceVariant);

      return Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isActive
                  ? colorScheme.primary.withValues(alpha: 0.45)
                  : colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isDone)
                Icon(Icons.check_circle_rounded, size: 13, color: fg)
              else
                CircleAvatar(
                  radius: 7,
                  backgroundColor: fg.withValues(alpha: 0.18),
                  child: Text(
                    '$step',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: fg,
                    ),
                  ),
                ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: fg,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Row(
      children: [
        buildPill(1, 'Send OTP'),
        const SizedBox(width: 6),
        buildPill(2, 'Verify OTP'),
        const SizedBox(width: 6),
        buildPill(3, 'Password'),
      ],
    );
  }

  Widget _buildStepContent(BuildContext context, ForgotPasswordState state) {
    return switch (state) {
      ForgotPasswordIdentifyState() => _buildRequestOtpStep(context, state),
      ForgotPasswordVerifyOtpState() => _buildVerifyOtpStep(context, state),
      ForgotPasswordSetNewPasswordState() => _buildNewPasswordStep(
        context,
        state,
      ),
      ForgotPasswordSuccessState() => const SizedBox.shrink(),
    };
  }

  Widget _buildRequestOtpStep(
    BuildContext context,
    ForgotPasswordIdentifyState state,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final cubit = context.read<ForgotPasswordCubit>();

    return Column(
      key: const Key('account_otp_step_1'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Verify your identity with a 6-digit OTP before changing the password for @${state.identifier}.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            key: const Key('account_send_otp_button'),
            onPressed: state.isSubmitting ? null : cubit.sendOtp,
            icon: state.isSubmitting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.mark_email_read_outlined, size: 18),
            label: const Text('Send OTP'),
          ),
        ),
      ],
    );
  }

  Widget _buildVerifyOtpStep(
    BuildContext context,
    ForgotPasswordVerifyOtpState state,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final cubit = context.read<ForgotPasswordCubit>();

    return Column(
      key: const Key('account_otp_step_2'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Enter the 6-digit OTP sent to ${state.maskedEmail}. Expires in 5 minutes.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        if (state.debugOtpCode != null) ...[
          const SizedBox(height: 8),
          Container(
            key: const Key('account_otp_demo_badge'),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: colorScheme.primary.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.mark_email_read_outlined,
                  size: 16,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'Received OTP: ${state.debugOtpCode}',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        TextFormField(
          key: const Key('account_otp_field'),
          controller: _otpController,
          enabled: !state.isSubmitting,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(6),
          ],
          decoration: InputDecoration(
            labelText: '6-Digit OTP',
            hintText: 'Enter 6-digit verification code',
            prefixIcon: const Icon(Icons.pin_outlined, size: 20),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
          textInputAction: TextInputAction.done,
          onChanged: cubit.updateOtpCode,
          onFieldSubmitted: (_) {
            cubit.updateOtpCode(_otpController.text);
            cubit.verifyOtp();
          },
        ),
        const SizedBox(height: 12),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton(
                  key: const Key('account_otp_back_button'),
                  onPressed: state.isSubmitting ? null : cubit.goToIdentifyStep,
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                  ),
                  child: const Text('Back'),
                ),
                const SizedBox(width: 4),
                if (state.canResend)
                  TextButton.icon(
                    key: const Key('account_resend_otp_button'),
                    onPressed: () {
                      _otpController.clear();
                      cubit.updateOtpCode('');
                      cubit.resendOtp();
                    },
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Resend OTP'),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                    ),
                  )
                else
                  Text(
                    'Resend in ${state.cooldownSecondsRemaining}s',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
            FilledButton.icon(
              key: const Key('account_verify_otp_button'),
              onPressed: state.isSubmitting
                  ? null
                  : () {
                      cubit.updateOtpCode(_otpController.text);
                      cubit.verifyOtp();
                    },
              icon: state.isSubmitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.verified_user_outlined, size: 18),
              label: const Text('Verify OTP'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildNewPasswordStep(
    BuildContext context,
    ForgotPasswordSetNewPasswordState state,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final cubit = context.read<ForgotPasswordCubit>();

    return Column(
      key: const Key('account_otp_step_3'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          key: const Key('account_otp_verified_badge'),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: colorScheme.primary.withValues(alpha: 0.35),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.verified_user_outlined,
                size: 16,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  'OTP verified. Set a new password (min 6 characters).',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          key: const Key('account_new_password_field'),
          controller: _newPasswordController,
          enabled: !state.isSubmitting,
          obscureText: _obscureNewPassword,
          decoration: InputDecoration(
            labelText: 'New Password',
            prefixIcon: const Icon(Icons.password, size: 20),
            suffixIcon: IconButton(
              key: const Key('account_new_password_visibility_toggle'),
              icon: Icon(
                _obscureNewPassword ? Icons.visibility_off : Icons.visibility,
                size: 20,
              ),
              onPressed: () =>
                  setState(() => _obscureNewPassword = !_obscureNewPassword),
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 12),
        TextFormField(
          key: const Key('account_confirm_password_field'),
          controller: _confirmPasswordController,
          enabled: !state.isSubmitting,
          obscureText: _obscureConfirmPassword,
          decoration: InputDecoration(
            labelText: 'Confirm Password',
            prefixIcon: const Icon(Icons.password, size: 20),
            suffixIcon: IconButton(
              key: const Key('account_confirm_password_visibility_toggle'),
              icon: Icon(
                _obscureConfirmPassword
                    ? Icons.visibility_off
                    : Icons.visibility,
                size: 20,
              ),
              onPressed: () => setState(
                () => _obscureConfirmPassword = !_obscureConfirmPassword,
              ),
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) => cubit.completeReset(
            newPassword: _newPasswordController.text,
            confirmPassword: _confirmPasswordController.text,
          ),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.tonalIcon(
            key: const Key('account_save_password_button'),
            onPressed: state.isSubmitting
                ? null
                : () => cubit.completeReset(
                    newPassword: _newPasswordController.text,
                    confirmPassword: _confirmPasswordController.text,
                  ),
            icon: state.isSubmitting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check_circle_outline, size: 18),
            label: const Text('Update Password'),
          ),
        ),
      ],
    );
  }
}
