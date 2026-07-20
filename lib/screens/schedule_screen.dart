import 'package:flutter/material.dart';
import '/Helping_Files/app_theme.dart';
import '/Helping_Files/app_card.dart';
import '/Helping_Files/bottom_nav.dart';
import '/Helping_Files/schedule_store.dart';

/// Where the user builds THEIR OWN outage schedule — from experience or
/// their DISCO's notice. This is deliberately framed as "your saved
/// schedule", never as something the app detected live, since we have
/// no real-time data source for that (see conversation history).
class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  Future<void> _addBlock() async {
    final range = await showDialog<RangeValues>(
      context: context,
      builder: (context) => const _AddBlockDialog(),
    );
    if (range == null) return;

    await ScheduleStore.addBlock(range.start.round(), range.end.round());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Your Schedule')),
      body: SafeArea(
        child: ValueListenableBuilder<List<ScheduleBlock>>(
          valueListenable: ScheduleStore.blocks,
          builder: (context, blocks, _) {
            if (blocks.isEmpty) {
              return _buildEmptyState(context);
            }
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
              children: [
                _buildIntro(),
                const SizedBox(height: 18),
                ...blocks.map((b) => _buildBlockCard(b)),
              ],
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addBlock,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add outage time'),
      ),
      bottomNavigationBar: const AppBottomNav(),
    );
  }

  Widget _buildIntro() {
    return const Text(
      "These are times YOU'VE told us your power usually goes out. "
      "We'll remind you before each one — add every block you know about.",
      style: TextStyle(fontSize: 13.5, color: AppColors.grey, height: 1.4),
    );
  }

  Widget _buildBlockCard(ScheduleBlock block) {
    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(
              color: AppColors.black,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.flash_off_rounded,
              color: AppColors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Power usually OFF',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.black,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  block.timeRangeLabel,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.delete_outline_rounded,
              color: AppColors.grey,
            ),
            onPressed: () => ScheduleStore.removeBlock(block.id),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.white,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.border, width: 1.5),
              ),
              child: const Icon(
                Icons.calendar_month_rounded,
                size: 34,
                color: AppColors.black,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'No saved outage times yet',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.black,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              "Add the times you know your power usually goes out, "
              "and we'll remind you before each one.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                color: AppColors.grey,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _addBlock,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add outage time'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Simple start/end time picker dialog. Returns a RangeValues in
/// "minutes since midnight" (0–1440) via two sequential time pickers —
/// keeps this file self-contained rather than pulling in a slider
/// dependency for something used this rarely.
class _AddBlockDialog extends StatefulWidget {
  const _AddBlockDialog();

  @override
  State<_AddBlockDialog> createState() => _AddBlockDialogState();
}

class _AddBlockDialogState extends State<_AddBlockDialog> {
  TimeOfDay? _start;
  TimeOfDay? _end;

  Future<void> _pickStart() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _start ?? const TimeOfDay(hour: 17, minute: 0),
    );
    if (picked != null) setState(() => _start = picked);
  }

  Future<void> _pickEnd() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _end ?? const TimeOfDay(hour: 19, minute: 0),
    );
    if (picked != null) setState(() => _end = picked);
  }

  void _submit() {
    if (_start == null || _end == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pick both a start and end time.')),
      );
      return;
    }
    final int startMin = _start!.hour * 60 + _start!.minute;
    int endMin = _end!.hour * 60 + _end!.minute;
    if (endMin <= startMin) endMin += 24 * 60; // crosses midnight

    Navigator.pop(context, RangeValues(startMin.toDouble(), endMin.toDouble()));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add outage time'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Starts at'),
            trailing: Text(
              _start == null ? 'Select' : _start!.format(context),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            onTap: _pickStart,
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Ends at'),
            trailing: Text(
              _end == null ? 'Select' : _end!.format(context),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            onTap: _pickEnd,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(onPressed: _submit, child: const Text('Add')),
      ],
    );
  }
}
