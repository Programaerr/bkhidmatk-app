import 'dart:async';

import 'models.dart';
import 'repository.dart';

/// In-memory no-op repository for the isolated web admin preview.
class PreviewRepository implements Repository {
  final StreamController<void> _changeController =
      StreamController<void>.broadcast();
  final List<OurWork> _works = [];
  int _nextWorkId = 1;

  static final _previewUser = AppUser(
    id: 1,
    name: 'أحمد سعد',
    phone: '07701234567',
    passwordHash: '',
    role: 'customer',
    city: 'بغداد',
    createdAt: DateTime.utc(2026),
  );

  @override
  Stream<void> get changes => _changeController.stream;

  void _notifyChanged() {
    if (!_changeController.isClosed) _changeController.add(null);
  }

  // users
  @override
  Future<AppUser?> findUserByPhone(String phone) async => _previewUser;

  @override
  Future<AppUser?> userById(int id) async => _previewUser;

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
  Future<List<Worker>> listWorkers(
          {int? categoryId, bool onlyAvailable = false}) async =>
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
  Future<List<Booking>> bookingsForCustomer(int customerId,
          {String? status}) async =>
      const [];

  @override
  Future<List<Booking>> allBookings(
          {String? status, String query = ''}) async =>
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
  Future<int> rateBooking(
          {required int bookingId,
          required int rating,
          String? review}) async =>
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

  // أعمالنا
  @override
  Future<List<OurWork>> listWorks({
    bool onlyActive = true,
    String query = '',
    int? limit,
    int? viewerId,
  }) async {
    final term = query.trim().toLowerCase();
    final works = _works.where((work) {
      return (!onlyActive || work.active) &&
          (term.isEmpty ||
              work.title.toLowerCase().contains(term) ||
              (work.description ?? '').toLowerCase().contains(term));
    }).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return works.take(limit ?? works.length).toList();
  }

  @override
  Future<OurWork?> workById(int id, {int? viewerId}) async {
    for (final work in _works) {
      if (work.id == id) return work;
    }
    return null;
  }

  @override
  Future<int> createWork(OurWork work) async {
    final id = _nextWorkId++;
    _works.add(work.copyWith(id: id));
    _notifyChanged();
    return id;
  }

  @override
  Future<void> updateWork(OurWork work) async {
    if (work.id == null) return;
    final index = _works.indexWhere((item) => item.id == work.id);
    if (index < 0) return;
    _works[index] = work;
    _notifyChanged();
  }

  @override
  Future<void> setWorkActive(int id, bool active) async {
    final index = _works.indexWhere((item) => item.id == id);
    if (index < 0) return;
    _works[index] = _works[index].copyWith(active: active);
    _notifyChanged();
  }

  @override
  Future<void> deleteWork(int id) async {
    _works.removeWhere((item) => item.id == id);
    _notifyChanged();
  }

  @override
  Future<void> incrementWorkViews(int id) async {
    final index = _works.indexWhere((item) => item.id == id);
    if (index < 0) return;
    _works[index] = _works[index].copyWith(views: _works[index].views + 1);
    _notifyChanged();
  }

  @override
  Future<void> setWorkLike(int id,
      {required int userId, required bool liked}) async {}

  @override
  Future<List<WorkComment>> workComments(int workId) async => const [];

  @override
  Future<int> addWorkComment(WorkComment comment) async => 1;

  @override
  Future<int> workCount() async => _works.length;

  // التوظيف
  @override
  Future<int> createHire(Hire hire) async => 1;

  @override
  Future<List<Hire>> listHires() async => const [];

  @override
  Future<bool> isHiredPhone(String phone) async => false;

  @override
  Future<void> deleteHire(int id) async {}

  // طلبات الحرفيين
  @override
  Future<int> createApplication(CraftsmanApplication application) async => 1;

  @override
  Future<List<CraftsmanApplication>> listApplications() async => const [];

  @override
  Future<bool> hasPendingApplication(String phone) async => false;

  @override
  Future<void> acceptApplication(CraftsmanApplication application) async {}

  @override
  Future<void> rejectApplication(int id) async {}

  // messages
  @override
  Future<List<ChatMessage>> threadMessages(int customerId) async => const [];

  @override
  Future<int> sendMessage(ChatMessage message) async => 1;

  @override
  Future<void> markThreadRead(int customerId,
      {required String readerRole}) async {}

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
  Future<String> getSetting(String key, {String fallback = ''}) async =>
      fallback;

  @override
  Future<void> setSetting(String key, String value) async {}

  // stats
  @override
  Future<AppStats> stats() async => const AppStats();

  @override
  Future<void> resetDemoData() async {}

  @override
  Future<void> close() => _changeController.close();
}
