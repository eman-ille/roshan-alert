import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '/Helping_Files/app_theme.dart';
import '/Helping_Files/app_card.dart';
import '/Helping_Files/bottom_nav.dart';
import '/Helping_Files/app_location.dart';
import '/Helping_Files/address_store.dart';
import '/Helping_Files/schedule_store.dart';
import '/Helping_Files/self_status_store.dart';
import '/Helping_Files/location_data.dart';
import '/Helping_Files/location_dropdown.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Working copies used only while the Location bottom sheet is open —
  // kept separate from AppLocation so a cancelled edit doesn't half-save.
  String? _draftProvince;
  String? _draftCity;
  String? _draftArea;

  Future<void> _openLocationSheet() async {
    _draftProvince = AppLocation.province;
    _draftCity = AppLocation.city;
    _draftArea = AppLocation.area;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.large),
        ),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                20,
                20,
                MediaQuery.of(sheetContext).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Change Location',
                    style: Theme.of(sheetContext).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  LocationDropdown(
                    label: 'Province',
                    value: _draftProvince,
                    items: LocationData.provinces,
                    outlined: false,
                    onChanged: (v) => setSheetState(() {
                      _draftProvince = v;
                      _draftCity = null;
                      _draftArea = null;
                    }),
                  ),
                  const SizedBox(height: 12),
                  LocationDropdown(
                    label: 'City',
                    value: _draftCity,
                    items: LocationData.citiesFor(_draftProvince),
                    enabled: _draftProvince != null,
                    disabledHint: 'Select province first',
                    outlined: false,
                    onChanged: (v) => setSheetState(() {
                      _draftCity = v;
                      _draftArea = null;
                    }),
                  ),
                  const SizedBox(height: 12),
                  LocationDropdown(
                    label: 'Area',
                    value: _draftArea,
                    items: LocationData.areasFor(_draftCity),
                    enabled: _draftCity != null,
                    disabledHint: 'Select city first',
                    outlined: false,
                    onChanged: (v) => setSheetState(() => _draftArea = v),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        if (_draftProvince == null ||
                            _draftCity == null ||
                            _draftArea == null) {
                          ScaffoldMessenger.of(sheetContext).showSnackBar(
                            const SnackBar(
                              content: Text('Please complete all fields.'),
                            ),
                          );
                          return;
                        }
                        await AppLocation.set(
                          utility: AppLocation.utility.value,
                          province: _draftProvince!,
                          city: _draftCity!,
                          area: _draftArea!,
                        );
                        if (sheetContext.mounted) {
                          Navigator.of(sheetContext).pop();
                        }
                        if (!mounted) return;
                        setState(() {});
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Location updated.')),
                        );
                      },
                      child: const Text('Save Location'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _openUtilitySheet() async {
    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.large),
        ),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Text(
                'Select Utility',
                style: Theme.of(sheetContext).textTheme.titleMedium,
              ),
              ListTile(
                leading: const Icon(Icons.bolt_rounded),
                title: const Text('Electricity'),
                trailing: AppLocation.utility.value == 'Electricity'
                    ? const Icon(Icons.check_rounded)
                    : null,
                onTap: () async {
                  await AppLocation.set(
                    utility: 'Electricity',
                    province: AppLocation.province ?? '',
                    city: AppLocation.city ?? '',
                    area: AppLocation.area ?? '',
                  );
                  if (sheetContext.mounted) Navigator.of(sheetContext).pop();
                  if (mounted) setState(() {});
                },
              ),
              ListTile(
                leading: const Icon(Icons.local_fire_department_rounded),
                title: const Text('Gas'),
                trailing: AppLocation.utility.value == 'Gas'
                    ? const Icon(Icons.check_rounded)
                    : null,
                onTap: () async {
                  await AppLocation.set(
                    utility: 'Gas',
                    province: AppLocation.province ?? '',
                    city: AppLocation.city ?? '',
                    area: AppLocation.area ?? '',
                  );
                  if (sheetContext.mounted) Navigator.of(sheetContext).pop();
                  if (mounted) setState(() {});
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<void> _handleChangePassword() async {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isSaving = false;
    bool obscureCurrent = true;
    bool obscureNew = true;
    bool obscureConfirm = true;

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: const Text('Change Password'),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: currentPasswordController,
                        obscureText: obscureCurrent,
                        decoration: InputDecoration(
                          labelText: 'Current Password',
                          suffixIcon: IconButton(
                            icon: Icon(
                              obscureCurrent
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                            onPressed: () => setDialogState(
                              () => obscureCurrent = !obscureCurrent,
                            ),
                          ),
                        ),
                        validator: (v) =>
                            (v == null || v.isEmpty) ? 'Required' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: newPasswordController,
                        obscureText: obscureNew,
                        decoration: InputDecoration(
                          labelText: 'New Password',
                          suffixIcon: IconButton(
                            icon: Icon(
                              obscureNew
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                            onPressed: () =>
                                setDialogState(() => obscureNew = !obscureNew),
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Required';
                          if (v.length < 8) return 'At least 8 characters';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: confirmPasswordController,
                        obscureText: obscureConfirm,
                        decoration: InputDecoration(
                          labelText: 'Confirm New Password',
                          suffixIcon: IconButton(
                            icon: Icon(
                              obscureConfirm
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                            onPressed: () => setDialogState(
                              () => obscureConfirm = !obscureConfirm,
                            ),
                          ),
                        ),
                        validator: (v) {
                          if (v != newPasswordController.text) {
                            return 'Passwords do not match';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          setDialogState(() => isSaving = true);
                          try {
                            final user = FirebaseAuth.instance.currentUser;
                            final email = user?.email;
                            if (user == null || email == null) {
                              throw FirebaseAuthException(code: 'no-user');
                            }
                            final credential = EmailAuthProvider.credential(
                              email: email,
                              password: currentPasswordController.text,
                            );
                            await user.reauthenticateWithCredential(credential);
                            await user.updatePassword(
                              newPasswordController.text,
                            );

                            if (!dialogContext.mounted) return;
                            Navigator.of(dialogContext).pop();
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Password updated successfully.'),
                              ),
                            );
                          } on FirebaseAuthException catch (e) {
                            String message;
                            switch (e.code) {
                              case 'wrong-password':
                              case 'invalid-credential':
                                message = 'Current password is incorrect.';
                                break;
                              case 'weak-password':
                                message = 'Please choose a stronger password.';
                                break;
                              default:
                                message =
                                    e.message ?? 'Could not update password.';
                            }
                            setDialogState(() => isSaving = false);
                            if (!dialogContext.mounted) return;
                            ScaffoldMessenger.of(
                              dialogContext,
                            ).showSnackBar(SnackBar(content: Text(message)));
                          } catch (e) {
                            setDialogState(() => isSaving = false);
                          }
                        },
                  child: isSaving
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Update'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text(
          'You will need to log in again to use Roshan Alert.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      ScheduleStore.reset();
      AppLocation.reset();
      await UserStatusOverride.clear();
      await AddressStore.clear();
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            _SectionLabel('LOCATION'),
            ValueListenableBuilder<String>(
              valueListenable: AppLocation.current,
              builder: (context, location, _) {
                return AppCard(
                  padding: EdgeInsets.zero,
                  child: _SettingsRow(
                    icon: Icons.place_rounded,
                    label: location,
                    onTap: _openLocationSheet,
                  ),
                );
              },
            ),
            const SizedBox(height: 28),

            _SectionLabel('PREFERENCES'),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  ValueListenableBuilder<ThemeMode>(
                    valueListenable: AppThemeController.mode,
                    builder: (context, mode, _) {
                      return SwitchListTile(
                        secondary: const Icon(Icons.dark_mode_rounded),
                        title: const Text('Dark Mode'),
                        value: mode == ThemeMode.dark,
                        onChanged: (isDark) =>
                            AppThemeController.toggle(isDark),
                      );
                    },
                  ),
                  const Divider(height: 1),
                  ValueListenableBuilder<String>(
                    valueListenable: AppLocation.utility,
                    builder: (context, utility, _) {
                      return _SettingsRow(
                        icon: utility == 'Gas'
                            ? Icons.local_fire_department_rounded
                            : Icons.bolt_rounded,
                        label: 'Utility: $utility',
                        onTap: _openUtilitySheet,
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            _SectionLabel('ACCOUNT'),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _SettingsRow(
                    icon: Icons.lock_reset_rounded,
                    label: 'Change Password',
                    onTap: _handleChangePassword,
                  ),
                  const Divider(height: 1),
                  _SettingsRow(
                    icon: Icons.logout_rounded,
                    label: 'Log Out',
                    onTap: _handleLogout,
                    isDestructive: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const AppBottomNav(),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.grey,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;

  const _SettingsRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDestructive ? Colors.red : AppColors.black;
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w600),
      ),
      trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.grey),
      onTap: onTap,
    );
  }
}
