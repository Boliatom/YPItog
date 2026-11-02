class AuthConfig {
  const AuthConfig({
    this.inactivityTimeout = const Duration(seconds: _inactivitySeconds),
    this.warningLead = const Duration(seconds: _warningSeconds),
    this.maxSession = const Duration(seconds: _maxSessionSeconds),
  });

  final Duration inactivityTimeout;

  final Duration warningLead;

  final Duration maxSession;
}

const _inactivitySeconds = int.fromEnvironment(
  'INACTIVITY_SECONDS',
  defaultValue: 180,
);
const _warningSeconds = int.fromEnvironment(
  'WARNING_SECONDS',
  defaultValue: 30,
);
const _maxSessionSeconds = int.fromEnvironment(
  'MAX_SESSION_SECONDS',
  defaultValue: 8 * 3600,
);
