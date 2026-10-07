import 'package:uuid/uuid.dart';

const _uuid = Uuid();

final _uuidPattern = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');

bool isUuid(String? value) => value != null && _uuidPattern.hasMatch(value);

String newUuid() => _uuid.v4();
