import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// ----------------------
/// KYC SDK DATA MODELS
/// ----------------------

/// High level step in the simulated KYC flow.
enum KycStep {
  welcome,
  documentCapture,
  selfieCapture,
  locationCheck,
  review,
  completed,
}

/// Types of events the SDK will send back to the host app.
enum KycEventType {
  flowStarted,
  stepStarted,
  stepCompleted,
  flowCompleted,
  permissionRequired, // host should trigger camera / location permission.
  error,
}

/// Simple event object passed back to the host app.
class KycEvent {
  final KycEventType type;
  final KycStep? step;
  final String message;
  final DateTime timestamp;
  final Map<String, dynamic>? meta;

  KycEvent({
    required this.type,
    this.step,
    required this.message,
    DateTime? timestamp,
    this.meta,
  }) : timestamp = timestamp ?? DateTime.now();
}

/// ----------------------
/// PLATFORM CHANNEL
/// ----------------------

const _kKycEventChannelName = 'universal_experience_sdk/events';
const _kycEventChannel = MethodChannel(_kKycEventChannelName);

/// Forward events to native hosts (Android / iOS).
/// If no host listener exists, this will just log and ignore.
Future<void> sendKycEventToHost(KycEvent event) async {
  try {
    await _kycEventChannel.invokeMethod('onKycEvent', {
      'type': event.type.name,
      'step': event.step?.name,
      'message': event.message,
      'timestamp': event.timestamp.millisecondsSinceEpoch,
      'meta': event.meta,
    });
  } catch (e) {
    // In preview / non-host environments, this may be unimplemented. Just swallow.
    debugPrint('sendKycEventToHost error: $e');
  }
}

/// ----------------------
/// UNIVERSAL EXPERIENCE SCREEN
/// ----------------------
///
/// This is the main SDK screen that host apps will open.
/// It simulates a KYC flow and sends callbacks at each stage.
class UniversalExperienceScreen extends StatefulWidget {
  /// Existing param — kept for backward compatibility.
  final String hostAppName;

  /// Optional identifiers supplied by host app.
  final String? userId;
  final String? sessionId;
  final String? referenceId;

  /// Permissions are handled by the host app.
  /// SDK only *reads* these flags to decide what to show.
  final bool cameraPermissionGranted;
  final bool locationPermissionGranted;

  /// Callback for the host app to observe SDK events (Flutter host).
  final void Function(KycEvent event)? onEvent;

  const UniversalExperienceScreen({
    super.key,
    this.hostAppName = 'Unknown Host',
    this.userId,
    this.sessionId,
    this.referenceId,
    this.cameraPermissionGranted = true, // default true => no break for old flows
    this.locationPermissionGranted = true,
    this.onEvent,
  });

  @override
  State<UniversalExperienceScreen> createState() =>
      _UniversalExperienceScreenState();
}

class _UniversalExperienceScreenState extends State<UniversalExperienceScreen> {
  KycStep _currentStep = KycStep.welcome;
  bool _documentCaptured = false;
  bool _selfieCaptured = false;
  bool _locationVerified = false;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _emitEvent(
      KycEvent(
        type: KycEventType.flowStarted,
        step: _currentStep,
        message: 'KYC flow started from host: ${widget.hostAppName}',
        meta: {
          'userId': widget.userId,
          'sessionId': widget.sessionId,
          'referenceId': widget.referenceId,
        },
      ),
    );
    _emitStepStarted(_currentStep);
  }

  /// 🔑 Single place where we fan-out events:
  /// - to Flutter host via onEvent
  /// - to native host via MethodChannel
  void _emitEvent(KycEvent event) {
    // Flutter host listener (our Flutter host app logs panel)
    widget.onEvent?.call(event);

    // Native host listener (Android/iOS via platform channel)
    // Fire-and-forget; we don't await to avoid blocking UI.
    // ignore: discarded_futures
    sendKycEventToHost(event);
  }

  void _emitStepStarted(KycStep step) {
    _emitEvent(
      KycEvent(
        type: KycEventType.stepStarted,
        step: step,
        message: 'Step started: $step',
      ),
    );
  }

  void _emitStepCompleted(KycStep step) {
    _emitEvent(
      KycEvent(
        type: KycEventType.stepCompleted,
        step: step,
        message: 'Step completed: $step',
      ),
    );
  }

  void _emitPermissionRequired(String permissionType) {
    _emitEvent(
      KycEvent(
        type: KycEventType.permissionRequired,
        step: _currentStep,
        message: 'Permission required: $permissionType',
        meta: {'permission': permissionType},
      ),
    );
  }

  void _handleClosePressed() {
    final navigator = Navigator.of(context);

    // If this screen was pushed on a Flutter navigator (Flutter host app),
    // just pop that route.
    if (navigator.canPop()) {
      navigator.pop();
      return;
    }

    // If we're embedded in a native container (Android Activity / iOS VC)
    // and this is the root route, ask the system to close the Flutter view.
    SystemNavigator.pop();
  }


  Future<void> _goToNextStep() async {
    if (_currentStep == KycStep.welcome) {
      setState(() {
        _currentStep = KycStep.documentCapture;
      });
      _emitStepStarted(_currentStep);
      return;
    }

    if (_currentStep == KycStep.documentCapture) {
      // Check camera permission
      if (!widget.cameraPermissionGranted) {
        _emitPermissionRequired('camera');
        _showSnack(
          'Camera permission required. Please grant it in the host app.',
        );
        return;
      }
      setState(() {
        _documentCaptured = true;
        _emitStepCompleted(KycStep.documentCapture);
        _currentStep = KycStep.selfieCapture;
      });
      _emitStepStarted(_currentStep);
      return;
    }

    if (_currentStep == KycStep.selfieCapture) {
      if (!widget.cameraPermissionGranted) {
        _emitPermissionRequired('camera');
        _showSnack(
          'Camera permission required. Please grant it in the host app.',
        );
        return;
      }
      setState(() {
        _selfieCaptured = true;
        _emitStepCompleted(KycStep.selfieCapture);
        _currentStep = KycStep.locationCheck;
      });
      _emitStepStarted(_currentStep);
      return;
    }

    if (_currentStep == KycStep.locationCheck) {
      if (!widget.locationPermissionGranted) {
        _emitPermissionRequired('location');
        _showSnack(
          'Location permission required. Please grant it in the host app.',
        );
        return;
      }
      setState(() {
        _locationVerified = true;
        _emitStepCompleted(KycStep.locationCheck);
        _currentStep = KycStep.review;
      });
      _emitStepStarted(_currentStep);
      return;
    }

    if (_currentStep == KycStep.review) {
      // Simulate final submission
      setState(() {
        _submitting = true;
      });

      await Future<void>.delayed(const Duration(seconds: 1));

      setState(() {
        _submitting = false;
        _emitStepCompleted(KycStep.review);
        _currentStep = KycStep.completed;
      });

      _emitEvent(
        KycEvent(
          type: KycEventType.flowCompleted,
          step: KycStep.completed,
          message: 'KYC flow completed successfully.',
          meta: {
            'userId': widget.userId,
            'sessionId': widget.sessionId,
            'referenceId': widget.referenceId,
            'documentCaptured': _documentCaptured,
            'selfieCaptured': _selfieCaptured,
            'locationVerified': _locationVerified,
          },
        ),
      );
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final steps = KycStep.values.where((s) => s != KycStep.completed).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Universal KYC Experience'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              _buildHeaderCard(theme),
              const SizedBox(height: 24),
              _buildStepper(steps, theme),
              const SizedBox(height: 16),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: _buildStepContent(_currentStep, theme),
                ),
              ),
              const SizedBox(height: 16),
              _buildBottomButton(theme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderCard(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: theme.colorScheme.primary,
            child: const Icon(Icons.verified_user, color: Colors.white),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'KYC Verification',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Host app: ${widget.hostAppName}',
                  style: theme.textTheme.bodySmall,
                ),
                if (widget.userId != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    'User: ${widget.userId}',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
                if (widget.sessionId != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Session: ${widget.sessionId}',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepper(List<KycStep> steps, ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: steps.map((step) {
        final index = steps.indexOf(step) + 1;
        final isActive = step == _currentStep;
        final isCompleted = _isStepCompleted(step);

        Color bg;
        Color fg;
        if (isCompleted) {
          bg = theme.colorScheme.primary;
          fg = Colors.white;
        } else if (isActive) {
          bg = theme.colorScheme.primaryContainer;
          fg = theme.colorScheme.primary;
        } else {
          bg = theme.colorScheme.surfaceVariant;
          fg = theme.colorScheme.onSurfaceVariant;
        }

        return Expanded(
          child: Column(
            children: [
              Container(
                padding:
                const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Center(
                  child: Text(
                    '$index',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: fg,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _stepLabel(step),
                textAlign: TextAlign.center,
                style: theme.textTheme.labelSmall,
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  bool _isStepCompleted(KycStep step) {
    switch (step) {
      case KycStep.welcome:
        return _currentStep.index > KycStep.welcome.index;
      case KycStep.documentCapture:
        return _documentCaptured;
      case KycStep.selfieCapture:
        return _selfieCaptured;
      case KycStep.locationCheck:
        return _locationVerified;
      case KycStep.review:
        return _currentStep == KycStep.completed;
      case KycStep.completed:
        return false;
    }
  }

  String _stepLabel(KycStep step) {
    switch (step) {
      case KycStep.welcome:
        return 'Welcome';
      case KycStep.documentCapture:
        return 'Document';
      case KycStep.selfieCapture:
        return 'Selfie';
      case KycStep.locationCheck:
        return 'Location';
      case KycStep.review:
        return 'Review';
      case KycStep.completed:
        return 'Done';
    }
  }

  Widget _buildStepContent(KycStep step, ThemeData theme) {
    switch (step) {
      case KycStep.welcome:
        return _buildWelcomeStep(theme);
      case KycStep.documentCapture:
        return _buildDocumentStep(theme);
      case KycStep.selfieCapture:
        return _buildSelfieStep(theme);
      case KycStep.locationCheck:
        return _buildLocationStep(theme);
      case KycStep.review:
        return _buildReviewStep(theme);
      case KycStep.completed:
        return _buildCompletedStep(theme);
    }
  }

  Widget _buildWelcomeStep(ThemeData theme) {
    return Column(
      key: const ValueKey('welcome'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Hello from Universal KYC SDK 👋',
          style: theme.textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text(
          'We will now simulate a full KYC verification journey. '
              'Use this screen to test how callbacks, states and permissions work end-to-end.',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        _buildInfoTile(
          theme,
          icon: Icons.info_outline,
          title: 'What happens here?',
          subtitle:
          'We walk through document capture, selfie capture and location verification, then send a final KYC result back to your app.',
        ),
      ],
    );
  }

  Widget _buildDocumentStep(ThemeData theme) {
    final hasCamera = widget.cameraPermissionGranted;
    return Column(
      key: const ValueKey('document'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Step 1 · Document capture',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Simulate scanning a government-issued ID. We do not store any real data; '
              'this is only for UI and callback testing.',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        Expanded(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.badge_outlined,
                  size: 64,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 12),
                Text(
                  hasCamera
                      ? 'Camera permission is available.\nTap Next to simulate ID capture.'
                      : 'Camera permission is missing.\nAsk the host app to grant it.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSelfieStep(ThemeData theme) {
    final hasCamera = widget.cameraPermissionGranted;
    return Column(
      key: const ValueKey('selfie'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Step 2 · Selfie verification',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'We simulate a selfie capture to match the user with the ID document.',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        Expanded(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.face_retouching_natural_outlined,
                  size: 64,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 12),
                Text(
                  hasCamera
                      ? 'Camera permission is available.\nTap Next to simulate selfie capture.'
                      : 'Camera permission is missing.\nAsk the host app to grant it.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLocationStep(ThemeData theme) {
    final hasLocation = widget.locationPermissionGranted;
    return Column(
      key: const ValueKey('location'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Step 3 · Location check',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'We simulate verifying your current location for regulatory or risk checks.',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        _buildInfoTile(
          theme,
          icon: Icons.lock_person_outlined,
          title: 'Privacy first',
          subtitle:
          'In a real SDK, location would be used only for compliance and not stored unnecessarily.',
        ),
        const SizedBox(height: 16),
        Expanded(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.location_on_outlined,
                  size: 64,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 12),
                Text(
                  hasLocation
                      ? 'Location permission is available.\nTap Next to simulate location verification.'
                      : 'Location permission is missing.\nAsk the host app to grant it.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReviewStep(ThemeData theme) {
    return Column(
      key: const ValueKey('review'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Review & submit',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Here is the summary of this simulated KYC session.',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        _buildSummaryChip(
          theme,
          icon: Icons.badge_outlined,
          label: 'Document captured',
          value: _documentCaptured ? 'Yes' : 'Pending',
        ),
        const SizedBox(height: 8),
        _buildSummaryChip(
          theme,
          icon: Icons.face_retouching_natural_outlined,
          label: 'Selfie captured',
          value: _selfieCaptured ? 'Yes' : 'Pending',
        ),
        const SizedBox(height: 8),
        _buildSummaryChip(
          theme,
          icon: Icons.location_on_outlined,
          label: 'Location verified',
          value: _locationVerified ? 'Yes' : 'Pending',
        ),
        const SizedBox(height: 16),
        _buildSummaryChip(
          theme,
          icon: Icons.fingerprint_outlined,
          label: 'User ID',
          value: widget.userId ?? 'Not provided',
        ),
        const SizedBox(height: 8),
        _buildSummaryChip(
          theme,
          icon: Icons.link_outlined,
          label: 'Reference ID',
          value: widget.referenceId ?? 'Not provided',
        ),
        const Spacer(),
        if (_submitting)
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 8),
                Text(
                  'Submitting KYC result...',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildCompletedStep(ThemeData theme) {
    return Column(
      key: const ValueKey('completed'),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.verified_outlined,
          size: 72,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(height: 12),
        Text(
          'KYC simulated successfully!',
          style: theme.textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'We have sent a completion event back to the host app.\n'
              'You can now close this screen from the host side.',
          style: theme.textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildBottomButton(ThemeData theme) {
    final isLast = _currentStep == KycStep.completed;
    final label = () {
      switch (_currentStep) {
        case KycStep.welcome:
          return 'Start KYC';
        case KycStep.documentCapture:
        case KycStep.selfieCapture:
        case KycStep.locationCheck:
          return 'Next';
        case KycStep.review:
          return 'Submit KYC';
        case KycStep.completed:
          return 'Close';
      }
    }();

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _submitting
            ? null
            : () {
          if (isLast) {
            _handleClosePressed();
          } else {
            _goToNextStep();
          }
        },
        child: Text(label),
      ),
    );
  }

  Widget _buildInfoTile(
      ThemeData theme, {
        required IconData icon,
        required String title,
        required String subtitle,
      }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.6),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryChip(
      ThemeData theme, {
        required IconData icon,
        required String label,
        required String value,
      }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.7),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium,
            ),
          ),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
