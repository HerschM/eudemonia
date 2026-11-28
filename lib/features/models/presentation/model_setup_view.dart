import 'package:flutter/material.dart';
import 'package:eudemonia/features/models/domain/model_availability.dart';
import 'package:eudemonia/features/models/domain/model_catalogue.dart';
import 'package:eudemonia/features/models/presentation/model_setup_texts.dart';
import 'package:eudemonia/features/models/presentation/model_setup_view_data.dart';
import 'package:eudemonia/features/theme/app_colors.dart';
import 'package:eudemonia/features/theme/widgets/pulse_dots_loader.dart';

/// The body of the model setup screen: the choice of speech model, the choice of writing model
/// and the Wi-Fi switch. Pure presentational widget, fed by plain values and callbacks.
class ModelSetupView extends StatelessWidget {
  final ModelSetupData data;
  final ValueChanged<String> onDownload;
  final ValueChanged<String> onCancel;
  final ValueChanged<String> onDelete;
  final ValueChanged<String> onSelect;
  final ValueChanged<bool> onWifiOnlyChanged;

  const ModelSetupView({
    super.key,
    required this.data,
    required this.onDownload,
    required this.onCancel,
    required this.onDelete,
    required this.onSelect,
    required this.onWifiOnlyChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(4, 0, 4, 16),
          child: Text(
            'Eudemonia runs on this phone. It needs two model files, downloaded once.',
            style: TextStyle(fontSize: 13, height: 1.4, color: AppColors.textSecondary),
          ),
        ),
        const _SectionHeader('Speech model'),
        const Padding(
          padding: EdgeInsets.fromLTRB(4, 0, 4, 10),
          child: Text(
            'Turns your recordings into text. Choose one.',
            style: TextStyle(fontSize: 12, height: 1.4, color: AppColors.textSecondary),
          ),
        ),
        for (final card in data.speechModels) ...[
          ModelCard(
            data: card,
            onDownload: onDownload,
            onCancel: onCancel,
            onDelete: onDelete,
            onSelect: onSelect,
          ),
          const SizedBox(height: 12),
        ],
        const SizedBox(height: 12),
        const _SectionHeader('Writing model'),
        const Padding(
          padding: EdgeInsets.fromLTRB(4, 0, 4, 10),
          child: Text(
            'Used by Synthesis to turn your thoughts into notes. Choose one.',
            style: TextStyle(fontSize: 12, height: 1.4, color: AppColors.textSecondary),
          ),
        ),
        if (data.loading)
          const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Center(child: PulseDotsLoader()))
        else if (data.noModelFitsMessage != null)
          _InfoCard(key: const Key('model_no_fit_message'), message: data.noModelFitsMessage!)
        else
          for (final card in data.languageModels) ...[
            ModelCard(
              data: card,
              onDownload: onDownload,
              onCancel: onCancel,
              onDelete: onDelete,
              onSelect: onSelect,
            ),
            const SizedBox(height: 12),
          ],
        const SizedBox(height: 12),
        Material(
          color: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppColors.cardRadius),
            side: const BorderSide(color: AppColors.borderSubtle),
          ),
          child: SwitchListTile(
            key: const Key('model_wifi_only_switch'),
            value: data.wifiOnly,
            onChanged: onWifiOnlyChanged,
            activeThumbColor: AppColors.accentAction,
            title: const Text(
              'Download on Wi-Fi only',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
            ),
            subtitle: const Text(
              'Models are large. Turn this off to allow mobile data.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 6),
      child: Text(
        title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String message;

  const _InfoCard({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: AppColors.cardDecoration(),
      child: Text(
        message,
        style: const TextStyle(fontSize: 13, height: 1.4, color: AppColors.textPrimary),
      ),
    );
  }
}

/// One model: what it is, what it costs and where its download stands.
class ModelCard extends StatelessWidget {
  final ModelCardData data;

  final ValueChanged<String> onDownload;
  final ValueChanged<String> onCancel;
  final ValueChanged<String> onDelete;
  final ValueChanged<String> onSelect;

  const ModelCard({
    super.key,
    required this.data,
    required this.onDownload,
    required this.onCancel,
    required this.onDelete,
    required this.onSelect,
  });

  ModelSpec get _spec => data.spec;
  ModelAvailability get _availability => data.availability;

  @override
  Widget build(BuildContext context) {
    final description = _spec.qualityLine;
    final ready = _availability.isReady && data.fits;
    final header = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            // The name takes the free width so the menu sits at the card's right edge.
            Expanded(
              child: Text(
                _spec.displayName,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
            ),
            if (ready)
              PopupMenuButton<String>(
                key: Key('model_menu_${_spec.id}'),
                tooltip: 'More',
                padding: EdgeInsets.zero,
                iconSize: 20,
                icon: const Icon(Icons.more_vert, color: AppColors.textSecondary),
                color: AppColors.surfaceElevated,
                onSelected: (value) {
                  if (value == 'delete') onDelete(_spec.id);
                },
                itemBuilder: (_) => [
                  PopupMenuItem<String>(
                    key: Key('model_delete_${_spec.id}'),
                    value: 'delete',
                    child: const Text('Delete', style: TextStyle(color: AppColors.textPrimary)),
                  ),
                ],
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(description, style: const TextStyle(fontSize: 12.5, height: 1.4, color: AppColors.textSecondary)),
        const SizedBox(height: 4),
        Text(
          describeModelDownload(_spec),
          style: const TextStyle(fontSize: 12, height: 1.4, color: AppColors.textTertiary),
        ),
      ],
    );

    return Material(
      key: Key('model_card_${_spec.id}'),
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppColors.cardRadius),
        side: BorderSide(color: data.selected && ready ? AppColors.accentAction : AppColors.borderSubtle),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: data.fits
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [header, const SizedBox(height: 10), _buildState()],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Opacity(key: Key('model_greyed_${_spec.id}'), opacity: 0.45, child: header),
                  const SizedBox(height: 10),
                  Text(
                    data.doesNotFitMessage ?? '',
                    key: Key('model_unfit_message_${_spec.id}'),
                    style: const TextStyle(fontSize: 12.5, height: 1.4, color: AppColors.accentWarning),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildState() {
    final id = _spec.id;
    switch (_availability.kind) {
      case ModelAvailabilityKind.absent:
        return _actionRow(
          const SizedBox.shrink(),
          _button('Download', Key('model_download_$id'), () => onDownload(id)),
        );
      case ModelAvailabilityKind.downloading:
        return _progress(describeProgress(_availability));
      case ModelAvailabilityKind.paused:
        return _progress(
          '${describeModelReason(_availability.reason, failed: false)} · ${describeProgress(_availability)}',
        );
      case ModelAvailabilityKind.verifying:
        return const Row(
          key: Key('model_verifying'),
          children: [
            PulseDotsLoader(),
            SizedBox(width: 10),
            Text('Checking file…', style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
          ],
        );
      case ModelAvailabilityKind.ready:
        return _readyRow();
      case ModelAvailabilityKind.failed:
        return _actionRow(
          Text(
            describeModelReason(_availability.reason, failed: true),
            key: Key('model_failure_$id'),
            style: const TextStyle(fontSize: 12.5, height: 1.4, color: AppColors.accentError),
          ),
          _button('Try again', Key('model_retry_$id'), () => onDownload(id)),
        );
    }
  }

  Widget _progress(String label) {
    final id = _spec.id;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            key: Key('model_progress_$id'),
            value: _availability.fraction,
            minHeight: 3,
            color: AppColors.accentAction,
            backgroundColor: AppColors.borderSubtle,
          ),
        ),
        const SizedBox(height: 8),
        _actionRow(
          Text(label, key: Key('model_progress_label_$id'), style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
          _button('Cancel', Key('model_cancel_$id'), () => onCancel(id), primary: false),
        ),
      ],
    );
  }

  Widget _readyRow() {
    final id = _spec.id;
    return _actionRow(
      Row(
        key: Key('model_ready_$id'),
        children: [
          Icon(
            data.selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
            size: 18,
            color: data.selected ? AppColors.accentAction : AppColors.textTertiary,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              data.selected ? 'In use' : 'Ready',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: data.selected ? AppColors.accentAction : AppColors.accentCapture,
              ),
            ),
          ),
        ],
      ),
      data.selected ? null : _button('Use this model', Key('model_use_$id'), () => onSelect(id)),
    );
  }

  Widget _actionRow(Widget status, Widget? action) {
    return Row(
      children: [
        Expanded(child: status),
        if (action != null) ...[const SizedBox(width: 8), action],
      ],
    );
  }

  Widget _button(String label, Key key, VoidCallback onPressed, {bool primary = true}) {
    return TextButton(
      key: key,
      style: TextButton.styleFrom(
        foregroundColor: primary ? Colors.white : AppColors.textSecondary,
        backgroundColor: primary ? AppColors.accentAction : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        minimumSize: const Size(48, 36),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppColors.badgeRadius)),
      ),
      onPressed: onPressed,
      child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
    );
  }
}
