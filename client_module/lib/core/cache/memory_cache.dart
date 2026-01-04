class CacheEntry<T> {
  final T value;
  final DateTime expiresAt;
  CacheEntry(this.value, this.expiresAt);

  bool get isValid => DateTime.now().isBefore(expiresAt);
}

class MemoryCache {
  final _map = <String, CacheEntry<dynamic>>{};

  T? get<T>(String key) {
    final e = _map[key];
    if (e == null) return null;
    if (!e.isValid) {
      _map.remove(key);
      return null;
    }
    return e.value as T;
  }

  void set<T>(
    String key,
    T value, {
    Duration ttl = const Duration(seconds: 30),
  }) {
    _map[key] = CacheEntry<T>(value, DateTime.now().add(ttl));
  }

  void invalidate(String key) => _map.remove(key);

  void invalidateMany(Iterable<String> keys) {
    for (final k in keys) {
      _map.remove(k);
    }
  }

  void clear() => _map.clear();
}
