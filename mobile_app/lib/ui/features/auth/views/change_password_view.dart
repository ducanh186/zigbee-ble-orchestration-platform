import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../l10n/localized_error_message.dart';
import '../../../core/theme/app_theme.dart';
import '../view_models/auth_view_model.dart';

class ChangePasswordView extends StatefulWidget {
  const ChangePasswordView({super.key});

  @override
  State<ChangePasswordView> createState() => _ChangePasswordViewState();
}

class _ChangePasswordViewState extends State<ChangePasswordView> {
  final _formKey = GlobalKey<FormState>();
  final _oldPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();

  @override
  void dispose() {
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit(AuthViewModel viewModel) async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    await viewModel.changePassword(
      oldPassword: _oldPasswordController.text,
      newPassword: _newPasswordController.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final l10n = AppLocalizations.of(context)!;
    final viewModel = context.watch<AuthViewModel>();

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      l10n.changePasswordTitle,
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _oldPasswordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: l10n.currentPasswordLabel,
                      ),
                      validator: (value) => value == null || value.isEmpty
                          ? l10n.requiredMessage
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _newPasswordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: l10n.newPasswordLabel,
                      ),
                      validator: (value) {
                        if (value == null || value.length < 8) {
                          return l10n.passwordMinimumMessage;
                        }
                        return null;
                      },
                    ),
                    if (viewModel.errorMessage != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        localizedErrorMessage(l10n, viewModel.errorMessage!),
                        style: TextStyle(color: palette.error),
                      ),
                    ],
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: viewModel.isLoading
                          ? null
                          : () => _submit(viewModel),
                      child: viewModel.isLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(l10n.updatePasswordAction),
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
