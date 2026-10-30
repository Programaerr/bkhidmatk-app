import 'package:bkhidmatk/data/models.dart';
import 'package:bkhidmatk/data/repository.dart';

/// مستودع وهمي فارغ لاختبار الواجهات بدون قاعدة بيانات حقيقية.
class FakeRepo implements Repository {
  FakeRepo({this.customer});

  /// زبون افتراضي يُعاد عند استعلام المستخدم الحالي.
  final AppUser? customer;

  @override
  Stream<void> get changes => const Stream<void>.empty();

  // users
  @override
  Future<AppUser?> findUserByPhone(String phone) async => customer;

  @override
  Future<AppUser?> userById(int id) async => customer;

  @override
  Future<int> createUser(AppUser user) async => 1;

  @override
  Future<void> updateUser(AppUser user) async {}

  @override
  Future<bool> phoneExists(String phone) async => false;

  @override
  Future<List<AppUser>> listCustomers({String query = ''}) async => const [];

  @override
  Future<int> customerCount() async => 0;

  // categories
  @override
  Future<List<Category>> listCategories() async => const [];

  @override
  Future<Category?> categoryById(int id) async => null;

  @override
  Future<int> saveCategory(Category category) async => 1;

  @override
  Future<int> serviceCountForCategory(int id) async => 0;

  @override
  Future<void> deleteCategory(int id) async {}

  // workers
  @override
  Future<List<Worker>> listWorkers({int? categoryId, bool onlyAvailable = false}) async =>
      const [];

  @override
  Future<Worker?> workerById(int id) async => null;

  @override
  Future<int> saveWorker(Worker worker) async => 1;

  @override
  Future<void> deleteWorker(int id) async {}

  @override
  Future<void> incrementWorkerJobs(int? workerId) async {}

  // services
  @override
  Future<List<Service>> listServices({
    int? categoryId,
    String query = '',
    bool onlyActive = true,
    int? limit,
  }) async =>
      const [];

  @override
  Future<Service?> serviceById(int id) async => null;

  @override
  Future<int> saveService(Service service) async => 1;

  @override
  Future<void> deleteService(int id) async {}

  @override
  Future<int> serviceCount() async => 0;

  // bookings
  @override
  Future<List<Booking>> bookingsForCustomer(int customerId, {String? status}) async =>
      const [];

  @override
  Future<List<Booking>> allBookings({String? status, String query = ''}) async =>
      const [];

  @override
  Future<Booking?> bookingById(int id) async => null;

  @override
  Future<int> createBooking(Booking booking) async => 1;

  @override
  Future<void> updateBookingStatus(int id, String status) async {}

  @override
  Future<void> assignWorker(int bookingId, int? workerId) async {}

  @override
  Future<int> rateBooking({required int bookingId, required int rating, String? review}) async =>
      0;

  @override
  Future<int> bookingsTodayCount() async => 0;

  @override
  Future<int> pendingBookingsCount() async => 0;

  // posts
  @override
  Future<List<Post>> listPosts({
    bool onlyApproved = true,
    int? categoryId,
    int? customerId,
    String query = '',
    int? limit,
  }) async =>
      const [];

  @override
  Future<Post?> postById(int id) async => null;

  @override
  Future<int> createPost(Post post) async => 1;

  @override
  Future<void> approvePost(int id, bool approved) async {}

  @override
  Future<void> deletePost(int id) async {}

  @override
  Future<void> toggleLike(int id, bool liked) async {}

  @override
  Future<int> postCount() async => 0;

  @override
  Future<int> pendingPostsCount() async => 0;

  // comments
  @override
  Future<List<PostComment>> commentsForPost(int postId) async => const [];

  @override
  Future<int> addComment(PostComment comment) async => 1;

  @override
  Future<void> deleteComment(int id) async {}

  @override
  Future<int> commentCountForUser(int userId) async => 0;

  // messages
  @override
  Future<List<ChatMessage>> threadMessages(int customerId) async => const [];

  @override
  Future<int> sendMessage(ChatMessage message) async => 1;

  @override
  Future<void> markThreadRead(int customerId, {required String readerRole}) async {}

  @override
  Future<int> unreadForAdmin() async => 0;

  @override
  Future<int> unreadForCustomer(int customerId) async => 0;

  @override
  Future<List<ChatThread>> messageThreads() async => const [];

  // cards
  @override
  Future<List<PaymentCard>> cardsForUser(int userId) async => const [];

  @override
  Future<int> addCard(PaymentCard card) async => 1;

  @override
  Future<void> deleteCard(int id) async {}

  // receipts
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
  }) async =>
      1;

  @override
  Future<List<Receipt>> receiptsForUser(int userId) async => const [];

  @override
  Future<List<Receipt>> allReceipts() async => const [];

  @override
  Future<Receipt?> receiptById(int id) async => null;

  @override
  Future<Receipt?> receiptForBooking(int bookingId) async => null;

  @override
  Future<void> markReceiptPaid(int id, bool paid) async {}

  // settings
  @override
  Future<String> getSetting(String key, {String fallback = ''}) async => fallback;

  @override
  Future<void> setSetting(String key, String value) async {}

  // stats
  @override
  Future<AppStats> stats() async => const AppStats();

  @override
  Future<void> resetDemoData() async {}

  @override
  Future<void> close() async {}
}
