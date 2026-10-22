import 'package:flutter/foundation.dart';

import '../models/user_address.dart';
import '../services/address_api.dart';

enum AddressLoadState { idle, loading, loaded, error }

class AddressProvider with ChangeNotifier {
  AddressProvider({AddressApi? api}) : _api = api ?? AddressApi();

  final AddressApi _api;

  List<UserAddress> _addresses = const [];
  AddressLoadState _loadState = AddressLoadState.idle;
  String? _error;

  List<UserAddress> get addresses => List.unmodifiable(_addresses);
  AddressLoadState get loadState => _loadState;
  String? get error => _error;
  bool get isLoaded => _loadState == AddressLoadState.loaded;

  UserAddress? get defaultAddress {
    for (final a in _addresses) {
      if (a.isDefault) return a;
    }
    return _addresses.isEmpty ? null : _addresses.first;
  }

  Future<void> load(String token) async {
    if (_loadState == AddressLoadState.loading) return;
    _loadState = AddressLoadState.loading;
    _error = null;
    notifyListeners();
    try {
      _addresses = await _api.list(token);
      _loadState = AddressLoadState.loaded;
    } catch (_) {
      _loadState = AddressLoadState.error;
      _error = 'Не удалось загрузить адреса';
    }
    notifyListeners();
  }

  Future<UserAddress> add(String token, UserAddress addr) async {
    final created = await _api.create(token, addr);
    if (created.isDefault) {
      _addresses = [
        created,
        ..._addresses.map((a) => a.copyWith(isDefault: false)),
      ];
    } else {
      _addresses = [..._addresses, created];
    }
    notifyListeners();
    return created;
  }

  Future<UserAddress> update(String token, String id, UserAddress addr) async {
    final updated = await _api.update(token, id, addr);
    _addresses = _addresses.map((a) {
      if (a.id == id) return updated;
      if (updated.isDefault) return a.copyWith(isDefault: false);
      return a;
    }).toList();
    notifyListeners();
    return updated;
  }

  Future<void> delete(String token, String id) async {
    await _api.delete(token, id);
    final wasDefault = _addresses.any((a) => a.id == id && a.isDefault);
    _addresses = _addresses.where((a) => a.id != id).toList();
    if (wasDefault && _addresses.isNotEmpty) {
      _addresses = [
        _addresses.first.copyWith(isDefault: true),
        ..._addresses.skip(1),
      ];
    }
    notifyListeners();
  }

  Future<void> setDefault(String token, String id) async {
    await _api.setDefault(token, id);
    _addresses = _addresses.map((a) => a.copyWith(isDefault: a.id == id)).toList();
    notifyListeners();
  }

  void clear() {
    _addresses = const [];
    _loadState = AddressLoadState.idle;
    _error = null;
    notifyListeners();
  }
}
