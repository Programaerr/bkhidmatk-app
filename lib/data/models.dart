/// يقرأ التاريخ من الخادم (UTC) ويحوّله إلى توقيت الجهاز.
DateTime? _date(Object? value) {
  if (value is! String || value.isEmpty) return null;
  return DateTime.tryParse(value)?.toLocal();
}

class AppUser {
  final int? id;
  final String name;
  final String phone;
  final String passwordHash;
  final String role; // customer | admin
  final String? email;
  final String? city;
  final String? address;
  final String? avatarPath;
  final DateTime createdAt;

  const AppUser({
    this.id,
    required this.name,
    required this.phone,
    required this.passwordHash,
    this.role = 'customer',
    this.email,
    this.city,
    this.address,
    this.avatarPath,
    required this.createdAt,
  });

  bool get isAdmin => role == 'admin';

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'phone': phone,
        'password': passwordHash,
        'role': role,
        'email': email,
        'city': city,
        'address': address,
        'avatar': avatarPath,
        'created_at': createdAt.toIso8601String(),
      };

  factory AppUser.fromMap(Map<String, Object?> m) => AppUser(
        id: m['id'] as int?,
        name: m['name'] as String? ?? '',
        phone: m['phone'] as String? ?? '',
        passwordHash: m['password'] as String? ?? '',
        role: m['role'] as String? ?? 'customer',
        email: m['email'] as String?,
        city: m['city'] as String?,
        address: m['address'] as String?,
        avatarPath: m['avatar'] as String?,
        createdAt: _date(m['created_at']) ?? DateTime.now(),
      );

  AppUser copyWith({
    String? name,
    String? phone,
    String? email,
    String? city,
    String? address,
    String? avatarPath,
  }) =>
      AppUser(
        id: id,
        name: name ?? this.name,
        phone: phone ?? this.phone,
        passwordHash: passwordHash,
        role: role,
        email: email ?? this.email,
        city: city ?? this.city,
        address: address ?? this.address,
        avatarPath: avatarPath ?? this.avatarPath,
        createdAt: createdAt,
      );
}

class Category {
  final int? id;
  final String name;
  final String icon; // Material icon key
  final int color;
  final int sortOrder;

  const Category({
    this.id,
    required this.name,
    required this.icon,
    required this.color,
    this.sortOrder = 0,
  });

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'icon': icon,
        'color': color,
        'sort_order': sortOrder,
      };

  factory Category.fromMap(Map<String, Object?> m) => Category(
        id: m['id'] as int?,
        name: m['name'] as String? ?? '',
        icon: m['icon'] as String? ?? 'build',
        color: m['color'] as int? ?? 0xFFFFD400,
        sortOrder: m['sort_order'] as int? ?? 0,
      );
}

class Worker {
  final int? id;
  final String name;
  final String phone;
  final String specialty;
  final int? categoryId;
  final double rating;
  final int jobsDone;
  final String? bio;
  final String? avatarPath;
  final bool available;

  const Worker({
    this.id,
    required this.name,
    required this.phone,
    required this.specialty,
    this.categoryId,
    this.rating = 4.8,
    this.jobsDone = 0,
    this.bio,
    this.avatarPath,
    this.available = true,
  });

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'phone': phone,
        'specialty': specialty,
        'category_id': categoryId,
        'rating': rating,
        'jobs_done': jobsDone,
        'bio': bio,
        'avatar': avatarPath,
        'available': available ? 1 : 0,
      };

  factory Worker.fromMap(Map<String, Object?> m) => Worker(
        id: m['id'] as int?,
        name: m['name'] as String? ?? '',
        phone: m['phone'] as String? ?? '',
        specialty: m['specialty'] as String? ?? '',
        categoryId: m['category_id'] as int?,
        rating: (m['rating'] as num?)?.toDouble() ?? 0,
        jobsDone: m['jobs_done'] as int? ?? 0,
        bio: m['bio'] as String?,
        avatarPath: m['avatar'] as String?,
        available: (m['available'] as int? ?? 1) == 1,
      );
}

class Service {
  final int? id;
  final int categoryId;
  final int? workerId;
  final String title;
  final String description;
  final double price;
  final int durationMinutes;
  final double rating;
  final bool active;
  final DateTime createdAt;

  // joined display fields
  final String? categoryName;
  final String? workerName;
  final String? workerPhone;
  final int? categoryColor;
  final String? categoryIcon;

  const Service({
    this.id,
    required this.categoryId,
    this.workerId,
    required this.title,
    required this.description,
    required this.price,
    this.durationMinutes = 60,
    this.rating = 4.8,
    this.active = true,
    required this.createdAt,
    this.categoryName,
    this.workerName,
    this.workerPhone,
    this.categoryColor,
    this.categoryIcon,
  });

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'category_id': categoryId,
        'worker_id': workerId,
        'title': title,
        'description': description,
        'price': price,
        'duration': durationMinutes,
        'rating': rating,
        'active': active ? 1 : 0,
        'created_at': createdAt.toIso8601String(),
      };

  factory Service.fromMap(Map<String, Object?> m) => Service(
        id: m['id'] as int?,
        categoryId: m['category_id'] as int? ?? 0,
        workerId: m['worker_id'] as int?,
        title: m['title'] as String? ?? '',
        description: m['description'] as String? ?? '',
        price: (m['price'] as num?)?.toDouble() ?? 0,
        durationMinutes: m['duration'] as int? ?? 60,
        rating: (m['rating'] as num?)?.toDouble() ?? 0,
        active: (m['active'] as int? ?? 1) == 1,
        createdAt: _date(m['created_at']) ?? DateTime.now(),
        categoryName: m['category_name'] as String?,
        workerName: m['worker_name'] as String?,
        workerPhone: m['worker_phone'] as String?,
        categoryColor: m['category_color'] as int?,
        categoryIcon: m['category_icon'] as String?,
      );

  Service copyWith({String? workerName, String? workerPhone}) => Service(
        id: id,
        categoryId: categoryId,
        workerId: workerId,
        title: title,
        description: description,
        price: price,
        durationMinutes: durationMinutes,
        rating: rating,
        active: active,
        createdAt: createdAt,
        categoryName: categoryName,
        workerName: workerName ?? this.workerName,
        workerPhone: workerPhone ?? this.workerPhone,
        categoryColor: categoryColor,
        categoryIcon: categoryIcon,
      );
}

class Booking {
  final int? id;
  final int customerId;
  final int serviceId;
  final int? workerId;
  final DateTime scheduledAt;
  final String slot;
  final String address;
  final String? notes;
  final String status; // pending, confirmed, in_progress, completed, cancelled
  final String paymentMethod; // cash, card
  final double total;
  final DateTime createdAt;

  final String? serviceTitle;
  final String? workerName;
  final String? workerPhone;
  final String? customerName;
  final String? customerPhone;

  const Booking({
    this.id,
    required this.customerId,
    required this.serviceId,
    this.workerId,
    required this.scheduledAt,
    required this.slot,
    required this.address,
    this.notes,
    this.status = 'pending',
    this.paymentMethod = 'cash',
    required this.total,
    required this.createdAt,
    this.serviceTitle,
    this.workerName,
    this.workerPhone,
    this.customerName,
    this.customerPhone,
  });

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'customer_id': customerId,
        'service_id': serviceId,
        'worker_id': workerId,
        'scheduled_at': scheduledAt.toIso8601String(),
        'slot': slot,
        'address': address,
        'notes': notes,
        'status': status,
        'payment_method': paymentMethod,
        'total': total,
        'created_at': createdAt.toIso8601String(),
      };

  factory Booking.fromMap(Map<String, Object?> m) => Booking(
        id: m['id'] as int?,
        customerId: m['customer_id'] as int? ?? 0,
        serviceId: m['service_id'] as int? ?? 0,
        workerId: m['worker_id'] as int?,
        scheduledAt: _date(m['scheduled_at']) ?? DateTime.now(),
        slot: m['slot'] as String? ?? '09:00',
        address: m['address'] as String? ?? '',
        notes: m['notes'] as String?,
        status: m['status'] as String? ?? 'pending',
        paymentMethod: m['payment_method'] as String? ?? 'cash',
        total: (m['total'] as num?)?.toDouble() ?? 0,
        createdAt: _date(m['created_at']) ?? DateTime.now(),
        serviceTitle: m['service_title'] as String?,
        workerName: m['worker_name'] as String?,
        workerPhone: m['worker_phone'] as String?,
        customerName: m['customer_name'] as String?,
        customerPhone: m['customer_phone'] as String?,
      );

  Booking copyWith({String? status, int? workerId, String? workerName}) => Booking(
        id: id,
        customerId: customerId,
        serviceId: serviceId,
        workerId: workerId ?? this.workerId,
        scheduledAt: scheduledAt,
        slot: slot,
        address: address,
        notes: notes,
        status: status ?? this.status,
        paymentMethod: paymentMethod,
        total: total,
        createdAt: createdAt,
        serviceTitle: serviceTitle,
        workerName: workerName ?? this.workerName,
        workerPhone: workerPhone,
        customerName: customerName,
        customerPhone: customerPhone,
      );
}

class BookingStatus {
  static const pending = 'pending';
  static const confirmed = 'confirmed';
  static const inProgress = 'in_progress';
  static const completed = 'completed';
  static const cancelled = 'cancelled';

  static const all = [pending, confirmed, inProgress, completed, cancelled];

  static String label(String s) => switch (s) {
        pending => 'بانتظار التأكيد',
        confirmed => 'تم التأكيد',
        inProgress => 'قيد التنفيذ',
        completed => 'مكتمل',
        cancelled => 'ملغي',
        _ => s,
      };
}

class Post {
  final int? id;
  final int customerId;
  final int categoryId;
  final String title;
  final String description;
  final double price;
  final String? mediaPath;
  final String mediaType; // image | video | none
  final String? location;
  final bool approved;
  final int likes;
  final DateTime createdAt;

  final String? customerName;
  final String? customerPhone;
  final String? categoryName;
  final int commentCount;

  const Post({
    this.id,
    required this.customerId,
    required this.categoryId,
    required this.title,
    required this.description,
    required this.price,
    this.mediaPath,
    this.mediaType = 'none',
    this.location,
    this.approved = true,
    this.likes = 0,
    required this.createdAt,
    this.customerName,
    this.customerPhone,
    this.categoryName,
    this.commentCount = 0,
  });

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'customer_id': customerId,
        'category_id': categoryId,
        'title': title,
        'description': description,
        'price': price,
        'media': mediaPath,
        'media_type': mediaType,
        'location': location,
        'approved': approved ? 1 : 0,
        'likes': likes,
        'created_at': createdAt.toIso8601String(),
      };

  factory Post.fromMap(Map<String, Object?> m) => Post(
        id: m['id'] as int?,
        customerId: m['customer_id'] as int? ?? 0,
        categoryId: m['category_id'] as int? ?? 0,
        title: m['title'] as String? ?? '',
        description: m['description'] as String? ?? '',
        price: (m['price'] as num?)?.toDouble() ?? 0,
        mediaPath: m['media'] as String?,
        mediaType: m['media_type'] as String? ?? 'none',
        location: m['location'] as String?,
        approved: (m['approved'] as int? ?? 1) == 1,
        likes: m['likes'] as int? ?? 0,
        createdAt: _date(m['created_at']) ?? DateTime.now(),
        customerName: m['customer_name'] as String?,
        customerPhone: m['customer_phone'] as String?,
        categoryName: m['category_name'] as String?,
        commentCount: m['comment_count'] as int? ?? 0,
      );
}

class PostComment {
  final int? id;
  final int postId;
  final int userId;
  final String userName;
  final String body;
  final DateTime createdAt;
  final String? avatarPath;

  const PostComment({
    this.id,
    required this.postId,
    required this.userId,
    required this.userName,
    required this.body,
    required this.createdAt,
    this.avatarPath,
  });

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'post_id': postId,
        'user_id': userId,
        'user_name': userName,
        'body': body,
        'created_at': createdAt.toIso8601String(),
      };

  factory PostComment.fromMap(Map<String, Object?> m) => PostComment(
        id: m['id'] as int?,
        postId: m['post_id'] as int? ?? 0,
        userId: m['user_id'] as int? ?? 0,
        userName: m['user_name'] as String? ?? '',
        body: m['body'] as String? ?? '',
        createdAt: _date(m['created_at']) ?? DateTime.now(),
        avatarPath: m['avatar'] as String?,
      );
}

class ChatMessage {
  final int? id;
  final int threadId; // customer id
  final int senderId;
  final String senderRole; // customer | admin
  final String body;
  final DateTime createdAt;
  final bool read;

  const ChatMessage({
    this.id,
    required this.threadId,
    required this.senderId,
    required this.senderRole,
    required this.body,
    required this.createdAt,
    this.read = false,
  });

  bool get fromAdmin => senderRole == 'admin';

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'thread_id': threadId,
        'sender_id': senderId,
        'sender_role': senderRole,
        'body': body,
        'created_at': createdAt.toIso8601String(),
        'read': read ? 1 : 0,
      };

  factory ChatMessage.fromMap(Map<String, Object?> m) => ChatMessage(
        id: m['id'] as int?,
        threadId: m['thread_id'] as int? ?? 0,
        senderId: m['sender_id'] as int? ?? 0,
        senderRole: m['sender_role'] as String? ?? 'customer',
        body: m['body'] as String? ?? '',
        createdAt: _date(m['created_at']) ?? DateTime.now(),
        read: (m['read'] as int? ?? 0) == 1,
      );
}

class PaymentCard {
  final int? id;
  final int userId;
  final String brand;
  final String last4;
  final String holder;
  final String expiry;
  final bool isDefault;

  const PaymentCard({
    this.id,
    required this.userId,
    required this.brand,
    required this.last4,
    required this.holder,
    required this.expiry,
    this.isDefault = false,
  });

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'user_id': userId,
        'brand': brand,
        'last4': last4,
        'holder': holder,
        'expiry': expiry,
        'is_default': isDefault ? 1 : 0,
      };

  factory PaymentCard.fromMap(Map<String, Object?> m) => PaymentCard(
        id: m['id'] as int?,
        userId: m['user_id'] as int? ?? 0,
        brand: m['brand'] as String? ?? 'Card',
        last4: m['last4'] as String? ?? '0000',
        holder: m['holder'] as String? ?? '',
        expiry: m['expiry'] as String? ?? '',
        isDefault: (m['is_default'] as int? ?? 0) == 1,
      );
}

class Receipt {
  final int? id;
  final String invoiceNo;
  final int? bookingId;
  final int userId;
  final String title;
  final String? serviceTitle;
  final String? workerName;
  final double amount;
  final String method; // cash, card
  final String? cardBrand;
  final String? last4;
  final bool paid;
  final DateTime createdAt;

  final String? customerName;
  final String? customerPhone;

  const Receipt({
    this.id,
    required this.invoiceNo,
    this.bookingId,
    required this.userId,
    required this.title,
    this.serviceTitle,
    this.workerName,
    required this.amount,
    required this.method,
    this.cardBrand,
    this.last4,
    this.paid = false,
    required this.createdAt,
    this.customerName,
    this.customerPhone,
  });

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'invoice_no': invoiceNo,
        'booking_id': bookingId,
        'user_id': userId,
        'title': title,
        'amount': amount,
        'method': method,
        'card_brand': cardBrand,
        'last4': last4,
        'paid': paid ? 1 : 0,
        'created_at': createdAt.toIso8601String(),
      };

  factory Receipt.fromMap(Map<String, Object?> m) => Receipt(
        id: m['id'] as int?,
        invoiceNo: m['invoice_no'] as String? ?? '',
        bookingId: m['booking_id'] as int?,
        userId: m['user_id'] as int? ?? 0,
        title: m['title'] as String? ?? 'وصل خدمة',
        serviceTitle: m['service_title'] as String?,
        workerName: m['worker_name'] as String?,
        amount: (m['amount'] as num?)?.toDouble() ?? 0,
        method: m['method'] as String? ?? 'cash',
        cardBrand: m['card_brand'] as String?,
        last4: m['last4'] as String?,
        paid: (m['paid'] as int? ?? 0) == 1,
        createdAt: _date(m['created_at']) ?? DateTime.now(),
        customerName: m['customer_name'] as String?,
        customerPhone: m['customer_phone'] as String?,
      );
}

class ChatThread {
  final int customerId;
  final String customerName;
  final String customerPhone;
  final String lastMessage;
  final DateTime lastAt;
  final int unread;

  const ChatThread({
    required this.customerId,
    required this.customerName,
    required this.customerPhone,
    required this.lastMessage,
    required this.lastAt,
    required this.unread,
  });
}

class AppStats {
  final int bookingsToday;
  final double revenue;
  final int customers;
  final int pending;
  final int services;
  final int posts;
  final int unreadMessages;
  final List<RevenuePoint> weekly;

  const AppStats({
    this.bookingsToday = 0,
    this.revenue = 0,
    this.customers = 0,
    this.pending = 0,
    this.services = 0,
    this.posts = 0,
    this.unreadMessages = 0,
    this.weekly = const [],
  });
}

class RevenuePoint {
  final DateTime day;
  final double value;
  const RevenuePoint(this.day, this.value);
}
