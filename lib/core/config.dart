const apiBaseUrl = String.fromEnvironment('API_BASE_URL');

const apiHealthPath = String.fromEnvironment(
  'API_HEALTH_PATH',
  defaultValue: '/health',
);

enum DataBackend {
  api,
  persistent,
  memory;

  static DataBackend parse(String raw) => switch (raw.trim().toLowerCase()) {
    'persistent' || 'local' || 'prefs' => DataBackend.persistent,
    'memory' || 'mem' => DataBackend.memory,
    _ => DataBackend.api,
  };

  bool get isRemote => this == DataBackend.api;
}

const backendName = String.fromEnvironment('BACKEND', defaultValue: 'api');

class MissingApiUrlException implements Exception {
  const MissingApiUrlException();

  @override
  String toString() => 'Не задан адрес API (параметр сборки API_BASE_URL).';
}
