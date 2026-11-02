enum Role {
  client('client', 'клиент'),
  master('master', 'мастер'),
  admin('admin', 'администратор');

  const Role(this.apiName, this.label);

  final String apiName;
  final String label;

  static Role parse(Object? raw) => switch (raw) {
    'admin' => Role.admin,
    'master' => Role.master,
    _ => Role.client,
  };
}
