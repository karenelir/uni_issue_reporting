import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/campus_places.dart';
import '../data/exceptions.dart';
import '../models/issue.dart';
import '../models/report_draft.dart';
import '../services/device_services.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/feedback.dart';
import '../widgets/format.dart';
import '../widgets/photo_image.dart';
import 'issue_details_screen.dart';
import 'report_sent_screen.dart';

/// Screens 4 and 5: the report form and its validation errors
/// (FR3 to FR7, FR19, FR20, NFR4, NFR8).
///
/// Follows patterns from 311 and campus apps: start with an optional photo
/// ("snap it"), pick the type of problem from icon tiles, describe it, and
/// pick the building from the USEK campus list.
class ReportFormScreen extends StatefulWidget {
  const ReportFormScreen({super.key, this.photoService, this.locationService});

  final PhotoService? photoService;
  final LocationService? locationService;

  @override
  State<ReportFormScreen> createState() => _ReportFormScreenState();
}

class _ReportFormScreenState extends State<ReportFormScreen> {
  final _title = TextEditingController();
  final _location = TextEditingController();
  final _room = TextEditingController();
  final _description = TextEditingController();
  final _focus = {for (final f in ReportField.values) f: FocusNode()};
  final _keys = {for (final f in ReportField.values) f: GlobalKey()};
  late final _photoService = widget.photoService ?? PhotoService();
  late final _locationService = widget.locationService ?? LocationService();

  IssueCategory? _category;
  bool _urgent = false;
  final List<String> _photos = [];
  Map<ReportField, String> _errors = {};
  bool _triedSubmit = false;
  bool _submitting = false;
  bool _locating = false;
  String? _submitError;
  List<Issue> _similar = const [];
  List<Issue> _atPlace = const [];

  @override
  void initState() {
    super.initState();
    _title.addListener(_onTitleChanged);
    _location.addListener(_onPlaceChanged);
  }

  @override
  void dispose() {
    _title.dispose();
    _location.dispose();
    _room.dispose();
    _description.dispose();
    for (final f in _focus.values) {
      f.dispose();
    }
    super.dispose();
  }

  bool get _isDirty =>
      _title.text.trim().isNotEmpty ||
      _location.text.trim().isNotEmpty ||
      _room.text.trim().isNotEmpty ||
      _description.text.trim().isNotEmpty ||
      _category != null ||
      _photos.isNotEmpty;

  /// "Building B, Lab 3": the building or area plus the optional room.
  String get _fullLocation {
    final place = _location.text.trim();
    final room = _room.text.trim();
    if (place.isEmpty || room.isEmpty) return place;
    return '$place, $room';
  }

  ReportDraft get _draft => ReportDraft(
        title: _title.text,
        description: _description.text,
        category: _category,
        location: _fullLocation,
        photoPaths: _photos,
        urgent: _urgent,
      );

  /// Open issues already reported in the chosen building (duplicate check).
  void _onPlaceChanged() {
    final place = _location.text.trim();
    setState(() => _atPlace =
        place.length >= 3 ? context.read<AppState>().issuesAtPlace(place) : const []);
    _revalidate();
  }

  void _onTitleChanged() {
    // Suggest existing issues before a duplicate is submitted (FR20).
    final text = _title.text.trim();
    final similar =
        text.length >= 4 ? context.read<AppState>().similarIssues(text) : const <Issue>[];
    setState(() => _similar = similar);
  }

  /// After the first submit attempt, errors update live as fields are fixed.
  void _revalidate() {
    if (_triedSubmit) setState(() => _errors = _draft.validate());
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _triedSubmit = true;
      _submitError = null;
      _errors = _draft.validate();
    });
    if (_errors.isNotEmpty) {
      // Take the student to the first field that needs fixing.
      final first = _fieldOrder.firstWhere(_errors.containsKey);
      final target = _keys[first]!.currentContext;
      if (target != null) {
        await Scrollable.ensureVisible(target,
            duration: const Duration(milliseconds: 250), alignment: 0.1);
      }
      if (first != ReportField.category && first != ReportField.photos) {
        _focus[first]!.requestFocus();
      }
      return;
    }

    setState(() => _submitting = true);
    try {
      final issue = await context.read<AppState>().submitReport(_draft);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => ReportSentScreen(issueId: issue.id)),
      );
    } on ValidationException catch (e) {
      setState(() => _errors = e.errors);
    } catch (e) {
      // The entered text stays in the form so it can be sent again (NFR8).
      setState(() => _submitError = describeError(e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  static const _fieldOrder = [
    ReportField.category,
    ReportField.title,
    ReportField.description,
    ReportField.location,
    ReportField.photos,
  ];

  Future<void> _close() async {
    if (!_isDirty) {
      Navigator.of(context).pop();
      return;
    }
    if (await _confirmDiscard() && mounted) Navigator.of(context).pop();
  }

  Future<bool> _confirmDiscard() => confirmAction(
        context,
        title: 'Discard this report?',
        message: 'What you entered will be lost.',
        confirmLabel: 'Discard',
        cancelLabel: 'Keep editing',
        destructive: true,
      );

  Future<void> _useMyLocation() async {
    setState(() => _locating = true);
    final result = await _locationService.currentLocationText();
    if (!mounted) return;
    setState(() => _locating = false);
    if (result.value != null) {
      if (_location.text.trim().isEmpty) {
        _location.text = result.value!;
        _onPlaceChanged();
      } else {
        final room = _room.text.trim();
        _room.text = room.isEmpty ? result.value! : '$room (${result.value})';
      }
      _revalidate();
      showMessage(context, 'Location added. You can add the building or room too.');
    } else {
      showMessage(context, result.error!);
      _focus[ReportField.location]!.requestFocus();
    }
  }

  Future<void> _addPhotos({required bool camera}) async {
    final remaining = ReportDraft.maxPhotos - _photos.length;
    if (remaining <= 0) return;
    final result = camera
        ? await _photoService.takePhoto()
        : await _photoService.pickFromGallery(limit: remaining);
    if (!mounted) return;
    if (result.error != null) {
      showMessage(context, result.error!);
      return;
    }
    final added = result.value!.take(remaining).toList();
    if (added.isEmpty) return;
    setState(() => _photos.addAll(added));
    showMessage(
      context,
      '${added.length} photo${added.length == 1 ? '' : 's'} added.',
      actionLabel: 'Undo',
      onAction: () => setState(() => _photos.removeWhere(added.contains)),
    );
  }

  void _choosePhotoSource() {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take photo'),
              onTap: () {
                Navigator.pop(context);
                _addPhotos(camera: true);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () {
                Navigator.pop(context);
                _addPhotos(camera: false);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _removePhoto(int index) {
    final removed = _photos[index];
    setState(() => _photos.removeAt(index));
    showMessage(
      context,
      'Photo removed.',
      actionLabel: 'Undo',
      onAction: () => setState(() => _photos.insert(index.clamp(0, _photos.length), removed)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isDirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmDiscard() && context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Cancel',
            icon: const Icon(Icons.close),
            onPressed: _close,
          ),
          title: const Text('Report an issue'),
          actions: [
            IconButton(
              tooltip: 'Tips for a good report',
              icon: const Icon(Icons.help_outline),
              onPressed: () => _showTips(context),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            if (_triedSubmit && _errors.isNotEmpty) ...[
              _Banner(
                icon: Icons.error_outline,
                text: 'Report not sent. Please fix the '
                    '${_errors.length == 1 ? 'field' : '${_errors.length} fields'} marked in red: '
                    '${_fieldOrder.where(_errors.containsKey).map((f) => f.label).join(', ')}.',
              ),
              const SizedBox(height: 12),
            ],
            if (_submitError != null) ...[
              _Banner(icon: Icons.cloud_off_outlined, text: _submitError!),
              const SizedBox(height: 12),
            ],
            _Section(
              key: _keys[ReportField.photos],
              step: 1,
              title: 'Start with a photo',
              subtitle: 'Optional, up to ${ReportDraft.maxPhotos}. A photo helps staff see the problem.',
              child: _PhotoPicker(
                photos: _photos,
                onRemove: _removePhoto,
                onAdd: _choosePhotoSource,
              ),
            ),
            _Section(
              key: _keys[ReportField.category],
              step: 2,
              title: 'What kind of problem is it?',
              child: _CategoryPicker(
                selected: _category,
                error: _errors[ReportField.category],
                onSelected: (c) {
                  setState(() => _category = c);
                  _revalidate();
                },
              ),
            ),
            _Section(
              key: _keys[ReportField.title],
              step: 3,
              title: 'Describe it',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _title,
                    focusNode: _focus[ReportField.title],
                    textInputAction: TextInputAction.next,
                    textCapitalization: TextCapitalization.sentences,
                    maxLength: ReportDraft.maxTitleLength,
                    decoration: InputDecoration(
                      labelText: 'Title',
                      hintText: 'e.g. Projector broken in Room 204',
                      errorText: _errors[ReportField.title],
                    ),
                    onChanged: (_) => _revalidate(),
                  ),
                  if (_similar.isNotEmpty)
                    _SimilarIssues(
                      heading: 'Already reported? Vote for it instead.',
                      issues: _similar,
                    ),
                  const SizedBox(height: 12),
                  TextField(
                    key: _keys[ReportField.description],
                    controller: _description,
                    focusNode: _focus[ReportField.description],
                    minLines: 3,
                    maxLines: 8,
                    maxLength: ReportDraft.maxDescriptionLength,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      labelText: 'Description',
                      hintText: 'What happened? Since when?',
                      alignLabelWithHint: true,
                      errorText: _errors[ReportField.description],
                    ),
                    onChanged: (_) => _revalidate(),
                  ),
                  _UrgentSwitch(
                    value: _urgent,
                    onChanged: (v) => setState(() => _urgent = v),
                  ),
                ],
              ),
            ),
            _Section(
              key: _keys[ReportField.location],
              step: 4,
              title: 'Where is it?',
              subtitle: 'Pick the USEK building or area, or type it.',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _PlacePicker(
                    controller: _location,
                    focusNode: _focus[ReportField.location]!,
                    errorText: _errors[ReportField.location],
                    onChanged: _onPlaceChanged,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _room,
                    textInputAction: TextInputAction.done,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Room or spot (optional)',
                      hintText: 'e.g. Lab 3, 2nd floor, near the entrance',
                      prefixIcon: Icon(Icons.meeting_room_outlined),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: _locating ? null : _useMyLocation,
                      icon: _locating
                          ? const SizedBox(
                              width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.my_location),
                      label: const Text('Use my current location'),
                    ),
                  ),
                  if (_atPlace.isNotEmpty)
                    _SimilarIssues(
                      heading: '${plural(_atPlace.length, 'open issue')} in '
                          '${placeOf(_location.text)}. Is yours one of them?',
                      issues: _atPlace.take(3).toList(),
                    ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  Icon(Icons.lock_outline, size: 16, color: AppColors.inkMuted),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text('Your name is never shown to other students.',
                        style: TextStyle(fontSize: 13, color: AppColors.inkMuted)),
                  ),
                ],
              ),
            ),
          ],
        ),
        bottomNavigationBar: Material(
          color: Colors.white,
          elevation: 8,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: FilledButton.icon(
                onPressed: _submitting ? null : _submit,
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                icon: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.send_rounded),
                label: const Text('Submit report'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showTips(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => const SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Tips for a good report',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
              SizedBox(height: 16),
              _Tip(Icons.category_outlined,
                  'Category: Facilities (rooms, labs, restrooms, cafeteria), Academic services '
                  '(portal, schedules, registration) or Infrastructure (Wi-Fi, power, buildings).'),
              _Tip(Icons.title, 'Title: say what is wrong and where, e.g. "Projector broken in Room 204".'),
              _Tip(Icons.notes, 'Description: what happened and since when.'),
              _Tip(Icons.place_outlined, 'Location: building and room, so staff can find it.'),
              _Tip(Icons.photo_camera_outlined,
                  'Photos are optional but help staff. Do not photograph people.'),
              _Tip(Icons.how_to_vote_outlined,
                  'If the problem is already in the feed, vote for it instead of reporting it again.'),
              _Tip(Icons.warning_amber_outlined,
                  'For emergencies or safety hazards, contact campus security directly.'),
            ],
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    super.key,
    required this.step,
    required this.title,
    required this.child,
    this.subtitle,
  });

  final int step;
  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 13,
                    backgroundColor: scheme.primaryContainer,
                    child: Text('$step',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: scheme.onPrimaryContainer)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Semantics(
                          header: true,
                          child: Text(title,
                              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                        ),
                        if (subtitle != null)
                          Text(subtitle!,
                              style: const TextStyle(fontSize: 13.5, color: AppColors.inkMuted)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

/// Category chosen from large icon tiles, as in 311 apps: the fixed list
/// of three (FR4) is always visible, so nothing has to be remembered.
class _CategoryPicker extends StatelessWidget {
  const _CategoryPicker({required this.selected, required this.error, required this.onSelected});

  final IssueCategory? selected;
  final String? error;
  final ValueChanged<IssueCategory> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final c in IssueCategory.values)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _CategoryTile(
              category: c,
              selected: selected == c,
              hasError: error != null,
              onTap: () => onSelected(c),
            ),
          ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(left: 4, top: 2),
            child: Text(error!, style: const TextStyle(color: AppColors.error, fontSize: 13.5)),
          ),
      ],
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.category,
    required this.selected,
    required this.hasError,
    required this.onTap,
  });

  final IssueCategory category;
  final bool selected;
  final bool hasError;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final style = CategoryStyle.of(category);
    final borderColor = selected
        ? AppColors.brand
        : (hasError ? AppColors.error : AppColors.outline);
    return Semantics(
      button: true,
      selected: selected,
      label: '${category.label}. ${style.examples}',
      excludeSemantics: true,
      child: Material(
        color: selected ? Theme.of(context).colorScheme.secondaryContainer.withValues(alpha: 0.5) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: borderColor, width: selected ? 2 : 1),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(color: style.background, shape: BoxShape.circle),
                  child: Icon(style.icon, color: style.foreground),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(category.label,
                          style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600)),
                      Text(style.examples,
                          style: const TextStyle(fontSize: 13, color: AppColors.inkMuted)),
                    ],
                  ),
                ),
                Icon(
                  selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                  color: selected ? AppColors.brand : AppColors.inkMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Tip extends StatelessWidget {
  const _Tip(this.icon, this.text);

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppColors.brand),
            const SizedBox(width: 12),
            Expanded(child: Text(text, style: const TextStyle(fontSize: 15))),
          ],
        ),
      );
}

class _Banner extends StatelessWidget {
  const _Banner({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.errorContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppColors.error),
            const SizedBox(width: 10),
            Expanded(child: Text(text, style: const TextStyle(fontSize: 14.5))),
          ],
        ),
      ),
    );
  }
}

/// "Already reported?" suggestions, by similar title (FR20) or by the same
/// building.
class _SimilarIssues extends StatelessWidget {
  const _SimilarIssues({required this.heading, required this.issues});

  final String heading;
  final List<Issue> issues;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      decoration: BoxDecoration(
        color: AppColors.warningContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lightbulb_outline, size: 18, color: AppColors.onWarningContainer),
              const SizedBox(width: 6),
              Expanded(
                child: Text(heading,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, color: AppColors.onWarningContainer)),
              ),
            ],
          ),
          for (final issue in issues)
            InkWell(
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => IssueDetailsScreen(issueId: issue.id),
              )),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(issue.title,
                          style: const TextStyle(
                              color: AppColors.onWarningContainer,
                              decoration: TextDecoration.underline)),
                    ),
                    const SizedBox(width: 8),
                    Text('${issue.votes} votes',
                        style: const TextStyle(color: AppColors.onWarningContainer)),
                    const Icon(Icons.chevron_right, color: AppColors.onWarningContainer),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PhotoPicker extends StatelessWidget {
  const _PhotoPicker({required this.photos, required this.onRemove, required this.onAdd});

  final List<String> photos;
  final ValueChanged<int> onRemove;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (var i = 0; i < photos.length; i++)
          Stack(
            clipBehavior: Clip.none,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 92,
                  height: 92,
                  child: photoImage(
                    photos[i],
                    semanticLabel: 'Photo ${i + 1}',
                    errorBuilder: (_, _, _) => const ColoredBox(
                      color: AppColors.background,
                      child: Icon(Icons.broken_image_outlined),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: -12,
                right: -12,
                child: IconButton.filledTonal(
                  tooltip: 'Remove photo ${i + 1}',
                  iconSize: 18,
                  icon: const Icon(Icons.close),
                  onPressed: () => onRemove(i),
                ),
              ),
            ],
          ),
        if (photos.length < ReportDraft.maxPhotos)
          Semantics(
            button: true,
            label: 'Add a photo',
            excludeSemantics: true,
            child: Material(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                onTap: onAdd,
                borderRadius: BorderRadius.circular(12),
                child: const SizedBox(
                  width: 92,
                  height: 92,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_a_photo_outlined, color: AppColors.brand),
                      SizedBox(height: 4),
                      Text('Add', style: TextStyle(color: AppColors.brand, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Building or area picked from the USEK campus list, with search; any
/// other place can still be typed (FR6).
class _PlacePicker extends StatelessWidget {
  const _PlacePicker({
    required this.controller,
    required this.focusNode,
    required this.errorText,
    required this.onChanged,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String? errorText;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownMenu<String>(
      controller: controller,
      focusNode: focusNode,
      expandedInsets: EdgeInsets.zero,
      enableFilter: true,
      requestFocusOnTap: true,
      menuHeight: 320,
      label: const Text('Building or area'),
      hintText: 'e.g. Building B',
      errorText: errorText,
      leadingIcon: const Icon(Icons.place_outlined),
      onSelected: (_) => onChanged(),
      dropdownMenuEntries: [
        for (final place in campusPlaces)
          DropdownMenuEntry(
            value: place.name,
            label: place.name,
            labelWidget: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(place.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                if (place.hint != null)
                  Text(place.hint!,
                      style: const TextStyle(fontSize: 13, color: AppColors.inkMuted)),
              ],
            ),
          ),
      ],
    );
  }
}

/// Lets the reporter flag a safety hazard, so serious issues stand out
/// even with few votes (assumption A3).
class _UrgentSwitch extends StatelessWidget {
  const _UrgentSwitch({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: SwitchListTile(
        tileColor: value ? AppColors.errorContainer : AppColors.background,
        value: value,
        onChanged: onChanged,
        secondary: Icon(Icons.warning_amber_rounded,
            color: value ? AppColors.error : AppColors.inkMuted),
        title: const Text('Safety hazard or urgent',
            style: TextStyle(fontWeight: FontWeight.w600)),
        subtitle: const Text('e.g. exposed wires, water leak, blocked exit. '
            'For emergencies, call campus security.'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
