import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:universal_experience_module/universal_experience_sdk.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const HostApp());
}

class HostApp extends StatelessWidget {
  const HostApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Universal Host Flutter App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4F46E5)),
        useMaterial3: true,
      ),
      home: const HostHomeScreen(),
    );
  }
}

class HostHomeScreen extends StatefulWidget {
  const HostHomeScreen({super.key});

  @override
  State<HostHomeScreen> createState() => _HostHomeScreenState();
}

class _HostHomeScreenState extends State<HostHomeScreen> {
  bool _cameraGranted = false;
  bool _locationGranted = false;
  bool _opening = false;

  /// Simple in-memory event log
  final List<KycEvent> _events = [];

  /// Safely enqueue events so we don't call setState during another widget's build.
  void _enqueueEvent(KycEvent event) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _events.insert(0, event); // latest first
      });
    });
  }

  Future<PermissionStatus> _safeRequest(Permission permission) async {
    try {
      debugPrint('Host: requesting $permission');
      final status = await permission.request();
      debugPrint('Host: status for $permission -> $status');
      return status;
    } catch (e, s) {
      debugPrint('Host: ERROR requesting $permission: $e\n$s');
      return PermissionStatus.denied;
    }
  }

  Future<void> _openKycSdk(BuildContext context) async {
    if (_opening) return;
    setState(() => _opening = true);

    // 1) Ask for permissions (host app is responsible)
    final camStatus = await _safeRequest(Permission.camera);
    final locStatus = await _safeRequest(Permission.locationWhenInUse);

    if (!mounted) return;

    setState(() {
      _cameraGranted = camStatus.isGranted;
      _locationGranted = locStatus.isGranted;
      _opening = false;
    });

    // 2) Optional info
    if (!_cameraGranted || !_locationGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Some permissions were not granted. '
            'SDK will show how it behaves without them.',
          ),
        ),
      );
    }

    // 3) Open the SDK and pass flags + identifiers
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => UniversalExperienceScreen(
          hostAppName: 'Flutter Host App',
          userId: 'host_user_001',
          sessionId: 'sess_flutter_001',
          referenceId: 'kyc-ref-001',
          cameraPermissionGranted: _cameraGranted,
          locationPermissionGranted: _locationGranted,
          onEvent: (event) {
            debugPrint(
              '[HOST] KYC EVENT: type=${event.type}, step=${event.step}, '
              'msg=${event.message}, meta=${event.meta}',
            );

            // 🔑 This is now deferred safely
            _enqueueEvent(event);

            if (event.type == KycEventType.permissionRequired) {
              final perm = event.meta?['permission'];
              if (perm != null && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'SDK requested $perm permission. '
                      'Handled by host app.',
                    ),
                  ),
                );
              }
            }

            if (event.type == KycEventType.flowCompleted && context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'KYC simulated successfully (host app got callback).',
                  ),
                ),
              );
            }
          },
        ),
      ),
    );
  }

  String _formatEventType(KycEventType type) {
    switch (type) {
      case KycEventType.flowStarted:
        return 'Flow Started';
      case KycEventType.stepStarted:
        return 'Step Started';
      case KycEventType.stepCompleted:
        return 'Step Completed';
      case KycEventType.flowCompleted:
        return 'Flow Completed';
      case KycEventType.permissionRequired:
        return 'Permission Required';
      case KycEventType.error:
        return 'Error';
    }
  }

  String _formatStep(KycStep? step) {
    if (step == null) return '-';
    switch (step) {
      case KycStep.welcome:
        return 'Welcome';
      case KycStep.documentCapture:
        return 'Document Capture';
      case KycStep.selfieCapture:
        return 'Selfie Capture';
      case KycStep.locationCheck:
        return 'Location Check';
      case KycStep.review:
        return 'Review';
      case KycStep.completed:
        return 'Completed';
    }
  }

  IconData _eventIcon(KycEventType type) {
    switch (type) {
      case KycEventType.flowStarted:
        return Icons.play_circle_outline;
      case KycEventType.stepStarted:
        return Icons.arrow_forward;
      case KycEventType.stepCompleted:
        return Icons.check_circle_outline;
      case KycEventType.flowCompleted:
        return Icons.verified;
      case KycEventType.permissionRequired:
        return Icons.lock_open;
      case KycEventType.error:
        return Icons.error_outline;
    }
  }

  Color _eventColor(ThemeData theme, KycEventType type) {
    switch (type) {
      case KycEventType.flowCompleted:
        return theme.colorScheme.primary;
      case KycEventType.error:
        return theme.colorScheme.error;
      case KycEventType.permissionRequired:
        return theme.colorScheme.tertiary;
      default:
        return theme.colorScheme.secondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Flutter Host App')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Header card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withOpacity(0.18),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: theme.colorScheme.primary,
                    child: const Icon(Icons.hub, color: Colors.white),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Universal KYC SDK · Host',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'This app invokes the SDK and shows all callbacks here.',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Permission status row
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _PermissionStatusChip(label: 'Camera', granted: _cameraGranted),
                const SizedBox(width: 8),
                _PermissionStatusChip(
                  label: 'Location',
                  granted: _locationGranted,
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Open SDK button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _opening ? null : () => _openKycSdk(context),
                icon: _opening
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.open_in_new),
                label: Text(
                  _opening
                      ? 'Requesting permissions...'
                      : 'Open Universal KYC SDK',
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Logs header
            Row(
              children: [
                Text(
                  'SDK Events',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                if (_events.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${_events.length}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                const Spacer(),
                if (_events.isNotEmpty)
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _events.clear();
                      });
                    },
                    icon: const Icon(Icons.clear_all, size: 18),
                    label: const Text('Clear'),
                  ),
              ],
            ),

            const SizedBox(height: 8),

            // Logs panel
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: _events.isEmpty
                    ? Center(
                        child: Text(
                          'No events yet.\nTap "Open Universal KYC SDK" to start.',
                          style: theme.textTheme.bodyMedium,
                          textAlign: TextAlign.center,
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: _events.length,
                        itemBuilder: (context, index) {
                          final event = _events[index];
                          final typeLabel = _formatEventType(event.type);
                          final stepLabel = _formatStep(event.step);
                          final color = _eventColor(theme, event.type);

                          return Card(
                            margin: const EdgeInsets.symmetric(
                              vertical: 4,
                              horizontal: 2,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(10),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    _eventIcon(event.type),
                                    color: color,
                                    size: 24,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              typeLabel,
                                              style: theme.textTheme.labelLarge
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                            ),
                                            const Spacer(),
                                            Text(
                                              TimeOfDay.fromDateTime(
                                                event.timestamp,
                                              ).format(context),
                                              style: theme.textTheme.labelSmall,
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Step: $stepLabel',
                                          style: theme.textTheme.labelSmall,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          event.message,
                                          style: theme.textTheme.bodySmall,
                                        ),
                                        if (event.meta != null &&
                                            event.meta!.isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            'Meta: ${event.meta}',
                                            style: theme.textTheme.bodySmall
                                                ?.copyWith(
                                                  color: theme
                                                      .colorScheme
                                                      .onSurfaceVariant,
                                                  fontSize: 11,
                                                ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PermissionStatusChip extends StatelessWidget {
  final String label;
  final bool granted;

  const _PermissionStatusChip({required this.label, required this.granted});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = granted
        ? theme.colorScheme.primary
        : theme.colorScheme.error.withOpacity(0.9);

    return Chip(
      avatar: Icon(
        granted ? Icons.check_circle : Icons.cancel,
        size: 18,
        color: Colors.white,
      ),
      label: Text(
        '$label: ${granted ? "Granted" : "Denied"}',
        style: theme.textTheme.labelMedium?.copyWith(color: Colors.white),
      ),
      backgroundColor: color,
    );
  }
}
