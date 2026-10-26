import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/utils.dart';
import 'models.dart';
import 'repository.dart';

/// تنفيذ قاعدة البيانات المشتركة عبر Supabase.
///
/// كل المستخدمين يقرؤون ويكتبون في نفس قاعدة البيانات، لذلك المنشورات
/// والحجوزات والرسائل تظهر عند الجميع مباشرة (Realtime).
class CloudRepository implements Repository {
  CloudRepository() {
    _listen();
  }

  final StreamController<void> _changes = StreamController<void>.broadcast();
  RealtimeChannel? _channel;
  Timer? _debounce;

  /// الجداول التي نراقبها لإعادة تحميل الشاشات تلقائياً.
  static const _watchedTables = [
    'posts',
    'comments',
    'bookings',
    'messages',
    'receipts',
    'services',
    'workers',
    'categories',
    'settings',
    'cards',
    'profiles',
  ];

  SupabaseClient get _client => Supabase.instance.client;

  String? get _authId => _client.auth.currentUser?.id;

  int? _cachedProfileId;
  String? _cachedAuthId;

  @override
  Stream<void> get changes => _changes.stream;

  // ------------------------------------------------------------- realtime
  void _listen() {
    final channel = _client.channel('bkhidmatk:public-changes');
    for (final table in _watchedTables) {
      channel.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: table,
        callback: (_) => _emitChange(),
      );
    }
    _channel = channel..subscribe();
  }

  void _emitChange() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (!_changes.isClosed) _changes.add(null);
    });
  }

  // -------------------------------------------------------------- helpers
  static List<Map<String, Object?>> _maps(Object? data) {
    if (data is! List) return const [];
    return [
      for (final row in data)
        if (row is Map) Map<String, Object?>.from(row),
    ];
  }

  static Map<String, Object?>? _map(Object? data) =>
      data is Map ? Map<String, Object?>.from(data) : null;

  /// يحوّل القيم إلى صيغة يفهمها Postgres: تواريخ UTC وبدون معرّف/كلمة مرور.
  static Map<String, Object?> _prepared(Map<String, Object?> raw) {
    final out = <String, Object?>{};
    raw.forEach((key, value) {
      if (key == 'id' || key == 'password') return;
      if (value is DateTime) {
        out[key] = value.toUtc().toIso8601String();
        return;
      }
      if (key.endsWith('_at') && value is String) {
        final parsed = DateTime.tryParse(value);
        out[key] = parsed == null ? value : parsed.toUtc().toIso8601String();
        return;
      }
      out[key] = value;
    });
    return out;
  }

  Future<int> _insert(String table, Map<String, Object?> values) async {
    final row = await _client
        .from(table)
        .insert(_prepared(values))
        .select('id')
        .single();
    return (row['id'] as num).toInt();
  }

  Future<void> _update(String table, int id, Map<String, Object?> values) async {
    await _client.from(table).update(_prepared(values)).eq('id', id);
  }

  /// بحث آمن لـ PostgREST (نزيل الفواصل والأقواس التي تُفسَّر كصيغة).
  static String _term(String query) =>
      query.trim().replaceAll(RegExp(r'[,%()]'), ' ').trim();

  Future<int?> _profileId() async {
    final authId = _authId;
    if (authId == null) return null;
    if (_cachedProfileId != null && _cachedAuthId == authId) {
      return _cachedProfileId;
    }
    final row = await _client
        .from('profiles_view')
        .select('id')
        .eq('auth_id', authId)
        .maybeSingle();
    _cachedProfileId = (row?['id'] as num?)?.toInt();
    _cachedAuthId = authId;
    return _cachedProfileId;
  }

  String? _contentType(String ext) => switch (ext.toLowerCase()) {
        'jpg' || 'jpeg' => 'image/jpeg',
        'png' => 'image/png',
        'webp' => 'image/webp',
        'gif' => 'image/gif',
        'mp4' => 'video/mp4',
        'mov' => 'video/quicktime',
        '3gp' => 'video/3gpp',
        _ => null,
      };

  /// يرفع ملفاً محلياً إلى مخزن Supabase ويعيد رابطه العام.
  Future<String?> _uploadMedia(String? path, String mediaType) async {
    if (path == null || path.isEmpty) return null;
    if (path.startsWith('asset:') || path.startsWith('http')) return path;
    final file = File(path);
    if (!await file.exists()) return null;
    var ext = p.extension(path).replaceFirst('.', '').toLowerCase();
    if (ext.isEmpty) ext = mediaType == 'video' ? 'mp4' : 'jpg';
    final owner = await _profileId() ?? 'guest';
    final objectPath = 'posts/$owner/${DateTime.now().millisecondsSinceEpoch}.$ext';
    await _client.storage.from('media').upload(
          objectPath,
          file,
          fileOptions: FileOptions(contentType: _contentType(ext), upsert: true),
        );
    return _client.storage.from('media').getPublicUrl(objectPath);
  }

  Future<void> _deleteMedia(String? url) async {
    if (url == null || !url.startsWith('http')) return;
    const marker = '/object/public/media/';
    final index = url.indexOf(marker);
    if (index < 0) return;
    final objectPath = url.substring(index + marker.length).split('?').first;
    try {
      await _client.storage.from('media').remove([objectPath]);
    } catch (_) {}
  }

  // ---------------------------------------------------------------- users
  @override
  Future<AppUser?> findUserByPhone(String phone) async {
    final row = await _client
        .from('profiles_view')
        .select()
        .eq('phone', normalizePhone(phone))
        .maybeSingle();
    return row == null ? null : AppUser.fromMap(_map(row)!);
  }

  @override
  Future<AppUser?> userById(int id) async {
    final row =
        await _client.from('profiles_view').select().eq('id', id).maybeSingle();
    return row == null ? null : AppUser.fromMap(_map(row)!);
  }

  @override
  Future<AppUser?> userByAuthId(String authId) async {
    final row = await _client
        .from('profiles_view')
        .select()
        .eq('auth_id', authId)
        .maybeSingle();
    return row == null ? null : AppUser.fromMap(_map(row)!);
  }

  @override
  Future<int> createUser(AppUser user) async {
    final authId = _authId;
    if (authId == null) {
      throw const AuthException('انتهت جلسة التسجيل، أعد المحاولة');
    }
    final id = await _insert('profiles', {
      'auth_id': authId,
      'name': user.name,
      'phone': normalizePhone(user.phone),
      'role': user.role,
      'email': user.email,
      'city': user.city,
      'address': user.address,
      'avatar': user.avatarPath,
      'created_at': user.createdAt,
    });
    _cachedProfileId = id;
    return id;
  }

  @override
  Future<void> updateUser(AppUser user) async {
    if (user.id == null) return;
    await _update('profiles', user.id!, {
      'name': user.name,
      'phone': normalizePhone(user.phone),
      'email': user.email,
      'city': user.city,
      'address': user.address,
      'avatar': user.avatarPath,
    });
  }

  @override
  Future<bool> phoneExists(String phone) async {
    final result = await _client.rpc(
      'phone_exists',
      params: {'p_phone': normalizePhone(phone)},
    );
    return result == true;
  }

  @override
  Future<List<AppUser>> listCustomers({String query = ''}) async {
    var q = _client.from('profiles_view').select().eq('role', 'customer');
    final term = _term(query);
    if (term.isNotEmpty) q = q.or('name.ilike.%$term%,phone.ilike.%$term%');
    final rows = await q.order('created_at', ascending: false);
    return _maps(rows).map(AppUser.fromMap).toList();
  }

  @override
  Future<int> customerCount() async =>
      await _client.from('profiles').count().eq('role', 'customer');

  // ----------------------------------------------------------- categories
  @override
  Future<List<Category>> listCategories() async {
    final rows = await _client
        .from('categories')
        .select()
        .order('sort_order', ascending: true)
        .order('id', ascending: true);
    return _maps(rows).map(Category.fromMap).toList();
  }

  @override
  Future<Category?> categoryById(int id) async {
    final row =
        await _client.from('categories').select().eq('id', id).maybeSingle();
    return row == null ? null : Category.fromMap(_map(row)!);
  }

  @override
  Future<int> saveCategory(Category category) async {
    if (category.id == null) return _insert('categories', category.toMap());
    await _update('categories', category.id!, category.toMap());
    return category.id!;
  }

  @override
  Future<int> serviceCountForCategory(int id) async =>
      await _client.from('services').count().eq('category_id', id);

  @override
  Future<void> deleteCategory(int id) async {
    await _client.from('categories').delete().eq('id', id);
  }

  // -------------------------------------------------------------- workers
  @override
  Future<List<Worker>> listWorkers({
    int? categoryId,
    bool onlyAvailable = false,
  }) async {
    var q = _client.from('workers').select();
    if (categoryId != null) q = q.eq('category_id', categoryId);
    if (onlyAvailable) q = q.eq('available', 1);
    final rows = await q.order('rating', ascending: false);
    return _maps(rows).map(Worker.fromMap).toList();
  }

  @override
  Future<Worker?> workerById(int id) async {
    final row = await _client.from('workers').select().eq('id', id).maybeSingle();
    return row == null ? null : Worker.fromMap(_map(row)!);
  }

  @override
  Future<int> saveWorker(Worker worker) async {
    if (worker.id == null) return _insert('workers', worker.toMap());
    await _update('workers', worker.id!, worker.toMap());
    return worker.id!;
  }

  @override
  Future<void> deleteWorker(int id) async {
    await _client.from('services').update({'worker_id': null}).eq('worker_id', id);
    await _client.from('workers').delete().eq('id', id);
  }

  @override
  Future<void> incrementWorkerJobs(int? workerId) async {
    if (workerId == null) return;
    await _client.rpc('increment_worker_jobs', params: {'p_worker_id': workerId});
  }

  // ------------------------------------------------------------- services
  @override
  Future<List<Service>> listServices({
    int? categoryId,
    String query = '',
    bool onlyActive = true,
    int? limit,
  }) async {
    var q = _client.from('services_view').select();
    if (onlyActive) q = q.eq('active', 1);
    if (categoryId != null) q = q.eq('category_id', categoryId);
    final term = _term(query);
    if (term.isNotEmpty) {
      q = q.or('title.ilike.%$term%,description.ilike.%$term%,'
          'worker_name.ilike.%$term%,category_name.ilike.%$term%');
    }
    final rows = await q
        .order('created_at', ascending: false)
        .limit(limit ?? 500);
    return _maps(rows).map(Service.fromMap).toList();
  }

  @override
  Future<Service?> serviceById(int id) async {
    final row =
        await _client.from('services_view').select().eq('id', id).maybeSingle();
    return row == null ? null : Service.fromMap(_map(row)!);
  }

  @override
  Future<int> saveService(Service service) async {
    if (service.id == null) return _insert('services', service.toMap());
    await _update('services', service.id!, service.toMap());
    return service.id!;
  }

  @override
  Future<void> deleteService(int id) async {
    await _client.from('services').delete().eq('id', id);
  }

  @override
  Future<int> serviceCount() async =>
      await _client.from('services').count().eq('active', 1);

  // ------------------------------------------------------------- bookings
  @override
  Future<List<Booking>> bookingsForCustomer(int customerId,
      {String? status}) async {
    var q = _client.from('bookings_view').select().eq('customer_id', customerId);
    if (status != null) q = q.eq('status', status);
    final rows = await q.order('scheduled_at', ascending: false);
    return _maps(rows).map(Booking.fromMap).toList();
  }

  @override
  Future<List<Booking>> allBookings({String? status, String query = ''}) async {
    var q = _client.from('bookings_view').select();
    if (status != null) q = q.eq('status', status);
    final term = _term(query);
    if (term.isNotEmpty) {
      q = q.or('customer_name.ilike.%$term%,customer_phone.ilike.%$term%,'
          'service_title.ilike.%$term%');
    }
    final rows = await q.order('scheduled_at', ascending: false);
    return _maps(rows).map(Booking.fromMap).toList();
  }

  @override
  Future<Booking?> bookingById(int id) async {
    final row =
        await _client.from('bookings_view').select().eq('id', id).maybeSingle();
    return row == null ? null : Booking.fromMap(_map(row)!);
  }

  @override
  Future<int> createBooking(Booking booking) async =>
      _insert('bookings', booking.toMap());

  @override
  Future<void> updateBookingStatus(int id, String status) async {
    // إلغاء الحجز من الزبون يمرّ عبر دالة آمنة (RLS تمنع التحديث المباشر).
    if (status == BookingStatus.cancelled) {
      final me = await _client
          .from('profiles_view')
          .select('role')
          .eq('auth_id', _authId ?? '')
          .maybeSingle();
      final isAdmin = (me?['role'] as String?) == 'admin';
      if (!isAdmin) {
        await _client.rpc('cancel_booking', params: {'p_id': id});
        return;
      }
    }
    await _client.from('bookings').update({'status': status}).eq('id', id);
  }

  @override
  Future<void> assignWorker(int bookingId, int? workerId) async {
    await _client
        .from('bookings')
        .update({'worker_id': workerId}).eq('id', bookingId);
  }

  @override
  Future<int> bookingsTodayCount() async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    return await _client
        .from('bookings')
        .count()
        .gte('scheduled_at', start.toUtc().toIso8601String())
        .lt('scheduled_at', start.add(const Duration(days: 1)).toUtc().toIso8601String());
  }

  @override
  Future<int> pendingBookingsCount() async =>
      await _client.from('bookings').count().eq('status', BookingStatus.pending);

  // ---------------------------------------------------------------- posts
  @override
  Future<List<Post>> listPosts({
    bool onlyApproved = true,
    int? categoryId,
    int? customerId,
    String query = '',
    int? limit,
  }) async {
    var q = _client.from('posts_view').select();
    if (onlyApproved) q = q.eq('approved', 1);
    if (categoryId != null) q = q.eq('category_id', categoryId);
    if (customerId != null) q = q.eq('customer_id', customerId);
    final term = _term(query);
    if (term.isNotEmpty) {
      q = q.or('title.ilike.%$term%,description.ilike.%$term%');
    }
    final rows =
        await q.order('created_at', ascending: false).limit(limit ?? 200);
    return _maps(rows).map(Post.fromMap).toList();
  }

  @override
  Future<Post?> postById(int id) async {
    final row =
        await _client.from('posts_view').select().eq('id', id).maybeSingle();
    return row == null ? null : Post.fromMap(_map(row)!);
  }

  @override
  Future<int> createPost(Post post) async {
    final media = await _uploadMedia(post.mediaPath, post.mediaType);
    return _insert('posts', {
      'customer_id': post.customerId,
      'category_id': post.categoryId,
      'title': post.title,
      'description': post.description,
      'price': post.price,
      'media': media,
      'media_type': post.mediaType,
      'location': post.location,
      'approved': post.approved ? 1 : 0,
      'likes': post.likes,
      'created_at': post.createdAt,
    });
  }

  @override
  Future<void> approvePost(int id, bool approved) async {
    await _client
        .from('posts')
        .update({'approved': approved ? 1 : 0}).eq('id', id);
  }

  @override
  Future<void> deletePost(int id) async {
    String? media;
    final row =
        await _client.from('posts').select('media').eq('id', id).maybeSingle();
    media = row?['media'] as String?;
    await _client.from('comments').delete().eq('post_id', id);
    await _client.from('posts').delete().eq('id', id);
    await _deleteMedia(media);
  }

  @override
  Future<void> toggleLike(int id, bool liked) async {
    await _client.rpc(
      'toggle_post_like',
      params: {'p_post_id': id, 'p_liked': liked},
    );
  }

  @override
  Future<int> postCount() async => await _client.from('posts').count();

  @override
  Future<int> pendingPostsCount() async =>
      await _client.from('posts').count().eq('approved', 0);

  // ------------------------------------------------------------- comments
  @override
  Future<List<PostComment>> commentsForPost(int postId) async {
    final rows = await _client
        .from('comments_view')
        .select()
        .eq('post_id', postId)
        .order('created_at', ascending: true);
    return _maps(rows).map(PostComment.fromMap).toList();
  }

  @override
  Future<int> addComment(PostComment comment) async =>
      _insert('comments', comment.toMap());

  @override
  Future<void> deleteComment(int id) async {
    await _client.from('comments').delete().eq('id', id);
  }

  @override
  Future<int> commentCountForUser(int userId) async =>
      await _client.from('comments').count().eq('user_id', userId);

  // ------------------------------------------------------------- messages
  @override
  Future<List<ChatMessage>> threadMessages(int customerId) async {
    final rows = await _client
        .from('messages')
        .select()
        .eq('thread_id', customerId)
        .order('created_at', ascending: true);
    return _maps(rows).map(ChatMessage.fromMap).toList();
  }

  @override
  Future<int> sendMessage(ChatMessage message) async =>
      _insert('messages', message.toMap());

  @override
  Future<void> markThreadRead(int customerId,
      {required String readerRole}) async {
    final other = readerRole == 'admin' ? 'customer' : 'admin';
    await _client
        .from('messages')
        .update({'read': 1})
        .eq('thread_id', customerId)
        .eq('sender_role', other)
        .eq('read', 0);
  }

  @override
  Future<int> unreadForAdmin() async => await _client
      .from('messages')
      .count()
      .eq('sender_role', 'customer')
      .eq('read', 0);

  @override
  Future<int> unreadForCustomer(int customerId) async => await _client
      .from('messages')
      .count()
      .eq('thread_id', customerId)
      .eq('sender_role', 'admin')
      .eq('read', 0);

  @override
  Future<List<ChatThread>> messageThreads() async {
    final rows = await _client
        .from('threads_view')
        .select()
        .order('last_at', ascending: false);
    return _maps(rows)
        .map((r) => ChatThread(
              customerId: (r['thread_id'] as num?)?.toInt() ?? 0,
              customerName: r['customer_name'] as String? ?? 'زبون',
              customerPhone: r['customer_phone'] as String? ?? '',
              lastMessage: r['last_message'] as String? ?? '',
              lastAt: (DateTime.tryParse(r['last_at'] as String? ?? '') ??
                      DateTime.now())
                  .toLocal(),
              unread: (r['unread'] as num?)?.toInt() ?? 0,
            ))
        .toList();
  }

  // ---------------------------------------------------------------- cards
  @override
  Future<List<PaymentCard>> cardsForUser(int userId) async {
    final rows = await _client
        .from('cards')
        .select()
        .eq('user_id', userId)
        .order('is_default', ascending: false)
        .order('id', ascending: false);
    return _maps(rows).map(PaymentCard.fromMap).toList();
  }

  @override
  Future<int> addCard(PaymentCard card) async {
    if (card.isDefault) {
      await _client
          .from('cards')
          .update({'is_default': 0}).eq('user_id', card.userId);
    }
    return _insert('cards', card.toMap());
  }

  @override
  Future<void> deleteCard(int id) async {
    await _client.from('cards').delete().eq('id', id);
  }

  // ------------------------------------------------------------- receipts
  @override
  Future<int> createReceiptForBooking({
    required int bookingId,
    required int userId,
    required String title,
    required double amount,
    required String method,
    String? cardBrand,
    String? last4,
    required bool paid,
  }) async {
    final now = DateTime.now();
    return _insert('receipts', {
      'invoice_no': invoiceNumber(bookingId, now),
      'booking_id': bookingId,
      'user_id': userId,
      'title': title,
      'amount': amount,
      'method': method,
      'card_brand': cardBrand,
      'last4': last4,
      'paid': paid ? 1 : 0,
      'created_at': now,
    });
  }

  @override
  Future<List<Receipt>> receiptsForUser(int userId) async {
    final rows = await _client
        .from('receipts_view')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    return _maps(rows).map(Receipt.fromMap).toList();
  }

  @override
  Future<List<Receipt>> allReceipts() async {
    final rows = await _client
        .from('receipts_view')
        .select()
        .order('created_at', ascending: false);
    return _maps(rows).map(Receipt.fromMap).toList();
  }

  @override
  Future<Receipt?> receiptById(int id) async {
    final row =
        await _client.from('receipts_view').select().eq('id', id).maybeSingle();
    return row == null ? null : Receipt.fromMap(_map(row)!);
  }

  @override
  Future<Receipt?> receiptForBooking(int bookingId) async {
    final row = await _client
        .from('receipts_view')
        .select()
        .eq('booking_id', bookingId)
        .limit(1)
        .maybeSingle();
    return row == null ? null : Receipt.fromMap(_map(row)!);
  }

  @override
  Future<void> markReceiptPaid(int id, bool paid) async {
    await _client
        .from('receipts')
        .update({'paid': paid ? 1 : 0}).eq('id', id);
  }

  // ------------------------------------------------------------- settings
  @override
  Future<String> getSetting(String key, {String fallback = ''}) async {
    final row =
        await _client.from('settings').select('value').eq('key', key).maybeSingle();
    return (row?['value'] as String?) ?? fallback;
  }

  @override
  Future<void> setSetting(String key, String value) async {
    await _client
        .from('settings')
        .upsert({'key': key, 'value': value}, onConflict: 'key');
  }

  // ---------------------------------------------------------------- stats
  @override
  Future<AppStats> stats() async {
    final now = DateTime.now();
    final since = DateTime(now.year, now.month, now.day)
        .subtract(const Duration(days: 6));

    final results = await Future.wait<Object>([
      bookingsTodayCount(),
      pendingBookingsCount(),
      customerCount(),
      serviceCount(),
      postCount(),
      unreadForAdmin(),
      _client.from('receipts').select('amount').eq('paid', 1),
      _client
          .from('receipts')
          .select('amount, created_at')
          .eq('paid', 1)
          .gte('created_at', since.toUtc().toIso8601String()),
    ]);

    final paidRows = _maps(results[6]);
    final revenue = paidRows.fold<double>(
      0,
      (sum, r) => sum + ((r['amount'] as num?)?.toDouble() ?? 0),
    );

    final weeklyMap = <String, double>{};
    for (final r in _maps(results[7])) {
      final day = DateTime.tryParse(r['created_at'] as String? ?? '')?.toLocal();
      if (day == null) continue;
      final key =
          '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
      weeklyMap[key] =
          (weeklyMap[key] ?? 0) + ((r['amount'] as num?)?.toDouble() ?? 0);
    }
    final days = <RevenuePoint>[];
    for (var i = 6; i >= 0; i--) {
      final day = DateTime(now.year, now.month, now.day)
          .subtract(Duration(days: i));
      final key =
          '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
      days.add(RevenuePoint(day, weeklyMap[key] ?? 0));
    }

    return AppStats(
      bookingsToday: results[0] as int,
      pending: results[1] as int,
      customers: results[2] as int,
      services: results[3] as int,
      posts: results[4] as int,
      unreadMessages: results[5] as int,
      revenue: revenue,
      weekly: days,
    );
  }

  @override
  Future<void> resetDemoData() async {
    // البيانات مشتركة على الخادم؛ لا تُحذف من التطبيق.
  }

  @override
  Future<void> close() async {
    _debounce?.cancel();
    final channel = _channel;
    _channel = null;
    if (channel != null) {
      try {
        await _client.removeChannel(channel);
      } catch (_) {}
    }
    await _changes.close();
  }
}
