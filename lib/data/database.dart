import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

String hashPassword(String password, {String salt = 'bkhidmatk_v1'}) =>
    sha256.convert(utf8.encode('$salt::$password')).toString();

class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  Database? _db;
  static const _fileName = 'bkhidmatk.db';
  static const _version = 3;

  Future<Database> get database async {
    if (_db != null && _db!.isOpen) return _db!;
    final dir = await getDatabasesPath();
    final path = p.join(dir, _fileName);
    _db = await openDatabase(
      path,
      version: _version,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        await _createSchema(db);
        await _seed(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) await _migrateToV2(db);
        if (oldVersion < 3) await _migrateToV3(db);
      },
    );
    return _db!;
  }

  /// v2: نظام النقاط — أعمدة `points` للمستخدم و`rating`/`review` للحجز.
  Future<void> _migrateToV2(Database db) async {
    await db.execute(
        "ALTER TABLE users ADD COLUMN points INTEGER NOT NULL DEFAULT 0");
    await db.execute('ALTER TABLE bookings ADD COLUMN rating INTEGER');
    await db.execute('ALTER TABLE bookings ADD COLUMN review TEXT');
  }

  /// v3: قسم «أعمالنا» (فيديوهات المدير) وشاشة «التوظيف» بالرقم.
  Future<void> _migrateToV3(Database db) async {
    await db.execute(_worksSchema);
    await db.execute(_workCommentsSchema);
    await db.execute(_workLikesSchema);
    await db.execute(_hiresSchema);
  }

  Future<void> reset() async {
    final dir = await getDatabasesPath();
    final path = p.join(dir, _fileName);
    if (_db != null) {
      await _db!.close();
      _db = null;
    }
    if (await File(path).exists()) {
      await deleteDatabase(path);
    }
    await database;
  }

  // ---------------------------------------------------- مخطط قسم «أعمالنا»
  // يُستخدم عند الإنشاء الجديد وعند ترقية قاعدة البيانات القديمة معاً.
  static const _worksSchema = '''
    CREATE TABLE IF NOT EXISTS our_works(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      title TEXT NOT NULL,
      description TEXT,
      video_url TEXT NOT NULL,
      active INTEGER NOT NULL DEFAULT 1,
      views INTEGER NOT NULL DEFAULT 0,
      likes INTEGER NOT NULL DEFAULT 0,
      created_at TEXT NOT NULL
    )
  ''';

  static const _workCommentsSchema = '''
    CREATE TABLE IF NOT EXISTS work_comments(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      work_id INTEGER NOT NULL,
      user_id INTEGER NOT NULL,
      user_name TEXT NOT NULL,
      body TEXT NOT NULL,
      created_at TEXT NOT NULL
    )
  ''';

  static const _workLikesSchema = '''
    CREATE TABLE IF NOT EXISTS work_likes(
      work_id INTEGER NOT NULL,
      user_id INTEGER NOT NULL,
      PRIMARY KEY (work_id, user_id)
    )
  ''';

  static const _hiresSchema = '''
    CREATE TABLE IF NOT EXISTS hires(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      phone TEXT NOT NULL UNIQUE,
      note TEXT,
      created_at TEXT NOT NULL
    )
  ''';

  Future<void> _createSchema(Database db) async {
    await db.execute('''
      CREATE TABLE users(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        phone TEXT NOT NULL UNIQUE,
        password TEXT NOT NULL,
        role TEXT NOT NULL DEFAULT 'customer',
        email TEXT,
        city TEXT,
        address TEXT,
        avatar TEXT,
        points INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE categories(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        icon TEXT NOT NULL,
        color INTEGER NOT NULL,
        sort_order INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE workers(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        phone TEXT NOT NULL,
        specialty TEXT NOT NULL,
        category_id INTEGER,
        rating REAL NOT NULL DEFAULT 4.8,
        jobs_done INTEGER NOT NULL DEFAULT 0,
        bio TEXT,
        avatar TEXT,
        available INTEGER NOT NULL DEFAULT 1
      )
    ''');
    await db.execute('''
      CREATE TABLE services(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        category_id INTEGER NOT NULL,
        worker_id INTEGER,
        title TEXT NOT NULL,
        description TEXT NOT NULL,
        price REAL NOT NULL,
        duration INTEGER NOT NULL DEFAULT 60,
        rating REAL NOT NULL DEFAULT 4.8,
        active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE bookings(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        customer_id INTEGER NOT NULL,
        service_id INTEGER NOT NULL,
        worker_id INTEGER,
        scheduled_at TEXT NOT NULL,
        slot TEXT NOT NULL,
        address TEXT NOT NULL,
        notes TEXT,
        status TEXT NOT NULL DEFAULT 'pending',
        payment_method TEXT NOT NULL DEFAULT 'cash',
        total REAL NOT NULL,
        rating INTEGER,
        review TEXT,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE posts(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        customer_id INTEGER NOT NULL,
        category_id INTEGER NOT NULL,
        title TEXT NOT NULL,
        description TEXT NOT NULL,
        price REAL NOT NULL,
        media TEXT,
        media_type TEXT NOT NULL DEFAULT 'none',
        location TEXT,
        approved INTEGER NOT NULL DEFAULT 1,
        likes INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE comments(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        post_id INTEGER NOT NULL,
        user_id INTEGER NOT NULL,
        user_name TEXT NOT NULL,
        body TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute(_worksSchema);
    await db.execute(_workCommentsSchema);
    await db.execute(_workLikesSchema);
    await db.execute(_hiresSchema);
    await db.execute('''
      CREATE TABLE messages(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        thread_id INTEGER NOT NULL,
        sender_id INTEGER NOT NULL,
        sender_role TEXT NOT NULL,
        body TEXT NOT NULL,
        created_at TEXT NOT NULL,
        read INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE cards(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        brand TEXT NOT NULL,
        last4 TEXT NOT NULL,
        holder TEXT NOT NULL,
        expiry TEXT NOT NULL,
        is_default INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE receipts(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        invoice_no TEXT NOT NULL,
        booking_id INTEGER,
        user_id INTEGER NOT NULL,
        title TEXT NOT NULL,
        amount REAL NOT NULL,
        method TEXT NOT NULL,
        card_brand TEXT,
        last4 TEXT,
        paid INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE settings(
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
  }

  Future<void> _seed(Database db) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    Future<int> category(String name, String icon, int color, int sort) =>
        db.insert('categories', {
          'name': name,
          'icon': icon,
          'color': color,
          'sort_order': sort,
        });

    final cElectric = await category('كهرباء', 'electrical_services', 0xFFFFC107, 0);
    final cWasher = await category('تصليح غسالات', 'local_laundry_service', 0xFF03A9F4, 1);
    final cPaint = await category('صباغة', 'format_paint', 0xFF8BC34A, 2);
    final cDecor = await category('ديكورات', 'chair_alt', 0xFFE91E63, 3);
    final cPlumb = await category('سباكة', 'plumbing', 0xFF00BCD4, 4);
    final cAc = await category('تكييف', 'ac_unit', 0xFF3F51B5, 5);
    final cClean = await category('تنظيف', 'cleaning_services', 0xFF9C27B0, 6);
    final cCarp = await category('نجارة', 'carpenter', 0xFF795548, 7);

    Future<int> worker(
      String name,
      String phone,
      String specialty,
      int catId,
      double rating,
      int jobs,
      String bio, {
      bool available = true,
    }) =>
        db.insert('workers', {
          'name': name,
          'phone': phone,
          'specialty': specialty,
          'category_id': catId,
          'rating': rating,
          'jobs_done': jobs,
          'bio': bio,
          'available': available ? 1 : 0,
        });

    final wElectric = await worker('أحمد الجبوري', '07701112233', 'كهربائي منازل', cElectric,
        4.9, 312, 'خبرة 12 سنة في تأسيس وصيانة الكهرباء المنزلية.');
    final wWasher = await worker('مصطفى كريم', '07802223344', 'فني غسالات', cWasher,
        4.8, 205, 'صيانة جميع أنواع الغسالات الأوتوماتيك والنشافات.');
    final wPaint = await worker('علي حسين', '07903334455', 'صباغ محترف', cPaint,
        4.7, 148, 'دهانات حديثة وديكورات جدارية بأجود المواد.');
    final wDecor = await worker('يوسف العبيدي', '07714445566', 'فني ديكور', cDecor,
        4.9, 97, 'جبس بورد وأسقف ثانوية وتصاميم عصرية.');
    final wPlumb = await worker('حيدر الموسوي', '07825556677', 'سباك', cPlumb,
        4.6, 263, 'تسليك مجاري وإصلاح تسريبات المياه.');
    final wAc = await worker('سيف الدين عباس', '07936667788', 'فني تكييف', cAc,
        4.8, 174, 'تركيب وصيانة وشحن مكيفات سبليت ومركزي.');
    final wClean = await worker('نور الهدى سالم', '07747778899', 'فريق تنظيف', cClean,
        4.9, 321, 'تنظيف منازل وشركات بعمالة مدربة ومواد آمنة.');
    final wCarp = await worker('كرار عبد الله', '07858889900', 'نجار موبيليا', cCarp,
        4.7, 132, 'تصليح وتفصيل أبواب وخزائن ومطابخ.');

    Future<void> service(
      int catId,
      int workerId,
      String title,
      String desc,
      double price,
      int minutes,
      double rating, {
      bool active = true,
      int daysAgo = 30,
    }) =>
        db.insert('services', {
          'category_id': catId,
          'worker_id': workerId,
          'title': title,
          'description': desc,
          'price': price,
          'duration': minutes,
          'rating': rating,
          'active': active ? 1 : 0,
          'created_at': today.subtract(Duration(days: daysAgo)).toIso8601String(),
        });

    await service(cElectric, wElectric, 'تصليح أعطال كهربائية منزلية',
        'فحص كامل للتمديدات وإصلاح الأعطال والمفاتيح والمقابس مع ضمان على العمل.', 25000, 90, 4.9);
    await service(cElectric, wElectric, 'تركيب ثريات وإضاءة LED',
        'تركيب وتثبيت الثريات وشرائط الإضاءة مع تنظيم الأسلاك بشكل آمن.', 15000, 60, 4.8, daysAgo: 25);
    await service(cWasher, wWasher, 'صيانة غسالة أوتوماتيك',
        'فحص وتصليح أعطال الغسالة: تصريف، دوران، لوحة تحكم، مع قطع غيار أصلية.', 30000, 90, 4.8);
    await service(cWasher, wWasher, 'تصليح نشافة ملابس',
        'إصلاح أعطال التسخين والدوران وتنظيف مجرى الهواء.', 25000, 75, 4.7, daysAgo: 20);
    await service(cPaint, wPaint, 'صبغ غرفة كاملة',
        'تحضير الجدران ومعجون ودهان وجهين مع تشطيب نظيف، السعر يشمل المواد.', 150000, 480, 4.8);
    await service(cPaint, wPaint, 'دهان واجهة بناية',
        'تنظيف الواجهة ودهان مقاوم للعوامل الجوية بضمان 3 سنوات.', 250000, 600, 4.7, daysAgo: 15);
    await service(cDecor, wDecor, 'تركيب جبس بورد وأسقف ثانوية',
        'تصميم وتنفيذ أسقف جبس مع إضاءة مخفية وتشطيب احترافي.', 120000, 300, 4.9);
    await service(cDecor, wDecor, 'تركيب ورق جدران',
        'توريد وتركيب ورق جدران عالي الجودة لجميع الغرف.', 60000, 180, 4.6, daysAgo: 12);
    await service(cPlumb, wPlumb, 'تسليك مجاري',
        'فتح الانسدادات وإزالة الترسبات بأجهزة حديثة دون تكسير.', 35000, 60, 4.7);
    await service(cPlumb, wPlumb, 'إصلاح تسريب مياه',
        'كشف التسريبات وإصلاح الأنابيب والخلاطات مع ضمان.', 20000, 45, 4.8, daysAgo: 10);
    await service(cAc, wAc, 'تنظيف مكيف سبليت',
        'غسيل كامل للوحدة الداخلية والخارجية وتعقيم الفلاتر.', 20000, 60, 4.9);
    await service(cAc, wAc, 'شحن غاز مكيف',
        'فحص الضغط وشحن غاز الـ R410 مع كشف التسريبات.', 40000, 75, 4.8, daysAgo: 9);
    await service(cClean, wClean, 'تنظيف منزل شامل',
        'تنظيف الغرف والمطبخ والحمامات بعمالة مدربة ومواد صديقة للبيئة.', 75000, 240, 4.9);
    await service(cClean, wClean, 'غسيل سيارة داخل وخارج',
        'غسيل احترافي مع تلميع داخلي وتنظيف المحرك.', 15000, 90, 4.8, daysAgo: 8);
    await service(cCarp, wCarp, 'تصليح أبواب وخزائن',
        'إصلاح المفصلات والأقفال وتعديل الأبواب الخشبية.', 40000, 120, 4.7, daysAgo: 7);
    await service(cCarp, wCarp, 'تفصيل وتركيب مطبخ',
        'تصميم وتنفيذ مطبخ حسب المساحة مع خامات مقاومة للرطوبة.', 300000, 720, 4.6,
        daysAgo: 6);

    final adminId = await db.insert('users', {
      'name': 'مدير جايك',
      'phone': '07700000000',
      'password': hashPassword('admin123'),
      'role': 'admin',
      'email': 'admin@bkhidmatk.iq',
      'city': 'بغداد',
      'address': 'بغداد - الكرادة',
      'created_at': today.subtract(const Duration(days: 120)).toIso8601String(),
    });

    final customerId = await db.insert('users', {
      'name': 'أحمد سعد',
      'phone': '07701234567',
      'password': hashPassword('123456'),
      'role': 'customer',
      'city': 'بغداد',
      'address': 'بغداد - حي الجامعة، شارع 20',
      'points': 100,
      'created_at': today.subtract(const Duration(days: 60)).toIso8601String(),
    });

    final customer2 = await db.insert('users', {
      'name': 'زينب حسن',
      'phone': '07712345678',
      'password': hashPassword('123456'),
      'role': 'customer',
      'city': 'البصرة',
      'address': 'البصرة - العشار',
      'created_at': today.subtract(const Duration(days: 35)).toIso8601String(),
    });

    await db.insert('users', {
      'name': 'مهند عبد الرزاق',
      'phone': '07811112222',
      'password': hashPassword('123456'),
      'role': 'customer',
      'city': 'أربيل',
      'address': 'أربيل - عنكاوا',
      'created_at': today.subtract(const Duration(days: 12)).toIso8601String(),
    });

    Future<int> booking(
      int userId,
      int serviceId,
      int workerId,
      int daysFromNow,
      String slot,
      String status,
      String method,
      double total,
      String address,
    ) =>
        db.insert('bookings', {
          'customer_id': userId,
          'service_id': serviceId,
          'worker_id': workerId,
          'scheduled_at': today.add(Duration(days: daysFromNow)).toIso8601String(),
          'slot': slot,
          'address': address,
          'status': status,
          'payment_method': method,
          'total': total,
          'created_at': today.subtract(const Duration(days: 2)).toIso8601String(),
        });

    final b1 = await booking(customerId, 1, wElectric, 0, '10:00', 'completed', 'card', 25000,
        'بغداد - حي الجامعة، شارع 20');
    await booking(customerId, 3, wWasher, 1, '12:00', 'pending', 'cash', 30000,
        'بغداد - حي الجامعة، شارع 20');
    await booking(customerId, 5, wPaint, 4, '09:00', 'confirmed', 'cash', 150000,
        'بغداد - حي الجامعة، شارع 20');
    await booking(customerId, 14, wClean, -3, '16:00', 'completed', 'card', 15000,
        'بغداد - حي الجامعة، شارع 20');
    await booking(customer2, 11, wAc, 2, '11:00', 'confirmed', 'card',
        20000, 'البصرة - العشار');
    await booking(customer2, 9, wPlumb, -1, '14:00', 'completed', 'cash', 35000,
        'البصرة - العشار');

    await db.insert('receipts', {
      'invoice_no': 'BKD-${today.year}-00001',
      'booking_id': b1,
      'user_id': customerId,
      'title': 'وصل دفع خدمة',
      'amount': 25000,
      'method': 'card',
      'card_brand': 'Mastercard',
      'last4': '4821',
      'paid': 1,
      'created_at': today.toIso8601String(),
    });
    await db.insert('receipts', {
      'invoice_no': 'BKD-${today.year}-00002',
      'booking_id': null,
      'user_id': customerId,
      'title': 'وصل دفع خدمة',
      'amount': 15000,
      'method': 'card',
      'card_brand': 'Mastercard',
      'last4': '4821',
      'paid': 1,
      'created_at': today.subtract(const Duration(days: 3)).toIso8601String(),
    });
    await db.insert('receipts', {
      'invoice_no': 'BKD-${today.year}-00003',
      'booking_id': null,
      'user_id': customer2,
      'title': 'وصل دفع خدمة',
      'amount': 35000,
      'method': 'cash',
      'paid': 1,
      'created_at': today.subtract(const Duration(days: 1)).toIso8601String(),
    });

    Future<int> post(
      int userId,
      int catId,
      String title,
      String desc,
      double price,
      String? media,
      String type,
      String location,
      String createdAgo,
      int likes,
    ) =>
        db.insert('posts', {
          'customer_id': userId,
          'category_id': catId,
          'title': title,
          'description': desc,
          'price': price,
          'media': media,
          'media_type': type,
          'location': location,
          'approved': 1,
          'likes': likes,
          'created_at': createdAgo,
        });

    final p1 = await post(
      customerId,
      cElectric,
      'تصليح لوحة كهرباء كاملة في يوم واحد',
      'استبدلت القواطع وتنظيم الأسلاك لبيت في حي الجامعة. الشغل نظيف والمواد أصلية، والفيديو يوضح النتيجة النهائية.',
      45000,
      'asset:assets/media/work_electric.jpg',
      'image',
      'بغداد - حي الجامعة',
      DateTime.now().subtract(const Duration(hours: 5)).toIso8601String(),
      34,
    );
    await post(
      customer2,
      cClean,
      'غسيل سيارة داخل وخارج',
      'خدمة غسيل متنقلة، نجي لعندك بالبصرة. شغل مرتب ومواد تلميع أصلية.',
      15000,
      'asset:assets/media/work_car.jpg',
      'image',
      'البصرة - العشار',
      DateTime.now().subtract(const Duration(hours: 20)).toIso8601String(),
      21,
    );
    final p3 = await post(
      customerId,
      cPaint,
      'صبغ غرفة نوم بلمسة ديكورية',
      'دهان وجهين مع خط ذهبي على الجدار الرئيسي. المدة يومان فقط.',
      120000,
      'asset:assets/media/work_paint.jpg',
      'image',
      'بغداد - زيونة',
      DateTime.now().subtract(const Duration(days: 2)).toIso8601String(),
      57,
    );
    await post(
      customer2,
      cAc,
      'صيانة وشحن مكيف سبليت',
      'تنظيف كامل + شحن غاز + فحص تسريبات. اشتغل المكيف مثل الجديد.',
      30000,
      'asset:assets/media/work_ac.jpg',
      'image',
      'البصرة - الجزائر',
      DateTime.now().subtract(const Duration(days: 3)).toIso8601String(),
      18,
    );

    await db.insert('comments', {
      'post_id': p1,
      'user_id': customer2,
      'user_name': 'زينب حسن',
      'body': 'شغل مرتب ما شاء الله، ممكن رقمك؟',
      'created_at': DateTime.now().subtract(const Duration(hours: 3)).toIso8601String(),
    });
    await db.insert('comments', {
      'post_id': p1,
      'user_id': adminId,
      'user_name': 'مدير جايك',
      'body': 'تم توثيق العمل بنجاح ✅ شكراً لمشاركتك.',
      'created_at': DateTime.now().subtract(const Duration(hours: 2)).toIso8601String(),
    });
    await db.insert('comments', {
      'post_id': p3,
      'user_id': customer2,
      'user_name': 'زينب حسن',
      'body': 'اللون يجنن، أي نوع صبغ استخدمت؟',
      'created_at': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
    });

    Future<void> msg(int thread, int sender, String role, String body, int hoursAgo,
            {bool read = true}) =>
        db.insert('messages', {
          'thread_id': thread,
          'sender_id': sender,
          'sender_role': role,
          'body': body,
          'created_at': DateTime.now().subtract(Duration(hours: hoursAgo)).toIso8601String(),
          'read': read ? 1 : 0,
        });

    await msg(customerId, customerId, 'customer',
        'مرحباً، حجزت صيانة غسالة أوتوماتيك وبغيت أتأكد من الوقت.', 26);
    await msg(customerId, adminId, 'admin',
        'أهلاً بك أستاذ أحمد 👋 تم استلام حجزك، الفني مصطفى سيتواصل معك قبل الموعد بنصف ساعة.', 25);
    await msg(customerId, customerId, 'customer', 'ممتاز، شكراً لكم.', 24);
    await msg(customerId, adminId, 'admin',
        'خدمتك تسعدنا دائماً. أي استفسار آخر نحن هنا.', 23);
    await msg(customer2, customer2, 'customer',
        'هل يوجد غسيل سيارات اليوم في العصر؟', 4, read: false);

    for (final entry in {
      'admin_phone': '07700000000',
      'support_hours': '9:00 ص - 10:00 م',
      'app_commission': '0',
      'currency': 'IQD',
      'card_test_mode': '1',
      'app_version': '1.0.0',
    }.entries) {
      await db.insert('settings', {'key': entry.key, 'value': entry.value});
    }
  }
}
