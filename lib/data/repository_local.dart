import 'dart:io';

import 'package:sqflite/sqflite.dart';

import '../core/language.dart';
import '../core/utils.dart';
import 'database.dart';
import 'models.dart';
import 'repository.dart';

/// تنفيذ قاعدة البيانات المحلية (SQLite) — التخزين الوحيد للتطبيق.
class LocalRepository implements Repository {
  LocalRepository();
  final AppDatabase _appDb = AppDatabase.instance;
  Future<Database> get _db => _appDb.database;

  @override
  Stream<void> get changes => const Stream<void>.empty();

  // ---------------------------------------------------------------- users
  @override
  Future<AppUser?> findUserByPhone(String phone) async {
    final db = await _db;
    final rows = await db.query('users',
        where: 'phone = ?', whereArgs: [normalizePhone(phone)], limit: 1);
    return rows.isEmpty ? null : AppUser.fromMap(rows.first);
  }

  @override
  Future<AppUser?> userById(int id) async {
    final db = await _db;
    final rows =
        await db.query('users', where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : AppUser.fromMap(rows.first);
  }

  @override
  Future<int> createUser(AppUser user) async {
    final db = await _db;
    return db.insert('users', user.toMap());
  }

  @override
  Future<void> updateUser(AppUser user) async {
    final db = await _db;
    await db
        .update('users', user.toMap(), where: 'id = ?', whereArgs: [user.id]);
  }

  @override
  Future<bool> phoneExists(String phone) async =>
      (await findUserByPhone(phone)) != null;

  @override
  Future<List<AppUser>> listCustomers({String query = ''}) async {
    final db = await _db;
    final rows = await db.query(
      'users',
      where: query.trim().isEmpty
          ? "role = 'customer'"
          : "role = 'customer' AND (name LIKE ? OR phone LIKE ?)",
      whereArgs: query.trim().isEmpty
          ? null
          : ['%${query.trim()}%', '%${query.trim()}%'],
      orderBy: 'created_at DESC',
    );
    return rows.map(AppUser.fromMap).toList();
  }

  @override
  Future<int> customerCount() async {
    final db = await _db;
    final r =
        await db.rawQuery("SELECT COUNT(*) c FROM users WHERE role='customer'");
    return (r.first['c'] as int?) ?? 0;
  }

  // ----------------------------------------------------------- categories
  @override
  Future<List<Category>> listCategories() async {
    final db = await _db;
    final rows =
        await db.query('categories', orderBy: 'sort_order ASC, id ASC');
    return rows.map(Category.fromMap).toList();
  }

  @override
  Future<Category?> categoryById(int id) async {
    final db = await _db;
    final rows = await db.query('categories',
        where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : Category.fromMap(rows.first);
  }

  @override
  Future<int> saveCategory(Category c) async {
    final db = await _db;
    if (c.id == null) return db.insert('categories', c.toMap());
    await db
        .update('categories', c.toMap(), where: 'id = ?', whereArgs: [c.id]);
    return c.id!;
  }

  @override
  Future<int> serviceCountForCategory(int id) async {
    final db = await _db;
    final r = await db
        .rawQuery('SELECT COUNT(*) c FROM services WHERE category_id=?', [id]);
    return (r.first['c'] as int?) ?? 0;
  }

  @override
  Future<void> deleteCategory(int id) async {
    final db = await _db;
    await db.delete('categories', where: 'id = ?', whereArgs: [id]);
  }

  // -------------------------------------------------------------- workers
  @override
  Future<List<Worker>> listWorkers(
      {int? categoryId, bool onlyAvailable = false}) async {
    final db = await _db;
    final where = <String>[];
    final args = <Object?>[];
    if (categoryId != null) {
      where.add('category_id = ?');
      args.add(categoryId);
    }
    if (onlyAvailable) where.add('available = 1');
    final rows = await db.query(
      'workers',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      // التساوي في التقييم يُفكّ برقم الحرفي، وإلا بدّلت الصفوف أماكنها عند كل تحميل.
      orderBy: 'rating DESC, id ASC',
    );
    return rows.map(Worker.fromMap).toList();
  }

  @override
  Future<Worker?> workerById(int id) async {
    final db = await _db;
    final rows =
        await db.query('workers', where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : Worker.fromMap(rows.first);
  }

  @override
  Future<Worker?> workerByPhone(String phone) async {
    final db = await _db;
    final rows = await db.query(
      'workers',
      where: 'phone = ?',
      whereArgs: [normalizePhone(phone)],
      limit: 1,
    );
    return rows.isEmpty ? null : Worker.fromMap(rows.first);
  }

  @override
  Future<void> updateWorkerCity(String phone, String city) async {
    final value = city.trim();
    if (value.isEmpty) return;
    final db = await _db;
    await db.update(
      'workers',
      {'city': value},
      where: 'phone = ?',
      whereArgs: [normalizePhone(phone)],
    );
  }

  @override
  Future<int> saveWorker(Worker w) async {
    final db = await _db;
    if (w.id == null) return db.insert('workers', w.toMap());
    await db.update('workers', w.toMap(), where: 'id = ?', whereArgs: [w.id]);
    return w.id!;
  }

  @override
  Future<void> deleteWorker(int id) async {
    final db = await _db;
    await db.update('services', {'worker_id': null},
        where: 'worker_id = ?', whereArgs: [id]);
    await db.delete('workers', where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<void> incrementWorkerJobs(int? workerId) async {
    if (workerId == null) return;
    final db = await _db;
    await db.rawUpdate(
        'UPDATE workers SET jobs_done = jobs_done + 1 WHERE id = ?',
        [workerId]);
  }

  // ------------------------------------------------------------- services
  static const _serviceSelect = '''
    SELECT s.*, c.name AS category_name, c.color AS category_color, c.icon AS category_icon,
           w.name AS worker_name, w.phone AS worker_phone
    FROM services s
    LEFT JOIN categories c ON c.id = s.category_id
    LEFT JOIN workers w ON w.id = s.worker_id
  ''';

  @override
  Future<List<Service>> listServices({
    int? categoryId,
    String query = '',
    bool onlyActive = true,
    int? limit,
  }) async {
    final db = await _db;
    final where = <String>[];
    final args = <Object?>[];
    if (onlyActive) where.add('s.active = 1');
    if (categoryId != null) {
      where.add('s.category_id = ?');
      args.add(categoryId);
    }
    if (query.trim().isNotEmpty) {
      where.add(
          '(s.title LIKE ? OR s.description LIKE ? OR w.name LIKE ? OR c.name LIKE ?)');
      final q = '%${query.trim()}%';
      args.addAll([q, q, q, q]);
    }
    final sql =
        '$_serviceSelect ${where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}'} '
        'ORDER BY s.created_at DESC ${limit != null ? 'LIMIT $limit' : ''}';
    final rows = await db.rawQuery(sql, args);
    return rows.map(Service.fromMap).toList();
  }

  @override
  Future<Service?> serviceById(int id) async {
    final db = await _db;
    final rows = await db.rawQuery('$_serviceSelect WHERE s.id = ?', [id]);
    return rows.isEmpty ? null : Service.fromMap(rows.first);
  }

  @override
  Future<int> saveService(Service s) async {
    final db = await _db;
    if (s.id == null) return db.insert('services', s.toMap());
    await db.update('services', s.toMap(), where: 'id = ?', whereArgs: [s.id]);
    return s.id!;
  }

  @override
  Future<void> deleteService(int id) async {
    final db = await _db;
    await db.delete('services', where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<int> serviceCount() async {
    final db = await _db;
    final r =
        await db.rawQuery('SELECT COUNT(*) c FROM services WHERE active=1');
    return (r.first['c'] as int?) ?? 0;
  }

  // ------------------------------------------------------------- bookings
  static const _bookingSelect = '''
    SELECT b.*, s.title AS service_title, w.name AS worker_name, w.phone AS worker_phone,
           u.name AS customer_name, u.phone AS customer_phone, u.city AS customer_city
    FROM bookings b
    LEFT JOIN services s ON s.id = b.service_id
    LEFT JOIN workers w ON w.id = b.worker_id
    LEFT JOIN users u ON u.id = b.customer_id
  ''';

  @override
  Future<List<Booking>> bookingsForCustomer(int customerId,
      {String? status}) async {
    final db = await _db;
    final rows = await db.rawQuery(
      '$_bookingSelect WHERE b.customer_id = ? '
      '${status == null ? '' : 'AND b.status = ?'} ORDER BY b.scheduled_at DESC',
      [customerId, if (status != null) status],
    );
    return rows.map(Booking.fromMap).toList();
  }

  @override
  Future<List<Booking>> allBookings({String? status, String query = ''}) async {
    final db = await _db;
    final where = <String>[];
    final args = <Object?>[];
    if (status != null) {
      where.add('b.status = ?');
      args.add(status);
    }
    if (query.trim().isNotEmpty) {
      where.add('(u.name LIKE ? OR u.phone LIKE ? OR s.title LIKE ?)');
      final q = '%${query.trim()}%';
      args.addAll([q, q, q]);
    }
    final rows = await db.rawQuery(
      '$_bookingSelect ${where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}'} '
      'ORDER BY b.scheduled_at DESC',
      args,
    );
    return rows.map(Booking.fromMap).toList();
  }

  @override
  Future<Booking?> bookingById(int id) async {
    final db = await _db;
    final rows = await db.rawQuery('$_bookingSelect WHERE b.id = ?', [id]);
    return rows.isEmpty ? null : Booking.fromMap(rows.first);
  }

  @override
  Future<int> createBooking(Booking b) async {
    final db = await _db;
    return db.insert('bookings', b.toMap());
  }

  @override
  Future<void> updateBookingStatus(int id, String status) async {
    final db = await _db;
    await db.update(
      'bookings',
      {
        'status': status,
        if (status == BookingStatus.dispatched)
          'dispatched_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    if (status == BookingStatus.completed) {
      final rows = await db.query('bookings',
          columns: ['worker_id'], where: 'id=?', whereArgs: [id]);
      if (rows.isNotEmpty) {
        await incrementWorkerJobs(rows.first['worker_id'] as int?);
      }
    }
  }

  @override
  Future<void> assignWorker(int bookingId, int? workerId) async {
    final db = await _db;
    await db.update(
      'bookings',
      {'worker_id': workerId, 'worker_response': WorkerResponse.pending},
      where: 'id = ?',
      whereArgs: [bookingId],
    );
  }

  @override
  Future<void> setBookingPrice(int bookingId, double amount) async {
    final db = await _db;
    final booking = await bookingById(bookingId);
    if (booking == null) return;
    await db.update('bookings', {'total': amount},
        where: 'id = ?', whereArgs: [bookingId]);
    final receipt = await receiptForBooking(bookingId);
    if (receipt == null) {
      await createReceiptForBooking(
        bookingId: bookingId,
        userId: booking.customerId,
        title: 'وصل دفع خدمة',
        amount: amount,
        method: 'cash',
        paid: false,
      );
    } else if (!receipt.paid) {
      await db.update('receipts', {'amount': amount},
          where: 'id = ?', whereArgs: [receipt.id]);
    }
  }

  @override
  Future<void> adminUpdateBooking(
    int bookingId, {
    required DateTime scheduledAt,
    required String slot,
    required String address,
    String? notes,
    String? adminNote,
  }) async {
    final db = await _db;
    final old = await bookingById(bookingId);
    if (old == null) return;
    String day(DateTime d) =>
        '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';
    final changes = <String>[
      if (day(old.scheduledAt) != day(scheduledAt))
        'الموعد: ${day(old.scheduledAt)} ← ${day(scheduledAt)}.',
      if (old.slot != slot) 'الوقت: ${old.slot} ← $slot.',
      if (old.address != address.trim()) 'العنوان تغيّر.',
      if ((old.notes ?? '') != (notes ?? '').trim()) 'الملاحظات تغيّرت.',
    ];
    if (changes.isEmpty && (old.adminNote ?? '') == (adminNote ?? '').trim()) {
      return;
    }
    final scheduleChanged =
        day(old.scheduledAt) != day(scheduledAt) || old.slot != slot;
    await db.update(
      'bookings',
      {
        'scheduled_at': scheduledAt.toIso8601String(),
        'slot': slot,
        'address': address.trim(),
        'notes': (notes ?? '').trim().isEmpty ? null : notes!.trim(),
        'admin_note':
            (adminNote ?? '').trim().isEmpty ? null : adminNote!.trim(),
        'admin_edited_at': DateTime.now().toIso8601String(),
        'edit_summary': changes.isEmpty ? null : changes.join(' '),
        'customer_ack': CustomerAck.pending,
        if (scheduleChanged && old.workerId != null)
          'worker_response': WorkerResponse.pending,
      },
      where: 'id = ?',
      whereArgs: [bookingId],
    );
  }

  @override
  Future<void> respondToBookingEdit(int bookingId,
      {required bool approve}) async {
    final db = await _db;
    await db.update(
      'bookings',
      {'customer_ack': approve ? CustomerAck.approved : CustomerAck.declined},
      where: 'id = ? AND customer_ack = ?',
      whereArgs: [bookingId, CustomerAck.pending],
    );
  }

  @override
  Future<List<Booking>> bookingsForWorker(AppUser worker) async {
    final db = await _db;
    final rows = await db.rawQuery(
      '$_bookingSelect WHERE w.phone = ? ORDER BY b.created_at DESC',
      [normalizePhone(worker.phone)],
    );
    // العنوان ورقم الزبون لا يصلان إلى الحرفي قبل أن ترسله الإدارة.
    return [
      for (final row in rows) _hideUntilSent(Booking.fromMap(row)),
    ];
  }

  Booking _hideUntilSent(Booking b) => b.sentToCustomer
      ? b
      : Booking(
          id: b.id,
          customerId: b.customerId,
          serviceId: b.serviceId,
          workerId: b.workerId,
          scheduledAt: b.scheduledAt,
          slot: b.slot,
          address: '',
          notes: b.notes,
          status: b.status,
          paymentMethod: b.paymentMethod,
          total: b.total,
          createdAt: b.createdAt,
          workerResponse: b.workerResponse,
          dispatchedAt: b.dispatchedAt,
          serviceTitle: b.serviceTitle,
          workerName: b.workerName,
          customerName: b.customerName,
        );

  @override
  Future<void> respondToBooking(int bookingId, {required bool accept}) async {
    final db = await _db;
    await db.update(
      'bookings',
      {
        'worker_response':
            accept ? WorkerResponse.accepted : WorkerResponse.declined
      },
      where: 'id = ? AND status IN (?, ?)',
      whereArgs: [bookingId, BookingStatus.pending, BookingStatus.confirmed],
    );
  }

  @override
  Future<bool> rateBooking({
    required int bookingId,
    required int rating,
    String? review,
  }) async {
    final db = await _db;
    final stars = rating.clamp(1, 5);
    return db.transaction<bool>((tx) async {
      final rows = await tx.query('bookings',
          columns: ['id', 'worker_id', 'status', 'rating'],
          where: 'id = ?',
          whereArgs: [bookingId],
          limit: 1);
      if (rows.isEmpty) return false;
      final b = rows.first;
      if (b['status'] != BookingStatus.completed) return false;
      if (b['rating'] != null) return false;

      await tx.update(
        'bookings',
        {'rating': stars, 'review': review},
        where: 'id = ?',
        whereArgs: [bookingId],
      );

      // تحديث متوسط تقييم العامل من كل تقييماته.
      final workerId = b['worker_id'] as int?;
      if (workerId != null) {
        final agg = await tx.rawQuery(
          'SELECT AVG(rating) a, COUNT(*) c FROM bookings '
          'WHERE worker_id = ? AND rating IS NOT NULL',
          [workerId],
        );
        await tx.update(
          'workers',
          {'rating': ((agg.first['a'] as num?) ?? 0).toDouble()},
          where: 'id = ?',
          whereArgs: [workerId],
        );
      }

      return true;
    });
  }

  @override
  Future<int> bookingsTodayCount() async {
    final db = await _db;
    final r = await db.rawQuery(
      "SELECT COUNT(*) c FROM bookings WHERE date(scheduled_at) = date('now','localtime')",
    );
    return (r.first['c'] as int?) ?? 0;
  }

  @override
  Future<int> pendingBookingsCount() async {
    final db = await _db;
    final r = await db
        .rawQuery("SELECT COUNT(*) c FROM bookings WHERE status='pending'");
    return (r.first['c'] as int?) ?? 0;
  }

  // ---------------------------------------------------------------- posts
  static const _postSelect = '''
    SELECT p.*, u.name AS customer_name, u.phone AS customer_phone, c.name AS category_name,
      (SELECT COUNT(*) FROM comments cm WHERE cm.post_id = p.id) AS comment_count
    FROM posts p
    LEFT JOIN users u ON u.id = p.customer_id
    LEFT JOIN categories c ON c.id = p.category_id
  ''';

  @override
  Future<List<Post>> listPosts({
    bool onlyApproved = true,
    int? categoryId,
    int? customerId,
    String query = '',
    int? limit,
  }) async {
    final db = await _db;
    final where = <String>[];
    final args = <Object?>[];
    if (onlyApproved) where.add('p.approved = 1');
    if (categoryId != null) {
      where.add('p.category_id = ?');
      args.add(categoryId);
    }
    if (customerId != null) {
      where.add('p.customer_id = ?');
      args.add(customerId);
    }
    if (query.trim().isNotEmpty) {
      where.add('(p.title LIKE ? OR p.description LIKE ?)');
      final q = '%${query.trim()}%';
      args.addAll([q, q]);
    }
    final rows = await db.rawQuery(
      '$_postSelect ${where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}'} '
      'ORDER BY p.created_at DESC ${limit != null ? 'LIMIT $limit' : ''}',
      args,
    );
    return rows.map(Post.fromMap).toList();
  }

  @override
  Future<Post?> postById(int id) async {
    final db = await _db;
    final rows = await db.rawQuery('$_postSelect WHERE p.id = ?', [id]);
    return rows.isEmpty ? null : Post.fromMap(rows.first);
  }

  @override
  Future<int> createPost(Post p) async {
    final db = await _db;
    return db.insert('posts', p.toMap());
  }

  @override
  Future<void> approvePost(int id, bool approved) async {
    final db = await _db;
    await db.update('posts', {'approved': approved ? 1 : 0},
        where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<void> deletePost(int id) async {
    final db = await _db;
    final rows = await db.query('posts',
        columns: ['media'], where: 'id=?', whereArgs: [id]);
    if (rows.isNotEmpty) {
      final media = rows.first['media'] as String?;
      if (media != null && !media.startsWith('asset:')) {
        final f = File(media);
        if (await f.exists()) {
          try {
            await f.delete();
          } catch (_) {}
        }
      }
    }
    await db.delete('comments', where: 'post_id = ?', whereArgs: [id]);
    await db.delete('posts', where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<void> toggleLike(int id, bool liked) async {
    final db = await _db;
    await db.rawUpdate(
        'UPDATE posts SET likes = MAX(0, likes + ?) WHERE id = ?',
        [liked ? 1 : -1, id]);
  }

  @override
  Future<int> postCount() async {
    final db = await _db;
    final r = await db.rawQuery('SELECT COUNT(*) c FROM posts');
    return (r.first['c'] as int?) ?? 0;
  }

  @override
  Future<int> pendingPostsCount() async {
    final db = await _db;
    final r =
        await db.rawQuery('SELECT COUNT(*) c FROM posts WHERE approved = 0');
    return (r.first['c'] as int?) ?? 0;
  }

  // ------------------------------------------------------------- comments
  @override
  Future<List<PostComment>> commentsForPost(int postId) async {
    final db = await _db;
    final rows = await db.rawQuery('''
      SELECT cm.*, u.avatar AS avatar FROM comments cm
      LEFT JOIN users u ON u.id = cm.user_id
      WHERE cm.post_id = ? ORDER BY cm.created_at ASC
    ''', [postId]);
    return rows.map(PostComment.fromMap).toList();
  }

  @override
  Future<int> addComment(PostComment c) async {
    final db = await _db;
    return db.insert('comments', c.toMap());
  }

  @override
  Future<void> deleteComment(int id) async {
    final db = await _db;
    await db.delete('comments', where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<int> commentCountForUser(int userId) async {
    final db = await _db;
    final r = await db
        .rawQuery('SELECT COUNT(*) c FROM comments WHERE user_id=?', [userId]);
    return (r.first['c'] as int?) ?? 0;
  }

  // ----------------------------------------------------------- أعمالنا (فيديو)
  static const _workSelect = '''
    SELECT w.*,
      (SELECT COUNT(*) FROM work_comments wc WHERE wc.work_id = w.id) AS comment_count,
      (SELECT COUNT(*) FROM work_likes wl WHERE wl.work_id = w.id AND wl.user_id = ?) AS liked_by_me
    FROM our_works w
  ''';

  @override
  Future<List<OurWork>> listWorks({
    bool onlyActive = true,
    String query = '',
    int? limit,
    int? viewerId,
  }) async {
    final db = await _db;
    final where = <String>[];
    final args = <Object?>[viewerId ?? -1];
    if (onlyActive) where.add('w.active = 1');
    if (query.trim().isNotEmpty) {
      where.add('(w.title LIKE ? OR w.description LIKE ?)');
      final q = '%${query.trim()}%';
      args.addAll([q, q]);
    }
    final rows = await db.rawQuery(
      '$_workSelect ${where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}'} '
      'ORDER BY w.created_at DESC ${limit != null ? 'LIMIT $limit' : ''}',
      args,
    );
    return rows.map(OurWork.fromMap).toList();
  }

  @override
  Future<OurWork?> workById(int id, {int? viewerId}) async {
    final db = await _db;
    final rows =
        await db.rawQuery('$_workSelect WHERE w.id = ?', [viewerId ?? -1, id]);
    return rows.isEmpty ? null : OurWork.fromMap(rows.first);
  }

  @override
  Future<int> createWork(OurWork work) async {
    final db = await _db;
    return db.insert('our_works', work.toMap());
  }

  @override
  Future<void> updateWork(OurWork work) async {
    final db = await _db;
    if (work.id == null) return;
    await db.update(
      'our_works',
      {
        'title': work.title,
        'description': work.description,
        'video_url': work.videoUrl,
      },
      where: 'id = ?',
      whereArgs: [work.id],
    );
  }

  @override
  Future<void> setWorkActive(int id, bool active) async {
    final db = await _db;
    await db.update('our_works', {'active': active ? 1 : 0},
        where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<void> deleteWork(int id) async {
    final db = await _db;
    await db.delete(
      'work_comment_reactions',
      where: 'comment_id IN (SELECT id FROM work_comments WHERE work_id = ?)',
      whereArgs: [id],
    );
    await db.delete('work_comments', where: 'work_id = ?', whereArgs: [id]);
    await db.delete('work_likes', where: 'work_id = ?', whereArgs: [id]);
    await db.delete('our_works', where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<void> incrementWorkViews(int id) async {
    final db = await _db;
    await db
        .rawUpdate('UPDATE our_works SET views = views + 1 WHERE id = ?', [id]);
  }

  @override
  Future<void> setWorkLike(int id,
      {required int userId, required bool liked}) async {
    final db = await _db;
    if (liked) {
      await db.insert('work_likes', {'work_id': id, 'user_id': userId},
          conflictAlgorithm: ConflictAlgorithm.ignore);
    } else {
      await db.delete('work_likes',
          where: 'work_id = ? AND user_id = ?', whereArgs: [id, userId]);
    }
    await db.rawUpdate(
      'UPDATE our_works SET likes = (SELECT COUNT(*) FROM work_likes WHERE work_id = ?) '
      'WHERE id = ?',
      [id, id],
    );
  }

  @override
  Future<List<WorkComment>> workComments(
    int workId, {
    int? viewerId,
    bool isAdmin = false,
  }) async {
    final db = await _db;
    final rows = await db.rawQuery('''
      SELECT wc.*, u.avatar AS avatar,
        (SELECT COUNT(*) FROM work_comment_reactions r
          WHERE r.comment_id = wc.id AND r.reaction = 1) AS likes_count,
        (SELECT COUNT(*) FROM work_comment_reactions r
          WHERE r.comment_id = wc.id AND r.reaction = -1) AS dislikes_count,
        COALESCE((SELECT r.reaction FROM work_comment_reactions r
          WHERE r.comment_id = wc.id AND r.user_id = ?), 0) AS my_reaction,
        CASE WHEN ? = 1 THEN wc.admin_hearted ELSE 0 END AS admin_hearted
      FROM work_comments wc
      LEFT JOIN users u ON u.id = wc.user_id
      WHERE wc.work_id = ? ORDER BY wc.created_at ASC
    ''', [viewerId ?? -1, isAdmin ? 1 : 0, workId]);
    return rows.map(WorkComment.fromMap).toList();
  }

  @override
  Future<int> addWorkComment(WorkComment c) async {
    final db = await _db;
    return db.insert('work_comments', c.toMap());
  }

  @override
  Future<void> updateWorkComment(int id, {required String body}) async {
    final db = await _db;
    await db.update(
      'work_comments',
      {'body': body},
      where: 'id = ?',
      whereArgs: [id],
    );
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
    final db = await _db;
    if (reaction == 0) {
      await db.delete(
        'work_comment_reactions',
        where: 'comment_id = ? AND user_id = ?',
        whereArgs: [commentId, userId],
      );
      return;
    }
    await db.insert(
      'work_comment_reactions',
      {
        'comment_id': commentId,
        'user_id': userId,
        'reaction': reaction,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> setWorkCommentHeart(
    int commentId, {
    required bool hearted,
  }) async {
    final db = await _db;
    await db.update(
      'work_comments',
      {'admin_hearted': hearted ? 1 : 0},
      where: 'id = ?',
      whereArgs: [commentId],
    );
  }

  @override
  Future<int> workCount() async {
    final db = await _db;
    final r = await db.rawQuery('SELECT COUNT(*) c FROM our_works');
    return (r.first['c'] as int?) ?? 0;
  }

  // ------------------------------------------------------------- التوظيف
  @override
  Future<int> createHire(Hire h) async {
    final db = await _db;
    await db.delete('hires', where: 'phone = ?', whereArgs: [h.phone]);
    final id = await db.insert('hires', h.toMap());
    // أي حساب موجود بهذا الرقم (زبون) يُرقّى فوراً إلى (حرفي).
    await db.update('users', {'role': 'worker'},
        where: "phone = ? AND role = 'customer'", whereArgs: [h.phone]);
    return id;
  }

  @override
  Future<List<Hire>> listHires() async {
    final db = await _db;
    final rows = await db.rawQuery('''
      SELECT h.*, u.id AS user_id, u.name AS user_name
      FROM hires h
      LEFT JOIN users u ON u.phone = h.phone
      ORDER BY h.created_at DESC
    ''');
    return rows.map(Hire.fromMap).toList();
  }

  @override
  Future<bool> isHiredPhone(String phone) async {
    final db = await _db;
    final r = await db
        .rawQuery('SELECT COUNT(*) c FROM hires WHERE phone = ?', [phone]);
    return ((r.first['c'] as int?) ?? 0) > 0;
  }

  @override
  Future<void> deleteHire(int id) async {
    final db = await _db;
    final rows = await db.query('hires',
        columns: ['phone'], where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isNotEmpty) {
      final phone = rows.first['phone'] as String?;
      if (phone != null) {
        await db.update('users', {'role': 'customer'},
            where: "phone = ? AND role = 'worker'", whereArgs: [phone]);
      }
    }
    await db.delete('hires', where: 'id = ?', whereArgs: [id]);
  }

  // ------------------------------------------------------ طلبات الحرفيين
  @override
  Future<int> createApplication(CraftsmanApplication application) async {
    final db = await _db;
    return db.insert('craftsman_applications', application.toMap());
  }

  @override
  Future<List<CraftsmanApplication>> listApplications() async {
    final db = await _db;
    final rows =
        await db.query('craftsman_applications', orderBy: 'created_at DESC');
    return rows.map(CraftsmanApplication.fromMap).toList();
  }

  @override
  Future<bool> hasPendingApplication(String phone) async {
    final db = await _db;
    final r = await db.rawQuery(
      'SELECT COUNT(*) c FROM craftsman_applications WHERE phone = ? AND status = ?',
      [phone, CraftsmanApplication.pending],
    );
    return ((r.first['c'] as int?) ?? 0) > 0;
  }

  @override
  Future<void> acceptApplication(CraftsmanApplication application) async {
    final db = await _db;
    // القبول ينشئ ملف الحرفي في دليل المحافظة فوراً، إن لم يكن المدير أضافه سابقاً.
    final existing = await db.query(
      'workers',
      where: 'phone = ?',
      whereArgs: [normalizePhone(application.phone)],
      limit: 1,
    );
    if (existing.isEmpty) {
      await db.insert('workers', {
        'name': application.name,
        'phone': normalizePhone(application.phone),
        'specialty': application.trade,
        'city': application.city,
        'available': 1,
      });
    } else {
      final row = existing.first;
      final city = (row['city'] as String?)?.trim() ?? '';
      if (city.isEmpty) {
        await db.update(
          'workers',
          {'city': application.city},
          where: 'id = ?',
          whereArgs: [row['id']],
        );
      }
    }
    await createHire(
      Hire(
          phone: application.phone,
          note: application.trade,
          createdAt: DateTime.now()),
    );
    await _setApplicationStatus(application.id!, CraftsmanApplication.accepted);
  }

  @override
  Future<void> rejectApplication(int id) =>
      _setApplicationStatus(id, CraftsmanApplication.rejected);

  Future<void> _setApplicationStatus(int id, String status) async {
    final db = await _db;
    await db.update(
      'craftsman_applications',
      {'status': status},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ------------------------------------------------------------- messages
  @override
  Future<List<ChatMessage>> threadMessages(int customerId) async {
    final db = await _db;
    final rows = await db.query('messages',
        where: 'thread_id = ?',
        whereArgs: [customerId],
        orderBy: 'created_at ASC');
    return rows.map(ChatMessage.fromMap).toList();
  }

  @override
  Future<int> sendMessage(ChatMessage m) async {
    final db = await _db;
    return db.insert('messages', m.toMap());
  }

  @override
  Future<void> markThreadRead(int customerId,
      {required String readerRole}) async {
    final db = await _db;
    final other = readerRole == 'admin' ? 'customer' : 'admin';
    await db.update('messages', {'read': 1},
        where: 'thread_id = ? AND sender_role = ?',
        whereArgs: [customerId, other]);
  }

  @override
  Future<int> unreadForAdmin() async {
    final db = await _db;
    final r = await db.rawQuery(
        "SELECT COUNT(*) c FROM messages WHERE sender_role='customer' AND read=0");
    return (r.first['c'] as int?) ?? 0;
  }

  @override
  Future<int> unreadForCustomer(int customerId) async {
    final db = await _db;
    final r = await db.rawQuery(
        "SELECT COUNT(*) c FROM messages WHERE thread_id=? AND sender_role='admin' AND read=0",
        [customerId]);
    return (r.first['c'] as int?) ?? 0;
  }

  @override
  Future<List<ChatThread>> messageThreads() async {
    final db = await _db;
    final rows = await db.rawQuery('''
      SELECT m.thread_id, u.name AS customer_name, u.phone AS customer_phone,
        (SELECT body FROM messages m2 WHERE m2.thread_id = m.thread_id ORDER BY created_at DESC LIMIT 1) AS last_message,
        (SELECT created_at FROM messages m3 WHERE m3.thread_id = m.thread_id ORDER BY created_at DESC LIMIT 1) AS last_at,
        (SELECT COUNT(*) FROM messages m4 WHERE m4.thread_id = m.thread_id AND m4.sender_role='customer' AND m4.read=0) AS unread
      FROM messages m
      LEFT JOIN users u ON u.id = m.thread_id
      GROUP BY m.thread_id
      ORDER BY last_at DESC
    ''');
    return rows
        .map((r) => ChatThread(
              customerId: r['thread_id'] as int? ?? 0,
              customerName:
                  r['customer_name'] as String? ?? tr('زبون', 'Customer'),
              customerPhone: r['customer_phone'] as String? ?? '',
              lastMessage: r['last_message'] as String? ?? '',
              lastAt: DateTime.tryParse(r['last_at'] as String? ?? '') ??
                  DateTime.now(),
              unread: r['unread'] as int? ?? 0,
            ))
        .toList();
  }

  // ---------------------------------------------------------------- cards
  @override
  Future<List<PaymentCard>> cardsForUser(int userId) async {
    final db = await _db;
    final rows = await db.query('cards',
        where: 'user_id = ?',
        whereArgs: [userId],
        orderBy: 'is_default DESC, id DESC');
    return rows.map(PaymentCard.fromMap).toList();
  }

  @override
  Future<int> addCard(PaymentCard c) async {
    final db = await _db;
    if (c.isDefault) {
      await db.update('cards', {'is_default': 0},
          where: 'user_id = ?', whereArgs: [c.userId]);
    }
    return db.insert('cards', c.toMap());
  }

  @override
  Future<void> deleteCard(int id) async {
    final db = await _db;
    await db.delete('cards', where: 'id = ?', whereArgs: [id]);
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
    final db = await _db;
    final now = DateTime.now();
    final invoice = invoiceNumber(bookingId, now);
    return db.insert('receipts', {
      'invoice_no': invoice,
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

  static const _receiptSelect = '''
    SELECT r.*, b.worker_id AS worker_id, s.title AS service_title, w.name AS worker_name,
           u.name AS customer_name, u.phone AS customer_phone, u.city AS customer_city
    FROM receipts r
    LEFT JOIN bookings b ON b.id = r.booking_id
    LEFT JOIN services s ON s.id = b.service_id
    LEFT JOIN workers w ON w.id = b.worker_id
    LEFT JOIN users u ON u.id = r.user_id
  ''';

  @override
  Future<List<Receipt>> receiptsForUser(int userId) async {
    final db = await _db;
    final rows = await db.rawQuery(
        '$_receiptSelect WHERE r.user_id = ? ORDER BY r.created_at DESC',
        [userId]);
    return rows.map(Receipt.fromMap).toList();
  }

  @override
  Future<List<Receipt>> allReceipts() async {
    final db = await _db;
    final rows =
        await db.rawQuery('$_receiptSelect ORDER BY r.created_at DESC');
    return rows.map(Receipt.fromMap).toList();
  }

  @override
  Future<Receipt?> receiptById(int id) async {
    final db = await _db;
    final rows = await db.rawQuery('$_receiptSelect WHERE r.id = ?', [id]);
    return rows.isEmpty ? null : Receipt.fromMap(rows.first);
  }

  @override
  Future<Receipt?> receiptForBooking(int bookingId) async {
    final db = await _db;
    final rows = await db.rawQuery(
        '$_receiptSelect WHERE r.booking_id = ? LIMIT 1', [bookingId]);
    return rows.isEmpty ? null : Receipt.fromMap(rows.first);
  }

  @override
  Future<void> markReceiptPaid(int id, bool paid) async {
    final db = await _db;
    await db.update('receipts', {'paid': paid ? 1 : 0},
        where: 'id = ?', whereArgs: [id]);
  }

  // ------------------------------------------------------------- settings
  @override
  Future<String> getSetting(String key, {String fallback = ''}) async {
    final db = await _db;
    final rows = await db.query('settings',
        where: 'key = ?', whereArgs: [key], limit: 1);
    return rows.isEmpty ? fallback : rows.first['value'] as String;
  }

  @override
  Future<void> setSetting(String key, String value) async {
    final db = await _db;
    await db.insert('settings', {'key': key, 'value': value},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // ---------------------------------------------------------------- stats
  @override
  Future<AppStats> stats() async {
    final db = await _db;
    final today = await bookingsTodayCount();
    final pending = await pendingBookingsCount();
    final customers = await customerCount();
    final services = await serviceCount();
    final posts = await postCount();
    final unread = await unreadForAdmin();
    final receipts = await db.rawQuery(
        'SELECT COALESCE(SUM(amount),0) s FROM receipts WHERE paid=1');

    final since = DateTime.now().subtract(const Duration(days: 6));
    final rows = await db.rawQuery(
      "SELECT date(created_at) d, COALESCE(SUM(amount),0) s FROM receipts "
      "WHERE paid=1 AND date(created_at) >= date(?) GROUP BY date(created_at)",
      [since.toIso8601String()],
    );
    final map = {
      for (final r in rows) r['d'] as String: (r['s'] as num).toDouble()
    };
    final days = <RevenuePoint>[];
    for (var i = 6; i >= 0; i--) {
      final day = DateTime.now().subtract(Duration(days: i));
      final key =
          '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
      days.add(
          RevenuePoint(DateTime(day.year, day.month, day.day), map[key] ?? 0));
    }
    return AppStats(
      bookingsToday: today,
      revenue: (receipts.first['s'] as num?)?.toDouble() ?? 0,
      customers: customers,
      pending: pending,
      services: services,
      posts: posts,
      works: await workCount(),
      unreadMessages: unread,
      weekly: days,
    );
  }

  @override
  Future<void> resetDemoData() async {
    await _appDb.reset();
  }

  @override
  Future<void> close() async {}
}
