import 'package:flutter/material.dart';
import 'package:eudemonia/features/theme/app_colors.dart';

/// Small link at the foot of Settings to the licence page (models and open-source libraries).
class LicencesLink extends StatelessWidget {
  const LicencesLink({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TextButton(
        key: const Key('settings_licences_link'),
        style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
        onPressed: () => showLicensePage(context: context, applicationName: 'Eudemonia'),
        child: const Text('Open-source licences', style: TextStyle(fontSize: 12.5)),
      ),
    );
  }
}
