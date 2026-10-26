import 'models.dart';

/// واجهة البيانات الموحّدة للتطبيق.
///
/// يوجد تنفيذان:
/// * [LocalRepository] — SQLite على الجهاز (وضع تجريبي بدون إنترنت).
/// * `CloudRepository` — Supabase (قاعدة بيانات مشتركة بين كل المستخدمين).
///
/// كل شاشات التطبيق تتعامل مع هذه الواجهة فقط، لذلك يمكن تبديل مصدر البيانات
/// دون تغيير أي شاشة.
abstract class Repository {
  /// بثّ يُطلق إشارة قصيرة عند تغيّر البيانات على الخادم (Realtime).
  /// في الوضع المحلي لا يصدر أي إشارة (البيانات محلية أصلاً).
  Stream<void> get changes;

  // ---------------------------------------------------------------- users
  Future<AppUser?> findUserByPhone(String phone);

  Future<AppUser?> userById(int id);

  /// جلب الملف الشخصي المرتبط بمعرّف مصادقة Supabase.
  Future<AppUser?> userByAuthId(String authId);

  Future<int> createUser(AppUser user);

  Future<void> updateUser(AppUser user);

  Future<bool> phoneExists(String phone);

  Future<List<AppUser>> listCustomers({String query = ''});

  Future<int> customerCount();

  // ----------------------------------------------------------- categories
  Future<List<Category>> listCategories();

  Future<Category?> categoryById(int id);

  Future<int> saveCategory(Category category);

  Future<int> serviceCountForCategory(int id);

  Future<void> deleteCategory(int id);

  // -------------------------------------------------------------- workers
  Future<List<Worker>> listWorkers({int? categoryId, bool onlyAvailable = false});

  Future<Worker?> workerById(int id);

  Future<int> saveWorker(Worker worker);

  Future<void> deleteWorker(int id);

  Future<void> incrementWorkerJobs(int? workerId);

  // ------------------------------------------------------------- services
  Future<List<Service>> listServices({
    int? categoryId,
    String query = '',
    bool onlyActive = true,
    int? limit,
  });

  Future<Service?> serviceById(int id);

  Future<int> saveService(Service service);

  Future<void> deleteService(int id);

  Future<int> serviceCount();

  // ------------------------------------------------------------- bookings
  Future<List<Booking>> bookingsForCustomer(int customerId, {String? status});

  Future<List<Booking>> allBookings({String? status, String query = ''});

  Future<Booking?> bookingById(int id);

  Future<int> createBooking(Booking booking);

  Future<void> updateBookingStatus(int id, String status);

  Future<void> assignWorker(int bookingId, int? workerId);

  Future<int> bookingsTodayCount();

  Future<int> pendingBookingsCount();

  // ---------------------------------------------------------------- posts
  Future<List<Post>> listPosts({
    bool onlyApproved = true,
    int? categoryId,
    int? customerId,
    String query = '',
    int? limit,
  });

  Future<Post?> postById(int id);

  Future<int> createPost(Post post);

  Future<void> approvePost(int id, bool approved);

  Future<void> deletePost(int id);

  Future<void> toggleLike(int id, bool liked);

  Future<int> postCount();

  Future<int> pendingPostsCount();

  // ------------------------------------------------------------- comments
  Future<List<PostComment>> commentsForPost(int postId);

  Future<int> addComment(PostComment comment);

  Future<void> deleteComment(int id);

  Future<int> commentCountForUser(int userId);

  // ------------------------------------------------------------- messages
  Future<List<ChatMessage>> threadMessages(int customerId);

  Future<int> sendMessage(ChatMessage message);

  Future<void> markThreadRead(int customerId, {required String readerRole});

  Future<int> unreadForAdmin();

  Future<int> unreadForCustomer(int customerId);

  Future<List<ChatThread>> messageThreads();

  // ---------------------------------------------------------------- cards
  Future<List<PaymentCard>> cardsForUser(int userId);

  Future<int> addCard(PaymentCard card);

  Future<void> deleteCard(int id);

  // ------------------------------------------------------------- receipts
  Future<int> createReceiptForBooking({
    required int bookingId,
    required int userId,
    required String title,
    required double amount,
    required String method,
    String? cardBrand,
    String? last4,
    required bool paid,
  });

  Future<List<Receipt>> receiptsForUser(int userId);

  Future<List<Receipt>> allReceipts();

  Future<Receipt?> receiptById(int id);

  Future<Receipt?> receiptForBooking(int bookingId);

  Future<void> markReceiptPaid(int id, bool paid);

  // ------------------------------------------------------------- settings
  Future<String> getSetting(String key, {String fallback = ''});

  Future<void> setSetting(String key, String value);

  // ---------------------------------------------------------------- stats
  Future<AppStats> stats();

  Future<void> resetDemoData();

  Future<void> close();
}
