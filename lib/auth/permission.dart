import 'role.dart';

enum Permission {
  viewCatalog('Просмотр услуг, мастеров, категорий и отзывов'),
  bookOnline('Онлайн-запись на услуги'),
  viewOwnAppointments('Свои записи и отмена записи'),
  writeReview('Отзыв о выполненной записи'),
  viewOwnSchedule('Свой график и записи к мастеру'),
  serveClients('Смена статуса записей мастера'),
  viewClients('Список клиентов и их карты'),
  viewAllAppointments('Все записи салона'),
  editData('Создание и изменение данных'),
  purgeData('Физическое удаление и восстановление записей'),
  manageUsers('Управление пользователями и ролями'),
  viewStats('Отчёт по выручке и загрузке мастеров');

  const Permission(this.label);

  final String label;
}

const rolePermissions = <Role, Set<Permission>>{
  Role.client: {
    Permission.viewCatalog,
    Permission.bookOnline,
    Permission.viewOwnAppointments,
    Permission.writeReview,
  },
  Role.master: {
    Permission.viewCatalog,
    Permission.viewOwnSchedule,
    Permission.serveClients,
    Permission.viewClients,
  },
  Role.admin: {
    Permission.viewCatalog,
    Permission.viewClients,
    Permission.viewAllAppointments,
    Permission.editData,
    Permission.purgeData,
    Permission.manageUsers,
    Permission.viewStats,
  },
};

bool roleHas(Role role, Permission permission) =>
    rolePermissions[role]!.contains(permission);
