import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show debugPrint, debugPrintStack;
import 'package:path/path.dart' as path;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/utils.dart';
import 'models.dart';
import 'repository.dart';

class SupabaseRepository implements Repository {
  SupabaseRepository(this._client) {
    _subscribe();
  }

  final SupabaseClient _client;
  final StreamController<void> _changes = StreamController<void>.broadcast();
  final List<RealtimeChannel> _channels = [];
  bool _closed = false;

  @override
  Stream<void> get changes => _changes.stream;

  void _subscribe() {
    for (final table in const [
      'app_profiles',
      'categories',
      'workers',
      'services',
      'bookings',
      'posts',
      'post_likes',
      'comments',
      'our_works',
      'work_comments',
      'work_comment_reactions',
      'work_likes',
      'hire_phones',
      'craftsman_applications',
      'messages',
      'cards',
      'receipts',
      'settings',
    ]) {
      final channel = _client
          .channel('jaik-repository-$table')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: table,
            callback: (_) {
              if (!_closed && !_changes.isClosed) _changes.add(null);
            },
          )
          .subscribe();
      _channels.add(channel);
    }
  }

  List<Map<String, dynamic>> _maps(Object? value) => (value as List)
      .map((row) => Map<String, dynamic>.from(row as Map))
      .toList();

  Map<String, dynamic> _map(Object? value) =>
      Map<String, dynamic>.from(value as Map);

  Map<String, dynamic> _write(Map<String, Object?> source) {
    const booleanColumns = {
      'active',
      'available',
      'approved',
      'read',
      'is_default',
      'paid',
    };
    return {
      for (final entry in source.entries)
        if (entry.key != 'id')
          entry.key: booleanColumns.contains(entry.key) && entry.value is int
              ? entry.value == 1
              : entry.value,
    };
  }

  Map<String, dynamic> _read(Map<String, dynamic> source) {
    const booleanColumns = {
      'active',
      'available',
      'approved',
      'read',
      'is_default',
      'paid',
      'liked_by_me',
      'admin_hearted',
    };
    return {
      for (final entry in source.entries)
        entry.key: booleanColumns.contains(entry.key) && entry.value is bool
            ? (entry.value as bool ? 1 : 0)
            : entry.value,
    };
  }

  Future<List<Map<String, dynamic>>> _allRows(
    Future<dynamic> Function(int from, int to) page,
  ) async {
    const pageSize = 500;
    final result = <Map<String, dynamic>>[];
    var offset = 0;
    while (true) {
      final rows = _maps(await page(offset, offset + pageSize - 1));
      result.addAll(rows);
      if (rows.length < pageSize) return result;
      offset += pageSize;
    }
  }

  Future<List<Map<String, dynamic>>> _rowsFor(String table) =>
      _allRows((from, to) => _client.from(table).select().range(from, to));

  Future<int> _insert(String table, Map<String, Object?> values) async {
    final row = _map(
      await _client.from(table).insert(_write(values)).select('id').single(),
    );
    return (row['id'] as num).toInt();
  }

  Future<bool> _isAdmin() async {
    final authUser = _client.auth.currentUser;
    if (authUser == null) return false;
    final row = await _client
        .from('app_profiles')
        .select('role')
        .eq('auth_user_id', authUser.id)
        .maybeSingle();
    return row?['role'] == 'admin';
  }

  Future<AppUser?> _profileBy(String column, Object value) async {
    final rows = _maps(
      await _client.from('app_profiles').select().eq(column, value).limit(1),
    );
    return rows.isEmpty ? null : AppUser.fromMap(_read(rows.first));
  }

  Future<String> _uploadMedia(String localPath, String folder) async {
    if (localPath.startsWith('http://') || localPath.startsWith('https://')) {
      return localPath;
    }
    if (localPath.startsWith('asset:')) {
      throw ArgumentError('لا يمكن رفع ملفات assets المضمنة كملفات مستخدمين');
    }
    final file = File(localPath);
    if (!await file.exists()) {
      throw FileSystemException('الملف المحدد غير موجود', localPath);
    }
    final authUser = _client.auth.currentUser;
    if (authUser == null) throw StateError('يلزم تسجيل الدخول لرفع الملفات');
    final extension = path.extension(localPath).toLowerCase();
    final objectPath =
        '$folder/${authUser.id}/${DateTime.now().microsecondsSinceEpoch}$extension';
    await _client.storage.from('jaik-media').upload(
          objectPath,
          file,
          fileOptions: FileOptions(
            upsert: false,
            contentType: _contentType(extension),
          ),
        );
    return _client.storage.from('jaik-media').getPublicUrl(objectPath);
  }

  String? _contentType(String extension) => switch (extension) {
        '.jpg' || '.jpeg' => 'image/jpeg',
        '.png' => 'image/png',
        '.webp' => 'image/webp',
        '.gif' => 'image/gif',
        '.mp4' => 'video/mp4',
        '.mov' => 'video/quicktime',
        '.webm' => 'video/webm',
        _ => null,
      };

  String? _storageObjectPath(String? url) {
    if (url == null || !url.startsWith('http')) return null;
    final uri = Uri.tryParse(url);
    if (uri == null) return null;
    final marker = '/storage/v1/object/public/jaik-media/';
    final path = uri.path;
    final index = path.indexOf(marker);
    return index < 0
        ? null
        : Uri.decodeComponent(path.substring(index + marker.length));
  }

  Future<void> _removeMedia(String? url) async {
    final objectPath = _storageObjectPath(url);
    if (objectPath != null) {
      await _client.storage.from('jaik-media').remove([objectPath]);
    }
  }

  Future<Map<int, int>> _countBy(
      List<Map<String, dynamic>> rows, String key) async {
    final counts = <int, int>{};
    for (final row in rows) {
      final id = (row[key] as num).toInt();
      counts.update(id, (count) => count + 1, ifAbsent: () => 1);
    }
    return counts;
  }

  // Users and profiles.
  @override
  Future<AppUser?> findUserByPhone(String phone) =>
      _profileBy('phone', normalizePhone(phone));

  @override
  Future<AppUser?> userById(int id) => _profileBy('id', id);

  @override
  Future<int> createUser(AppUser user) async {
    throw UnsupportedError(
      'إنشاء حساب Supabase يتم بتأكيد رقم الهاتف عبر رمز OTP.',
    );
  }

  @override
  Future<void> updateUser(AppUser user) async {
    final authUser = _client.auth.currentUser;
    if (authUser == null) throw StateError('لا توجد جلسة دخول فعالة');
    await _client.from('app_profiles').update({
      'name': user.name,
      'city': user.city,
      'address': user.address,
      'avatar': user.avatarPath == null
          ? null
          : await _uploadMedia(user.avatarPath!, 'avatars'),
    }).eq('auth_user_id', authUser.id);
  }

  @override
  Future<bool> phoneExists(String phone) async =>
      await findUserByPhone(phone) != null;

  @override
  Future<List<AppUser>> listCustomers({String query = ''}) async {
    final rows = await _allRows((from, to) => _client
        .from('app_profiles')
        .select()
        .eq('role', 'customer')
        .order('created_at', ascending: false)
        .range(from, to));
    final term = query.trim().toLowerCase();
    return rows
        .where(
          (row) =>
              term.isEmpty ||
              (row['name'] as String).toLowerCase().contains(term) ||
              (row['phone'] as String).contains(term),
        )
        .map((row) => AppUser.fromMap(_read(row)))
        .toList();
  }

  @override
  Future<int> customerCount() async {
    final response = await _client
        .from('app_profiles')
        .select('id')
        .eq('role', 'customer')
        .count(CountOption.exact);
    return response.count;
  }

  // Categories.
  @override
  Future<List<Category>> listCategories() async {
    final rows = _maps(
      await _client.from('categories').select().order('sort_order').order('id'),
    );
    return rows.map((row) => Category.fromMap(row)).toList();
  }

  @override
  Future<Category?> categoryById(int id) async {
    final rows = _maps(
      await _client.from('categories').select().eq('id', id).limit(1),
    );
    return rows.isEmpty ? null : Category.fromMap(rows.first);
  }

  @override
  Future<int> saveCategory(Category category) async {
    final values = category.toMap()..remove('id');
    if (category.id == null) return _insert('categories', values);
    await _client
        .from('categories')
        .update(_write(values))
        .eq('id', category.id!);
    return category.id!;
  }

  @override
  Future<int> serviceCountForCategory(int id) async {
    final response = await _client
        .from('services')
        .select('id')
        .eq('category_id', id)
        .count(CountOption.exact);
    return response.count;
  }

  @override
  Future<void> deleteCategory(int id) async {
    await _client.from('categories').delete().eq('id', id);
  }

  // Workers.
  @override
  Future<List<Worker>> listWorkers({
    int? categoryId,
    bool onlyAvailable = false,
  }) async {
    final isAdmin = await _isAdmin();
    final rows = isAdmin
        ? _maps(await _client.rpc('list_admin_workers'))
        : await _allRows((from, to) {
            dynamic query = _client.from('workers').select(
                  'id,name,specialty,category_id,rating,jobs_done,bio,avatar,available',
                );
            if (categoryId != null) query = query.eq('category_id', categoryId);
            if (onlyAvailable) query = query.eq('available', true);
            return query.order('rating', ascending: false).range(from, to);
          });
    final workers = rows
        .where(
          (row) =>
              (categoryId == null || row['category_id'] == categoryId) &&
              (!onlyAvailable || row['available'] == true),
        )
        .map((row) => Worker.fromMap(_read(row)))
        .toList()
      ..sort((a, b) => b.rating.compareTo(a.rating));
    return workers;
  }

  @override
  Future<Worker?> workerById(int id) async {
    final isAdmin = await _isAdmin();
    final rows = isAdmin
        ? _maps(
            await _client.rpc(
              'list_admin_workers',
              params: {'p_worker_id': id},
            ),
          )
        : _maps(
            await _client
                .from('workers')
                .select(
                  'id,name,specialty,category_id,rating,jobs_done,bio,avatar,available',
                )
                .eq('id', id)
                .limit(1),
          );
    return rows.isEmpty ? null : Worker.fromMap(_read(rows.first));
  }

  @override
  Future<int> saveWorker(Worker worker) async {
    final values = worker.toMap()..remove('id');
    final avatar = worker.avatarPath;
    if (avatar != null && avatar.isNotEmpty) {
      values['avatar'] = await _uploadMedia(avatar, 'workers');
    }
    if (worker.id == null) return _insert('workers', values);
    await _client.from('workers').update(_write(values)).eq('id', worker.id!);
    return worker.id!;
  }

  @override
  Future<void> deleteWorker(int id) async {
    await _client.from('workers').delete().eq('id', id);
  }

  @override
  Future<void> incrementWorkerJobs(int? workerId) async {
    if (workerId != null) {
      await _client
          .rpc('increment_worker_jobs', params: {'p_worker_id': workerId});
    }
  }

  // Services.
  @override
  Future<List<Service>> listServices({
    int? categoryId,
    String query = '',
    bool onlyActive = true,
    int? limit,
  }) async {
    final rows = await _allRows((from, to) {
      dynamic builder = _client
          .from('services')
          .select('*,categories(name,color,icon),workers(name)');
      if (onlyActive) builder = builder.eq('active', true);
      if (categoryId != null) builder = builder.eq('category_id', categoryId);
      return builder.order('created_at', ascending: false).range(from, to);
    });
    final term = query.trim().toLowerCase();
    return rows
        .map((row) {
          final category = row['categories'] as Map<String, dynamic>?;
          final worker = row['workers'] as Map<String, dynamic>?;
          return Service.fromMap({
            ..._read(row),
            'category_name': category?['name'],
            'category_color': category?['color'],
            'category_icon': category?['icon'],
            'worker_name': worker?['name'],
            'worker_phone': worker?['phone'],
          });
        })
        .where(
          (service) =>
              term.isEmpty ||
              service.title.toLowerCase().contains(term) ||
              service.description.toLowerCase().contains(term) ||
              (service.categoryName ?? '').toLowerCase().contains(term) ||
              (service.workerName ?? '').toLowerCase().contains(term),
        )
        .toList();
  }

  @override
  Future<Service?> serviceById(int id) async {
    final rows = _maps(
      await _client
          .from('services')
          .select('*,categories(name,color,icon),workers(name)')
          .eq('id', id)
          .limit(1),
    );
    if (rows.isEmpty) return null;
    final row = rows.first;
    final category = row['categories'] as Map<String, dynamic>?;
    final worker = row['workers'] as Map<String, dynamic>?;
    return Service.fromMap({
      ..._read(row),
      'category_name': category?['name'],
      'category_color': category?['color'],
      'category_icon': category?['icon'],
      'worker_name': worker?['name'],
    });
  }

  @override
  Future<int> saveService(Service service) async {
    final values = service.toMap()..remove('id');
    if (service.id == null) return _insert('services', values);
    await _client.from('services').update(_write(values)).eq('id', service.id!);
    return service.id!;
  }

  @override
  Future<void> deleteService(int id) async {
    await _client.from('services').delete().eq('id', id);
  }

  @override
  Future<int> serviceCount() async {
    final response = await _client
        .from('services')
        .select('id')
        .eq('active', true)
        .count(CountOption.exact);
    return response.count;
  }

  // Bookings.
  Future<List<Map<String, dynamic>>> _bookingRows() async {
    return _allRows(
      (from, to) => _client
          .from('bookings')
          .select(
            '*,services(title),workers(name),app_profiles!bookings_customer_id_fkey(name,phone)',
          )
          .range(from, to),
    );
  }

  Booking _bookingFrom(Map<String, dynamic> row) {
    final service = row['services'] as Map<String, dynamic>?;
    final worker = row['workers'] as Map<String, dynamic>?;
    final customer = row['app_profiles'] as Map<String, dynamic>?;
    return Booking.fromMap({
      ..._read(row),
      'service_title': service?['title'],
      'worker_name': worker?['name'],
      'worker_phone': worker?['phone'],
      'customer_name': customer?['name'],
      'customer_phone': customer?['phone'],
    });
  }

  @override
  Future<List<Booking>> bookingsForCustomer(int customerId,
      {String? status}) async {
    final rows = await _allRows((from, to) {
      dynamic query = _client
          .from('bookings')
          .select(
              '*,services(title),workers(name),app_profiles!bookings_customer_id_fkey(name,phone)')
          .eq('customer_id', customerId);
      if (status != null) query = query.eq('status', status);
      return query.order('scheduled_at', ascending: false).range(from, to);
    });
    return rows.map(_bookingFrom).toList();
  }

  @override
  Future<List<Booking>> allBookings({String? status, String query = ''}) async {
    final rows = await _bookingRows();
    final term = query.trim().toLowerCase();
    return rows
        .where((row) {
          if (status != null && row['status'] != status) return false;
          if (term.isEmpty) return true;
          final customer = row['app_profiles'] as Map<String, dynamic>?;
          final service = row['services'] as Map<String, dynamic>?;
          return (customer?['name'] as String? ?? '')
                  .toLowerCase()
                  .contains(term) ||
              (customer?['phone'] as String? ?? '').contains(term) ||
              (service?['title'] as String? ?? '').toLowerCase().contains(term);
        })
        .map(_bookingFrom)
        .toList()
      ..sort((a, b) => b.scheduledAt.compareTo(a.scheduledAt));
  }

  @override
  Future<Booking?> bookingById(int id) async {
    final rows = _maps(
      await _client
          .from('bookings')
          .select(
              '*,services(title),workers(name),app_profiles!bookings_customer_id_fkey(name,phone)')
          .eq('id', id)
          .limit(1),
    );
    return rows.isEmpty ? null : _bookingFrom(rows.first);
  }

  @override
  Future<int> createBooking(Booking booking) async =>
      _insert('bookings', booking.toMap());

  @override
  Future<void> updateBookingStatus(int id, String status) async {
    await _client.rpc(
      'update_booking_status',
      params: {'p_booking_id': id, 'p_status': status},
    );
  }

  @override
  Future<void> assignWorker(int bookingId, int? workerId) async {
    await _client
        .from('bookings')
        .update({'worker_id': workerId}).eq('id', bookingId);
  }

  @override
  Future<bool> rateBooking({
    required int bookingId,
    required int rating,
    String? review,
  }) async {
    final result = await _client.rpc('rate_booking', params: {
      'p_booking_id': bookingId,
      'p_rating': rating.clamp(1, 5),
      'p_review': review,
    });
    return (result as num).toInt() > 0;
  }

  @override
  Future<int> bookingsTodayCount() async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day).toUtc();
    final end = start.add(const Duration(days: 1));
    final response = await _client
        .from('bookings')
        .select('id')
        .gte('scheduled_at', start.toIso8601String())
        .lt('scheduled_at', end.toIso8601String())
        .count(CountOption.exact);
    return response.count;
  }

  @override
  Future<int> pendingBookingsCount() async {
    final response = await _client
        .from('bookings')
        .select('id')
        .eq('status', BookingStatus.pending)
        .count(CountOption.exact);
    return response.count;
  }

  // Community posts and comments.
  Future<List<Map<String, dynamic>>> _postRows() async {
    final posts = await _allRows(
      (from, to) => _client
          .from('posts')
          .select(
              '*,app_profiles!posts_customer_id_fkey(name,phone),categories(name)')
          .order('created_at', ascending: false)
          .range(from, to),
    );
    if (posts.isEmpty) return posts;
    final ids = posts.map((row) => (row['id'] as num).toInt()).toList();
    final comments = await _allRows(
      (from, to) => _client
          .from('comments')
          .select('post_id')
          .inFilter('post_id', ids)
          .range(from, to),
    );
    final counts = await _countBy(comments, 'post_id');
    return posts.map((row) {
      final customer = row['app_profiles'] as Map<String, dynamic>?;
      final category = row['categories'] as Map<String, dynamic>?;
      return {
        ..._read(row),
        'customer_name': customer?['name'],
        'customer_phone': customer?['phone'],
        'category_name': category?['name'],
        'comment_count': counts[(row['id'] as num).toInt()] ?? 0,
      };
    }).toList();
  }

  @override
  Future<List<Post>> listPosts({
    bool onlyApproved = true,
    int? categoryId,
    int? customerId,
    String query = '',
    int? limit,
  }) async {
    final rows = await _postRows();
    final term = query.trim().toLowerCase();
    final result = rows.where((row) {
      if (onlyApproved && row['approved'] != 1) return false;
      if (categoryId != null && row['category_id'] != categoryId) return false;
      if (customerId != null && row['customer_id'] != customerId) return false;
      return term.isEmpty ||
          (row['title'] as String).toLowerCase().contains(term) ||
          (row['description'] as String).toLowerCase().contains(term);
    }).toList();
    return result.take(limit ?? result.length).map(Post.fromMap).toList();
  }

  @override
  Future<Post?> postById(int id) async {
    final rows = (await listPosts(onlyApproved: false))
        .where((post) => post.id == id)
        .toList();
    return rows.isEmpty ? null : rows.first;
  }

  @override
  Future<int> createPost(Post post) async {
    final values = post.toMap();
    values.remove('id');
    values['approved'] = false;
    values['likes'] = 0;
    final media = post.mediaPath;
    if (media != null && media.isNotEmpty && !media.startsWith('asset:')) {
      values['media'] = await _uploadMedia(media, 'posts');
    }
    return _insert('posts', values);
  }

  @override
  Future<void> approvePost(int id, bool approved) async {
    await _client.rpc('approve_post', params: {
      'p_post_id': id,
      'p_approved': approved,
    });
  }

  @override
  Future<void> deletePost(int id) async {
    final rows = _maps(
      await _client.from('posts').select('media').eq('id', id).limit(1),
    );
    if (rows.isNotEmpty) await _removeMedia(rows.first['media'] as String?);
    await _client.from('posts').delete().eq('id', id);
  }

  @override
  Future<void> toggleLike(int id, bool liked) async {
    await _client.rpc('set_post_like', params: {
      'p_post_id': id,
      'p_liked': liked,
    });
  }

  @override
  Future<int> postCount() async {
    final response =
        await _client.from('posts').select('id').count(CountOption.exact);
    return response.count;
  }

  @override
  Future<int> pendingPostsCount() async {
    final response = await _client
        .from('posts')
        .select('id')
        .eq('approved', false)
        .count(CountOption.exact);
    return response.count;
  }

  @override
  Future<List<PostComment>> commentsForPost(int postId) async {
    final rows = await _allRows(
      (from, to) => _client
          .from('comments')
          .select('*,app_profiles!comments_user_id_fkey(avatar)')
          .eq('post_id', postId)
          .order('created_at')
          .range(from, to),
    );
    return rows.map((row) {
      final profile = row['app_profiles'] as Map<String, dynamic>?;
      return PostComment.fromMap({...row, 'avatar': profile?['avatar']});
    }).toList();
  }

  @override
  Future<int> addComment(PostComment comment) async {
    final values = comment.toMap()..remove('id');
    return _insert('comments', values);
  }

  @override
  Future<void> deleteComment(int id) async {
    await _client.from('comments').delete().eq('id', id);
  }

  @override
  Future<int> commentCountForUser(int userId) async {
    final response = await _client
        .from('comments')
        .select('id')
        .eq('user_id', userId)
        .count(CountOption.exact);
    return response.count;
  }

  // Admin-published works, reactions, and comments.
  Future<List<Map<String, dynamic>>> _workRows() async {
    final works = await _rowsFor('our_works');
    if (works.isEmpty) return works;
    final ids = works.map((row) => (row['id'] as num).toInt()).toList();
    final comments = await _allRows(
      (from, to) => _client
          .from('work_comments')
          .select('work_id')
          .inFilter('work_id', ids)
          .range(from, to),
    );
    final likes = await _allRows(
      (from, to) => _client
          .from('work_likes')
          .select('work_id,user_id')
          .inFilter('work_id', ids)
          .range(from, to),
    );
    final commentCounts = await _countBy(comments, 'work_id');
    final likeCounts = await _countBy(likes, 'work_id');
    final userId = await _currentProfileId();
    final likedWorkIds = {
      for (final like in likes)
        if (like['user_id'] == userId) (like['work_id'] as num).toInt(),
    };
    return works
        .map((row) => {
              ...row,
              'comment_count': commentCounts[(row['id'] as num).toInt()] ?? 0,
              'likes': likeCounts[(row['id'] as num).toInt()] ?? 0,
              'liked_by_me':
                  likedWorkIds.contains((row['id'] as num).toInt()) ? 1 : 0,
            })
        .toList();
  }

  @override
  Future<List<OurWork>> listWorks({
    bool onlyActive = true,
    String query = '',
    int? limit,
    int? viewerId,
  }) async {
    final rows = await _workRows();
    final term = query.trim().toLowerCase();
    return rows
        .where((row) =>
            (!onlyActive || row['active'] == true) &&
            (term.isEmpty ||
                (row['title'] as String).toLowerCase().contains(term) ||
                (row['description'] as String? ?? '')
                    .toLowerCase()
                    .contains(term)))
        .take(limit ?? rows.length)
        .map((row) => OurWork.fromMap(_read(row)))
        .toList();
  }

  @override
  Future<OurWork?> workById(int id, {int? viewerId}) async {
    final works = await listWorks(onlyActive: false, viewerId: viewerId);
    final matching = works.where((work) => work.id == id);
    return matching.isEmpty ? null : matching.first;
  }

  @override
  Future<int> createWork(OurWork work) async {
    final values = work.toMap()..remove('id');
    return _insert('our_works', values);
  }

  @override
  Future<void> updateWork(OurWork work) async {
    if (work.id == null) return;
    await _client.from('our_works').update({
      'title': work.title,
      'description': work.description,
      'video_url': work.videoUrl,
    }).eq('id', work.id!);
  }

  @override
  Future<void> setWorkActive(int id, bool active) async {
    await _client.from('our_works').update({'active': active}).eq('id', id);
  }

  @override
  Future<void> deleteWork(int id) async {
    await _client.from('our_works').delete().eq('id', id);
  }

  @override
  Future<void> incrementWorkViews(int id) async {
    await _client.rpc('increment_work_views', params: {'p_work_id': id});
  }

  @override
  Future<void> setWorkLike(
    int id, {
    required int userId,
    required bool liked,
  }) async {
    await _client.rpc('set_work_like', params: {
      'p_work_id': id,
      'p_liked': liked,
    });
  }

  @override
  Future<List<WorkComment>> workComments(
    int workId, {
    int? viewerId,
    bool isAdmin = false,
  }) async {
    final rows = await _allRows(
      (from, to) => _client
          .from('work_comments')
          .select()
          .eq('work_id', workId)
          .order('created_at')
          .range(from, to),
    );
    final ids = rows.map((row) => (row['id'] as num).toInt()).toList();
    var reactions = <Map<String, dynamic>>[];
    if (ids.isNotEmpty) {
      try {
        reactions = await _allRows(
          (from, to) => _client
              .from('work_comment_reactions')
              .select('comment_id,user_id,reaction')
              .inFilter('comment_id', ids)
              .range(from, to),
        );
      } catch (error, stackTrace) {
        debugPrint('Failed to load work comment reactions: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
    }
    final currentUserId = viewerId ?? await _currentProfileId();
    final reactionsByComment = <int, List<Map<String, dynamic>>>{};
    for (final reaction in reactions) {
      final commentId = (reaction['comment_id'] as num).toInt();
      reactionsByComment.putIfAbsent(commentId, () => []).add(reaction);
    }
    return rows.map((row) {
      final id = (row['id'] as num).toInt();
      final commentReactions = reactionsByComment[id] ?? const [];
      final mine = commentReactions.where(
        (reaction) => (reaction['user_id'] as num).toInt() == currentUserId,
      );
      final myReaction =
          mine.isEmpty ? 0 : (mine.first['reaction'] as num).toInt();
      return WorkComment.fromMap({
        ..._read(row),
        'likes_count': commentReactions
            .where((reaction) => (reaction['reaction'] as num).toInt() == 1)
            .length,
        'dislikes_count': commentReactions
            .where((reaction) => (reaction['reaction'] as num).toInt() == -1)
            .length,
        'my_reaction': myReaction,
        'admin_hearted': isAdmin && row['admin_hearted'] == true,
      });
    }).toList();
  }

  @override
  Future<int> addWorkComment(WorkComment comment) async {
    final values = comment.toMap()..remove('id');
    return _insert('work_comments', values);
  }

  @override
  Future<void> updateWorkComment(int id, {required String body}) async {
    await _client.from('work_comments').update({'body': body}).eq('id', id);
  }

  @override
  Future<void> setWorkCommentReaction(
    int commentId, {
    required int userId,
    required int reaction,
  }) async {
    if (reaction != -1 && reaction != 0 && reaction != 1) {
      throw ArgumentError.value(reaction, 'reaction');
    }
    await _client.rpc('set_work_comment_reaction', params: {
      'p_comment_id': commentId,
      'p_reaction': reaction,
    });
  }

  @override
  Future<void> setWorkCommentHeart(
    int commentId, {
    required bool hearted,
  }) async {
    await _client.rpc('set_work_comment_heart', params: {
      'p_comment_id': commentId,
      'p_hearted': hearted,
    });
  }

  @override
  Future<int> workCount() async {
    final response =
        await _client.from('our_works').select('id').count(CountOption.exact);
    return response.count;
  }

  // Hired phone numbers.
  @override
  Future<int> createHire(Hire hire) async {
    final values = hire.toMap()..remove('id');
    final existing = _maps(
      await _client
          .from('hire_phones')
          .select('id')
          .eq('phone', normalizePhone(hire.phone))
          .limit(1),
    );
    if (existing.isEmpty) return _insert('hire_phones', values);
    final id = (existing.first['id'] as num).toInt();
    await _client.from('hire_phones').update({
      'note': hire.note,
      'created_at': hire.createdAt.toIso8601String()
    }).eq('id', id);
    return id;
  }

  @override
  Future<List<Hire>> listHires() async {
    final rows = _maps(
      await _client
          .from('hire_phones')
          .select()
          .order('created_at', ascending: false),
    );
    final profiles =
        _maps(await _client.from('app_profiles').select('id,phone,name'));
    final profilesByPhone = {
      for (final profile in profiles) profile['phone'] as String: profile,
    };
    return rows.map((row) {
      final profile = profilesByPhone[row['phone']];
      return Hire.fromMap({
        ...row,
        'user_id': profile?['id'],
        'user_name': profile?['name'],
      });
    }).toList();
  }

  @override
  Future<bool> isHiredPhone(String phone) async {
    final rows = _maps(
      await _client
          .from('hire_phones')
          .select('id')
          .eq('phone', normalizePhone(phone))
          .limit(1),
    );
    return rows.isNotEmpty;
  }

  @override
  Future<void> deleteHire(int id) async {
    await _client.from('hire_phones').delete().eq('id', id);
  }

  // Craftsman applications.
  @override
  Future<int> createApplication(CraftsmanApplication application) async {
    final result = await _client.rpc(
      'submit_craftsman_application',
      params: {
        'p_name': application.name.trim(),
        'p_phone': normalizePhone(application.phone),
        'p_age': application.age,
        'p_city': application.city.trim(),
        'p_address': application.address?.trim(),
        'p_trade': application.trade.trim(),
        'p_experience_years': application.experienceYears,
        'p_about': application.about?.trim(),
      },
    );
    return (result as num).toInt();
  }

  @override
  Future<List<CraftsmanApplication>> listApplications() async {
    final rows = await _allRows(
      (from, to) => _client
          .from('craftsman_applications')
          .select()
          .order('created_at', ascending: false)
          .range(from, to),
    );
    return rows.map(CraftsmanApplication.fromMap).toList();
  }

  @override
  Future<bool> hasPendingApplication(String phone) async {
    final result = await _client.rpc(
      'has_pending_craftsman_application',
      params: {'p_phone': normalizePhone(phone)},
    );
    return result as bool;
  }

  @override
  Future<void> acceptApplication(CraftsmanApplication application) async {
    final id = application.id;
    if (id == null) throw ArgumentError('Application must have an id');
    await _client.rpc(
      'accept_craftsman_application',
      params: {'p_application_id': id},
    );
  }

  @override
  Future<void> rejectApplication(int id) async {
    await _client.rpc(
      'reject_craftsman_application',
      params: {'p_application_id': id},
    );
  }

  // Support messages.
  Future<int> _currentProfileId() async {
    final authUser = _client.auth.currentUser;
    if (authUser == null) throw StateError('لا توجد جلسة دخول فعالة');
    final rows = _maps(
      await _client
          .from('app_profiles')
          .select('id')
          .eq('auth_user_id', authUser.id)
          .limit(1),
    );
    if (rows.isEmpty) throw StateError('تعذر العثور على ملف الحساب');
    return (rows.first['id'] as num).toInt();
  }

  @override
  Future<List<ChatMessage>> threadMessages(int customerId) async {
    final rows = _maps(
      await _client
          .from('messages')
          .select()
          .eq('thread_id', customerId)
          .order('created_at'),
    );
    return rows.map((row) => ChatMessage.fromMap(_read(row))).toList();
  }

  @override
  Future<int> sendMessage(ChatMessage message) async {
    final userId = await _currentProfileId();
    final values = message.toMap()
      ..remove('id')
      ..['sender_id'] = userId;
    return _insert('messages', values);
  }

  @override
  Future<void> markThreadRead(
    int customerId, {
    required String readerRole,
  }) async {
    final senderRole = readerRole == 'admin' ? 'customer' : 'admin';
    await _client
        .from('messages')
        .update({'read': true})
        .eq('thread_id', customerId)
        .eq('sender_role', senderRole)
        .eq('read', false);
  }

  @override
  Future<int> unreadForAdmin() async {
    final response = await _client
        .from('messages')
        .select('id')
        .eq('sender_role', 'customer')
        .eq('read', false)
        .count(CountOption.exact);
    return response.count;
  }

  @override
  Future<int> unreadForCustomer(int customerId) async {
    final response = await _client
        .from('messages')
        .select('id')
        .eq('thread_id', customerId)
        .eq('sender_role', 'admin')
        .eq('read', false)
        .count(CountOption.exact);
    return response.count;
  }

  @override
  Future<List<ChatThread>> messageThreads() async {
    final messages = await _allRows(
      (from, to) => _client
          .from('messages')
          .select('*,app_profiles!messages_thread_id_fkey(name,phone)')
          .order('created_at', ascending: false)
          .range(from, to),
    );
    final latestByThread = <int, ChatThread>{};
    final unreadByThread = <int, int>{};
    for (final message in messages) {
      if (message['sender_role'] != 'customer' || message['read'] == true) {
        continue;
      }
      final threadId = (message['thread_id'] as num).toInt();
      unreadByThread.update(
        threadId,
        (count) => count + 1,
        ifAbsent: () => 1,
      );
    }
    for (final row in messages) {
      final threadId = (row['thread_id'] as num).toInt();
      final profile = row['app_profiles'] as Map<String, dynamic>?;
      latestByThread.putIfAbsent(
        threadId,
        () => ChatThread(
          customerId: threadId,
          customerName: profile?['name'] as String? ?? 'زبون',
          customerPhone: profile?['phone'] as String? ?? '',
          lastMessage: row['body'] as String? ?? '',
          lastAt: DateTime.parse(row['created_at'] as String).toLocal(),
          unread: unreadByThread[threadId] ?? 0,
        ),
      );
    }
    return latestByThread.values.toList()
      ..sort((a, b) => b.lastAt.compareTo(a.lastAt));
  }

  // Saved card display data (no full card numbers are stored).
  @override
  Future<List<PaymentCard>> cardsForUser(int userId) async {
    final rows = _maps(
      await _client
          .from('cards')
          .select()
          .eq('user_id', userId)
          .order('is_default', ascending: false)
          .order('id', ascending: false),
    );
    return rows.map((row) => PaymentCard.fromMap(_read(row))).toList();
  }

  @override
  Future<int> addCard(PaymentCard card) async {
    final values = card.toMap()..remove('id');
    return _insert('cards', values);
  }

  @override
  Future<void> deleteCard(int id) async {
    await _client.from('cards').delete().eq('id', id);
  }

  // Receipts.
  Future<List<Map<String, dynamic>>> _receiptRows() => _allRows(
        (from, to) => _client
            .from('receipts')
            .select(
              '*,bookings!left(worker_id,services(title),workers(name)),app_profiles!receipts_user_id_fkey(name,phone)',
            )
            .range(from, to),
      );

  Receipt _receiptFrom(Map<String, dynamic> row) {
    final booking = row['bookings'] as Map<String, dynamic>?;
    final service = booking?['services'] as Map<String, dynamic>?;
    final worker = booking?['workers'] as Map<String, dynamic>?;
    final profile = row['app_profiles'] as Map<String, dynamic>?;
    return Receipt.fromMap({
      ..._read(row),
      'service_title': service?['title'],
      'worker_name': worker?['name'],
      'customer_name': profile?['name'],
      'customer_phone': profile?['phone'],
    });
  }

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
      'created_at': now.toIso8601String(),
    });
  }

  @override
  Future<List<Receipt>> receiptsForUser(int userId) async {
    final rows = await _receiptRows();
    return rows
        .where((row) => row['user_id'] == userId)
        .map(_receiptFrom)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  @override
  Future<List<Receipt>> allReceipts() async {
    final rows = await _receiptRows();
    return rows.map(_receiptFrom).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  @override
  Future<Receipt?> receiptById(int id) async {
    final rows = (await _receiptRows()).where((row) => row['id'] == id);
    return rows.isEmpty ? null : _receiptFrom(rows.first);
  }

  @override
  Future<Receipt?> receiptForBooking(int bookingId) async {
    final rows =
        (await _receiptRows()).where((row) => row['booking_id'] == bookingId);
    return rows.isEmpty ? null : _receiptFrom(rows.first);
  }

  @override
  Future<void> markReceiptPaid(int id, bool paid) async {
    await _client.from('receipts').update({'paid': paid}).eq('id', id);
  }

  // Settings.
  @override
  Future<String> getSetting(String key, {String fallback = ''}) async {
    final rows = _maps(
      await _client.from('settings').select('value').eq('key', key).limit(1),
    );
    return rows.isEmpty ? fallback : rows.first['value'] as String;
  }

  @override
  Future<void> setSetting(String key, String value) async {
    await _client.from('settings').upsert({'key': key, 'value': value});
  }

  // Dashboard statistics.
  @override
  Future<AppStats> stats() async {
    final today = await bookingsTodayCount();
    final pending = await pendingBookingsCount();
    final customers = await customerCount();
    final services = await serviceCount();
    final unread = await unreadForAdmin();
    final posts = await postCount();
    final works = await workCount();
    final receipts = await _rowsFor('receipts');
    final paid = receipts.where((row) => row['paid'] == true).toList();
    final revenue = paid.fold<double>(
      0,
      (sum, row) => sum + (row['amount'] as num).toDouble(),
    );
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day)
        .subtract(const Duration(days: 6));
    final amountsByDay = <String, double>{};
    for (final row in paid) {
      final createdAt = DateTime.parse(row['created_at'] as String).toLocal();
      final key =
          '${createdAt.year}-${createdAt.month.toString().padLeft(2, '0')}-${createdAt.day.toString().padLeft(2, '0')}';
      amountsByDay.update(
        key,
        (sum) => sum + (row['amount'] as num).toDouble(),
        ifAbsent: () => (row['amount'] as num).toDouble(),
      );
    }
    final weekly = <RevenuePoint>[
      for (var offset = 6; offset >= 0; offset--)
        () {
          final day = start.add(Duration(days: 6 - offset));
          final key =
              '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
          return RevenuePoint(day, amountsByDay[key] ?? 0);
        }(),
    ];
    return AppStats(
      bookingsToday: today,
      revenue: revenue,
      customers: customers,
      pending: pending,
      services: services,
      posts: posts,
      works: works,
      unreadMessages: unread,
      weekly: weekly,
    );
  }

  @override
  Future<void> resetDemoData() async {
    throw UnsupportedError(
      'إعادة الضبط غير متاحة في الوضع السحابي حتى لا تُحذف بيانات المستخدمين.',
    );
  }

  @override
  Future<void> close() async {
    _closed = true;
    for (final channel in _channels) {
      await _client.removeChannel(channel);
    }
    await _changes.close();
  }
}
