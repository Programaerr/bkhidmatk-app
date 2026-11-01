import 'package:jaik/data/models.dart';
import 'package:jaik/data/preview_repository.dart';

class FakeRepo extends PreviewRepository {
  FakeRepo({this.customer});

  final AppUser? customer;

  @override
  Future<AppUser?> findUserByPhone(String phone) async => customer;

  @override
  Future<AppUser?> userById(int id) async => customer;
}
