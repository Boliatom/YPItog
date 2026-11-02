import 'permission.dart';

const guestPaths = {'/login', '/register'};

const _catalogSections = {'services', 'categories', 'masters', 'reviews'};

Permission? requiredPermission(Uri uri) {
  final s = uri.pathSegments;
  if (s.isEmpty) return null;
  switch (s.first) {
    case 'book':
      return Permission.bookOnline;
    case 'my-appointments':
      return Permission.viewOwnAppointments;
    case 'my-schedule':
      return Permission.viewOwnSchedule;
    case 'admin':
      return s.length > 1 && s[1] == 'stats'
          ? Permission.viewStats
          : Permission.manageUsers;
    case 'appointments':
      return _entityPermission(s, Permission.viewAllAppointments);
    case 'clients':
      return _entityPermission(s, Permission.viewClients);
    case 'cards':
    case 'schedules':
      return Permission.editData;
  }
  if (_catalogSections.contains(s.first)) {
    return _entityPermission(s, Permission.viewCatalog);
  }
  return null;
}

Permission _entityPermission(List<String> s, Permission view) {
  if (s.length >= 2 && s[1] == 'new') return Permission.editData;
  if (s.length >= 3 && s[2] == 'edit') return Permission.editData;
  return view;
}

String? safeReturnPath(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  if (!raw.startsWith('/') || raw.startsWith('//')) return null;
  if (raw.contains('\\') || raw.contains(RegExp(r'[\x00-\x1f]'))) return null;
  final uri = Uri.tryParse(raw);
  if (uri == null || uri.hasScheme || uri.hasAuthority) return null;
  if (guestPaths.contains(uri.path) || uri.path == '/forbidden') return null;
  return raw;
}

String loginLocation({String? returnTo}) {
  final target = safeReturnPath(returnTo);
  if (target == null || target == '/') return '/login';
  return Uri(path: '/login', queryParameters: {'from': target}).toString();
}

String forbiddenLocation(Uri denied) =>
    Uri(path: '/forbidden', queryParameters: {'path': denied.path}).toString();
