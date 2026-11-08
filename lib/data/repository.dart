import 'models.dart';

/// واجهة البيانات الموحّدة للتطبيق — تنفيذها الحالي [LocalRepository]
/// (SQLite على الجهاز، كل شيء محلي).
abstract class Repository {
  /// بثّ يُطلق إشارة قصيرة عند وصول رسالة جديدة. محلياً لا تصدر أي إشارة.
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
  Future<List<Worker>> listWorkers(
      {int? categoryId, bool onlyAvailable = false});

  Future<Worker?> workerById(int id);

  /// ملف الحرفي المرتبط برقم الهاتف، ليعرف الحساب محافظته المحفوظة في الدليل.
  Future<Worker?> workerByPhone(String phone);

  /// يحدّث محافظة الحرفي المرتبط بالحساب، ويُبقيها متطابقة مع محافظة الملف.
  Future<void> updateWorkerCity(String phone, String city);

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

  /// يعيّن الحرفي (أو يغيّره)، فيعود رده إلى «بانتظار» ويُخطَر الحرفي الجديد.
  Future<void> assignWorker(int bookingId, int? workerId);

  /// طلبات الحرفي صاحب هذا الحساب. العنوان ورقم الزبون فيها فارغان حتى ترسله الإدارة.
  Future<List<Booking>> bookingsForWorker(AppUser worker);

  /// المدير يحدد السعر المتفق عليه للحجز، فيُنشأ به الوصل (أو يتحدث) ليدفعه الزبون لاحقاً.
  Future<void> setBookingPrice(int bookingId, double amount);

  /// تعديل المدير للحجز: يسجّل ما تغيّر ووقت التعديل، ويطلب موافقة الزبون عليه.
  Future<void> adminUpdateBooking(
    int bookingId, {
    required DateTime scheduledAt,
    required String slot,
    required String address,
    String? notes,
    String? adminNote,
  });

  /// الزبون يوافق على تعديل الإدارة أو يرفضه.
  Future<void> respondToBookingEdit(int bookingId, {required bool approve});

  /// الحرفي يؤكد الطلب أو يعتذر عنه قبل إرساله.
  Future<void> respondToBooking(int bookingId, {required bool accept});

  /// تقييم العامل بعد اكتمال الحجز.
  ///
  /// يحفظ تقييم العميل وملاحظته ويحدّث متوسط تقييم العامل.
  /// يعيد false إذا تعذّر التقييم، مثلاً إذا لم يكتمل الحجز أو سبق تقييمه.
  Future<bool> rateBooking({
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

  // ----------------------------------------------------------- أعمالنا (فيديو)
  /// قائمة أعمال «أعمالنا» — الأحدث أولاً، مع إعجابات المشاهد وعدد التعليقات.
  Future<List<OurWork>> listWorks({
    bool onlyActive = true,
    String query = '',
    int? limit,
    int? viewerId,
  });

  Future<OurWork?> workById(int id, {int? viewerId});

  Future<int> createWork(OurWork work);

  Future<void> updateWork(OurWork work);

  Future<void> setWorkActive(int id, bool active);

  Future<void> deleteWork(int id);

  Future<void> incrementWorkViews(int id);

  Future<void> setWorkLike(int id, {required int userId, required bool liked});

  Future<List<WorkComment>> workComments(
    int workId, {
    int? viewerId,
    bool isAdmin = false,
  });

  Future<int> addWorkComment(WorkComment comment);

  Future<void> updateWorkComment(int id, {required String body});

  Future<void> setWorkCommentReaction(
    int commentId, {
    required int userId,
    required int reaction,
  });

  Future<void> setWorkCommentHeart(
    int commentId, {
    required bool hearted,
  });

  Future<int> workCount();

  // ------------------------------------------------------------- التوظيف
  /// يضيف رقماً للتوظيف، ويرقّي أي حساب موجود بهذا الرقم إلى (حرفي).
  Future<int> createHire(Hire hire);

  Future<List<Hire>> listHires();

  Future<bool> isHiredPhone(String phone);

  /// يحذف الرقم ويُرجع صاحبه (إن كان حرفاً) إلى زبون عادي.
  Future<void> deleteHire(int id);

  // ------------------------------------------------------ طلبات الحرفيين
  Future<int> createApplication(CraftsmanApplication application);

  Future<List<CraftsmanApplication>> listApplications();

  Future<bool> hasPendingApplication(String phone);

  /// يقبل الطلب ويضيف رقمه للتوظيف، فيصبح حسابه (حرفي) عند التسجيل.
  Future<void> acceptApplication(CraftsmanApplication application);

  Future<void> rejectApplication(int id);

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
