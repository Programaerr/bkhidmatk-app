import 'models.dart';

/// نقاط المكافأة الممنوحة لكل نجمة تقييم: تقييم 5 نجوم = 50 نقطة.
const int pointsPerStar = 10;

int pointsForRating(int rating) => rating.clamp(1, 5) * pointsPerStar;

/// واجهة البيانات الموحّدة للتطبيق — تنفيذها الحالي [LocalRepository]
/// (SQLite على الجهاز، كل شيء محلي).
abstract class Repository {
  /// بثّ يُطلق إشارة قصيرة عند تغيّر البيانات. محلياً لا تصدر أي إشارة.
  Stream<void> get changes;

  // ---------------------------------------------------------------- users
  Future<AppUser?> findUserByPhone(String phone);

  Future<AppUser?> userById(int id);

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

  /// تقييم العامل بعد اكتمال الحجز.
  ///
  /// يحفظ تقييم العميل (1..5) وملاحظته، ويضيف نقاط مكافأة لرصيد العميل
  /// ([pointsForRating] نقطة)، ويحدّث متوسط تقييم العامل.
  /// يعيد عدد النقاط المضافة، أو 0 إذا كان الحجز مقيَّماً مسبقاً.
  Future<int> rateBooking({
    required int bookingId,
    required int rating,
    String? review,
  });

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
