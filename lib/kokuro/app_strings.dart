/// Centralised Arabic strings for the entire KOKURO UI.
/// Usage: `AppStrings.watchNow`, `AppStrings.retry`, etc.
class AppStrings {
  AppStrings._();

  // ── Brand ────────────────────────────────────────────────
  static const String appName = 'KOKURO';

  // ── Navigation ───────────────────────────────────────────
  static const String navHome = 'الرئيسية';
  static const String navExplore = 'اكتشف';
  static const String navLibrary = 'مكتبتي';

  // ── Search ───────────────────────────────────────────────
  static const String searchHint = 'ابحث عن أنمي، شخصيات، أنواع...';
  static const String recentSearches = 'عمليات البحث الأخيرة';
  static const String clearSearches = 'مسح السجل';

  // ── Top Bar ──────────────────────────────────────────────
  static const String notifications = 'الإشعارات';
  static const String noNotifications = 'لا توجد إشعارات جديدة';
  static const String openMyList = 'فتح قائمتي';
  static const String nextEpisodeAirs = 'بث جديد يوم';
  static const String airsSoon = 'هتتجدد قريب';
  static const String airsTodayIn = 'في خلال شوية';
  static const String on = 'في';
  static const String upcomingAirs = 'الحلقات القادمة';
  static const String searchMyLibrary = 'ابحث في مكتبتي...';

  // ── Profile ──────────────────────────────────────────────
  static const String myProfile = 'ملفي الشخصي';
  static const String editProfile = 'تعديل الملف الشخصي';
  static const String displayName = 'الاسم المعروض';
  static const String displayNameHint = 'اكتب اسمك هنا';
  static const String bio = 'نبذة';
  static const String bioHint = 'عرّف بنفسك في سطر...';
  static const String pickAvatar = 'اختر الأفاتار';
  static const String accentTheme = 'لون التطبيق';
  static const String favoriteGenre = 'النوع المفضل';
  static const String profileSaved = 'تم حفظ ملفك الشخصي';
  static const String nameRequired = 'الاسم مطلوب';
  static const String guestUser = 'مستخدم كوكورو';
  static const String localOnlyNote =
      'يُحفظ محلياً على جهازك فقط — بدون حساب أو سيرفر.';

  // ── Buttons / Actions ────────────────────────────────────
  static const String watchNow = 'شاهد الآن';
  static const String watch = 'مشاهدة';
  static const String continueWatching = 'متابعة';
  static const String rewatch = 'إعادة المشاهدة';
  static const String retry = 'إعادة المحاولة';
  static const String cancel = 'إلغاء';
  static const String save = 'حفظ';
  static const String submitReview = 'إرسال المراجعة';
  static const String saveRating = 'حفظ التقييم';
  static const String clearRating = 'مسح التقييم';
  static const String goBack = 'رجوع';
  static const String reloadPage = 'إعادة تحميل الصفحة';
  static const String openOnYouTube = 'فتح على يوتيوب';
  static const String searchOnYouTube = 'البحث على يوتيوب';
  static const String closePlayer = 'إغلاق المشغل';

  // ── My List ──────────────────────────────────────────────
  static const String myList = 'قائمتي';
  static const String addToMyList = 'إضافة لقائمتي';
  static const String removeFromMyList = 'إزالة من قائمتي';
  static const String savedToList = 'تم الحفظ في القائمة';
  static const String removedFromList = 'تمت الإزالة من القائمة';
  static const String inMyList = 'في قائمتي';

  // ── Detail Screen — Tabs ─────────────────────────────────
  static const String tabStory = 'القصة';
  static const String tabCharacters = 'الشخصيات';
  static const String tabEpisodes = 'الحلقات';
  static const String tabReviews = 'المراجعات';
  static const String tabRelated = 'ذات صلة';

  // ── Detail Screen — Header ───────────────────────────────
  static const String episodes = 'حلقات';
  static const String episodesCount = 'حلقة';
  static const String members = 'عضو';
  static const String score = 'التقييم';
  static const String status = 'الحالة';
  static const String year = 'السنة';
  static const String characters = 'الشخصيات';

  // ── Detail Screen — Synopsis ─────────────────────────────
  static const String synopsis = 'القصة';
  static const String noSynopsis = 'القصة غير متاحة.';
  static const String watchOn = 'شاهد من';
  static const String navigateExternal = 'فتح في المتصفح';
  static const String updateAvailable = 'نسخة جديدة من كوكورو متاحة.';
  static const String updateNow = 'تحديث الآن';
  static const String ofTotalEpisodes = 'من إجمالي';

  // ── Detail Screen — AT A GLANCE ──────────────────────────
  static const String atAGlance = 'نظرة عامة';

  // ── Detail Screen — Menu ─────────────────────────────────
  static const String rateThisAnime = 'قيّم هذا الأنمي';
  static const String writeReview = 'اكتب مراجعة';
  static const String refresh = 'تحديث';
  static const String streamingComingSoon = 'سيتم البث قريباً';

  // ── Detail Screen — Buttons ──────────────────────────────
  static const String watchTrailer = 'شاهد الإعلان';
  static const String youtube = 'يوتيوب';
  static const String officialTrailer = 'الإعلان الرسمي';
  static const String tapToWatchTrailer = 'اضغط لمشاهدة الإعلان الرسمي';

  // ── Detail Screen — Empty States ─────────────────────────
  static const String noCharacters = 'لا توجد شخصيات متاحة';
  static const String noCharactersSubtitle =
      'ستظهر ملفات الشخصيات بعد تحميل القصة.';
  static const String noEpisodes = 'لا توجد حلقات متاحة';
  static const String noEpisodesSubtitle =
      'تعذرت جلب بيانات الحلقات لهذا العنوان.';
  static const String noReviews = 'لا توجد مراجعات بعد. كن أول من يشارك رأيه';
  static const String noRecommendations = 'لا توجد توصيات متاحة';
  static const String noRecommendationsSubtitle =
      'ستظهر عناصر مشابهة هنا بناءً على مكتبتك.';
  static const String you = 'أنت';

  // ── Detail Screen — Reviews ──────────────────────────────
  static const String communityReviews = 'مراجعات المجتمع';
  static const String editReview = 'تعديل مراجعتك';
  static const String writeYourReview = 'اكتب مراجعتك';
  static const String shareYourThoughts = 'شارك رأيك في هذه القصة';
  static const String whatDidYouThink = 'ماذا رأيت؟';
  static const String pleaseWriteThoughts = 'اكتب أفكارك من فضلك';
  static const String yourRating = 'تقييمك: ';

  // ── Detail Screen — Episodes ─────────────────────────────
  static const String episode = 'حلقة';
  static const String aired = 'تاريخ العرض:';
  static const String tba = 'قريباً';

  // ── Detail Screen — Progress ─────────────────────────────
  static const String episodeMarked = 'تم تحديد الحلقة كمشاهدة';

  // ── Detail Screen — Player Errors ────────────────────────
  static const String playerDidNotLoad =
      'لم يتم تحميل نظام المشغل. أعد تحميل الصفحة للمحاولة.';
  static const String trailerCouldNotStart =
      'تعذر بدء تشغيل الإعلان. جرّب إعادة تحميل الصفحة.';
  static const String trailerUnavailable =
      'هذا الإعلان غير متاح (معرف فيديو غير صالح).';
  static const String trailerCannotPlay =
      'لا يمكن تشغيل هذا الإعلان في مشغل مدمج.';
  static const String trailerRemoved = 'تم حذف هذا الإعلان أو جعله خاصاً.';
  static const String trailerNotAllowed = 'المالك لا يسمح بدمج هذا الإعلان.';
  static const String trailerErrorCode =
      'أبلغ مشغل الإعلان عن خطأ (الكود \$code).';

  // ── Loading States ───────────────────────────────────────
  static const String enteringStory = 'جارٍ تحميل القصة...';
  static const String loadingFullStory = 'لا يمكن تحميل القصة الكاملة';
  static const String channelingCharacter = 'جارٍ تحميل الشخصية...';
  static const String unfoldingLibrary = 'جارٍ تحميل المكتبة...';

  // ── Home Screen ──────────────────────────────────────────
  static const String thisSeason = 'هذا الموسم';
  static const String freshStories = 'قصص جديدة';
  static const String movieNight = 'ليلة أفلام';
  static const String cinemaPicks = 'اختيارات السينما';
  static const String spotlight = 'مميّز';
  static const String handPicked = 'مختار لك بعناية';
  static const String comingSoon = 'قريباً';
  static const String markYourCalendar = 'حدد موعدك';
  static const String becauseYouWatched = 'لأنك شاهدت';
  static const String moreLikeWhatYouLove = 'المزيد مما تحب';
  static const String topRated = 'الأعلى تقييماً';
  static const String topTenNow = 'قائمة العشرة الأوائل';
  static const String browseByGenre = 'تصفّح حسب النوع';
  static const String pickAMood = 'اختر مزاجك وانطلق';
  static const String seeAll = 'عرض الكل';
  static const String featured = 'مميز';
  static const String journeyAwaits = 'رحلة تنتظرك...';
  static const String dailyPick = 'اختيار اليوم';
  static const String continueJourney = 'تابع رحلتك';
  static const String keepMomentum = 'استمر في المتابعة';
  static const String yourLibrary = 'مكتبتك';
  static const String nothingYet = 'لا شيء بعد — اكتشف!';
  static const String titlesSaved = 'عناصر محفوظة';
  static const String title = 'عنصر';
  static const String titles = 'عناصر';
  static const String addAnimeToList = 'أضف أنمي إلى قائمتك لمواصلة رحلتك.';
  static const String tapTitleAbove = 'اضغط على أي عنوان أعلاه لمواصلة القصة.';
  static const String exploreTitles = 'استكشف العناصر';
  static const String trendingThreads = 'الأسئلة الرائجة';
  static const String whatFansBinging = 'ماذا يشاهد المعجبون';
  static const String storyThreads = 'خيوط القصة';
  static const String storyThreadsSubtitle =
      'كل أنمي. كل شخصية.\nكل لحظة. متصلة.';
  static const String winter = 'الشتاء';
  static const String spring = 'الربيع';
  static const String summer = 'الصيف';
  static const String fall = 'الخريف';

  // ── Explore Screen ───────────────────────────────────────
  static const String all = 'الكل';
  static const String popular = 'الأكثر شعبية';
  static const String upcoming = 'القادم';
  static const String discoverMood = 'اكتشف قصصاً تناسب روحك.';
  static const String searchAnime = 'ابحث عن أنمي...';
  static const String season = 'الموسم';
  static const String studio = 'الاستوديو';
  static const String type = 'النوع';
  static const String rating = 'التصنيف';
  static const String sort = 'الترتيب';
  static const String genreMap = 'خريطة الأنواع';
  static const String exploreByMood = 'اكتشف حسب المزاج';
  static const String noResults = 'لا توجد نتائج';
  static const String noAnimeFound = 'لم يتم العثور على أنمي';
  static const String noMoreResults = 'لا مزيد من النتائج';
  static const String popularIn = 'الأكثر شعبية في';
  static const String resultsFor = 'نتائج لـ';
  static const String loadingCategory = 'جارٍ تحميل الفئة الكاملة...';
  static const String viewAll = 'عرض الكل';
  static const String viewAllTitles = 'عرض الكل \$total عنصر';

  // ── Explore — Genres ─────────────────────────────────────
  static const String genreAction = 'أكشن';
  static const String genreAdventure = 'مغامرة';
  static const String genreComedy = 'كوميديا';
  static const String genreDrama = 'دراما';
  static const String genreFantasy = 'خيال';
  static const String genreHorror = 'رعب';
  static const String genreMystery = 'غموض';
  static const String genreRomance = 'رومانسي';
  static const String genreSciFi = 'خيال علمي';
  static const String genreSliceOfLife = 'الحياة اليومية';
  static const String genreSports = 'رياضة';
  static const String genreSupernatural = 'خارق';
  static const String genreThriller = 'إثارة';

  // ── Library Screen ───────────────────────────────────────
  static const String watching = 'أشاهد';
  static const String completed = 'مكتمل';
  static const String planToWatch = 'قائمة المشاهدة';
  static const String onHold = 'معلّق';
  static const String dropped = 'متوقف';
  static const String myUniverse = 'عالمي';
  static const String yourStories = 'قصصك. خيوطك.';
  static const String titlesInLibrary = 'عناصر في مكتبتك.';
  static const String libraryEmpty = 'مكتبتك فارغة';
  static const String addAnimeToWatchlist =
      'أضف أنمي إلى قائمة المشاهدة لتراها هنا.';
  static const String nothingInLabel = 'لا شيء في "\$label"';
  static const String moveToStatus = 'انقل عنصراً إلى هذا الحالة لتراه هنا.';
  static const String removed = 'تمت الإزالة';
  static const String epsWatched = 'حلقات مشاهدة';
  static const String changeStatus = 'تغيير الحالة';
  static const String removeFromLibrary = 'إزالة من المكتبة';
  static const String watchTime = 'وقت المشاهدة';
  static const String favGenre = 'النوع المفضل';
  static const String yourAnimePersonality = 'شخصيتك الأنمي';
  static const String recentActivity = 'النشاط الأخير';
  static const String noRecentActivity = 'لا يوجد نشاط حديث';
  static const String none = 'لا شيء';
  static const String justNow = 'الآن';
  static const String minutesAgo = 'دقائق مضت';
  static const String hoursAgo = 'ساعات مضت';
  static const String daysAgo = 'أيام مضت';
  static const String weeksAgo = 'أسابيع مضت';

  // ── Library — Personality ────────────────────────────────
  static const String personalityWarrior = 'المقاتل';
  static const String personalityWarriorDesc =
      'تعيش على الإثارة من المواجهات الملحمية والمعارك الشرسة.';
  static const String personalityDreamer = 'الحالم';
  static const String personalityDreamerDesc =
      'تشعر بالحياة في عوالم يكون فيها المستحيل ممكناً.';
  static const String personalityRomantic = 'الرومانسي';
  static const String personalityRomanticDesc =
      'تؤمن بقوة الحب والروابط الصادقة.';
  static const String personalityVisionary = 'الرؤية';
  static const String personalityVisionaryDesc =
      'تجذبك إمكانيات الغد وما وراءه.';
  static const String personalityDetective = 'المحقق';
  static const String personalityDetectiveDesc =
      'تحب حل الألغاز وكشف الحقائق الخفية.';
  static const String personalityStoryteller = 'الراوي';
  static const String personalityStorytellerDesc =
      'تقدر السرد العميق والرحلة المعقدة للشخصيات.';
  static const String personalityExplorer = 'المستكشف';
  static const String personalityExplorerDesc =
      'تتبنى كل نوع وتجد الجمال في التنوع.';

  // ── Character Screen ─────────────────────────────────────
  static const String personality = 'الشخصية';
  static const String voiceActor = 'ممثل الصوت';
  static const String unknown = 'غير معروف';
  static const String japanese = 'اليابانية';
  static const String appearances = 'المظاهر';
  static const String noAppearances = 'لا توجد مظاهر متاحة';
  static const String viewAnime = 'عرض الأنمي';

  // ── Character Screen — Traits ────────────────────────────
  static const String traitBrave = 'شجاع';
  static const String traitDetermined = 'مصمم';
  static const String traitResilient = 'مرن';
  static const String traitRuthless = 'قاسي';
  static const String traitIntelligent = 'ذكي';
  static const String traitCharismatic = 'كاريزمي';
  static const String traitProud = 'فخور';
  static const String traitStrategic = 'استراتيجي';
  static const String traitComplex = 'معقد';
  static const String traitGraceful = 'أنيق';
  static const String traitPerceptive = 'حاد الإدراك';
  static const String traitKind = 'لطيف';
  static const String traitLoyal = 'وفيّ';
  static const String traitReliable = 'موثوق';
  static const String traitVersatile = 'متعدد المواهب';
  static const String traitSupportive = 'داعم';
  static const String traitStrong = 'قوي';
  static const String traitDependable = 'يعتمد عليه';
  static const String traitUnique = 'فريد';
  static const String traitIntriguing = 'مشوق';
  static const String traitMysterious = 'غامض';

  // ── Episode Player ───────────────────────────────────────
  static const String episodeNumber = 'الحلقة';
  static const String officialYouTube = 'يوتيوب الرسمي';
  static const String watchedSaved = 'تم المشاهدة — محفوظ في مكتبتك';
  static const String watchingNow = 'جارٍ المشاهدة — يُحفظ التقدم تلقائياً';
  static const String startingStream = 'جارٍ بدء البث الرسمي...';
  static const String couldNotPlay = 'تعذر تشغيل هذه الحلقة على يوتيوب.';
  static const String videoUnavailable = 'هذا الفيديو غير متاح للدمج.';

  // ── App Router ───────────────────────────────────────────
  static const String characterNotFound = 'الشخصية غير موجودة';

  // ── BLoC Errors ──────────────────────────────────────────
  static const String couldNotLoadAnime = 'تعذر تحميل بيانات الأنمي';
  static const String animeNotFound = 'الأنمي غير موجود';

  // ── Watch Status Labels ──────────────────────────────────
  static const String statusWatching = 'أشاهد';
  static const String statusCompleted = 'مكتمل';
  static const String statusPlanToWatch = 'قائمة المشاهدة';
  static const String statusOnHold = 'معلّق';
  static const String statusDropped = 'متوقف';

  // ── Misc ─────────────────────────────────────────────────
  static const String xp = 'XP';
  static const String level = 'المستوى';
  static const String eps = 'حلقات';

  static const Map<String, String> genreLabels = {
    'Action': genreAction,
    'Adventure': genreAdventure,
    'Comedy': genreComedy,
    'Drama': genreDrama,
    'Fantasy': genreFantasy,
    'Horror': genreHorror,
    'Mystery': genreMystery,
    'Romance': genreRomance,
    'Sci-Fi': genreSciFi,
    'Slice of Life': genreSliceOfLife,
    'Sports': genreSports,
    'Supernatural': genreSupernatural,
    'Thriller': genreThriller,
  };

  static String genreLabel(String en) => genreLabels[en] ?? en;

  static String genreKey(String ar) {
    for (final e in genreLabels.entries) {
      if (e.value == ar) return e.key;
    }
    return ar;
  }
}
