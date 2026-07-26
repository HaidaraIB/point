import 'package:point/Models/TaskModel.dart';
import 'package:point/config/app_config.dart';

class StorageKeys {
  /// طلب مزامنة بعد دفع FCM صامت (خلفية).
  static const String prefsPendingPushSync = 'point_pending_push_sync_v1';

  /// آخر توكن FCM نُزامَن بنجاح (للمقارنة عند استئناف التطبيق).
  static const String prefsFcmTokenLastSynced = 'point_fcm_token_last_synced_v1';

  /// `employee` أو `client` — يقترن بـ [prefsFcmTokenUserId].
  static const String prefsFcmTokenRole = 'point_fcm_token_role_v1';

  static const String prefsFcmTokenUserId = 'point_fcm_token_user_id_v1';

  /// أقصى `createdAt` (ms منذ epoch) لإشعار وارد رأيناه عند استطلاع Firestore بعد الاستئناف.
  static const String prefsNotificationsResumeCursorMs =
      'point_notifications_resume_cursor_ms_v1';

  /// مرة واحدة: اقتراح تعطيل تحسين البطارية لـ Android.
  static const String prefsBatteryOptPromptShown = 'point_battery_opt_prompt_v1';

  /// مفتاح anon من Supabase (public).
  static String get supabaseKey => AppConfig.supabaseAnonKey;

  /// رابط التخزين العام (public).
  static String get supabaseStorageBaseUrl => AppConfig.supabaseStorageBaseUrl;
  static final List<String> contentsTypeList = [
    "content_image",
    "content_video",
    "content_reel",
    "content_story",
    "content_ads",
    "content_article",
    "content_text",
    "content_graphic",
    "content_podcast",
    "content_live",
  ];
  static final List<String> platformList = [
    // "all",
    "platform_facebook",
    "platform_instagram",
    "platform_messenger",
    "platform_whatsapp",
    "platform_twitter",
    "platform_linkedin",
    "platform_youtube",
    "platform_tiktok",
    "platform_snapchat",
    "platform_pinterest",
    "platform_telegram",
    "platform_threads",
    "platform_meta_ads",
    "platform_google_ads",
  ];
  static final List<String> campaignTarget = [
    "sales",
    "messages",
    "engagement",
    "reach",
  ];
  static final List<String> priority = [
    'normal',
    "imp",
    "veryimp",
    "veryveryimp",
  ];
  static final List<String> shootingtype = [
    'video',
    "photography",
    "video_photography",
  ];
  static final List<String> monatgecategory = [
    'social_media_fhd', // FHD سوشيال ميديا
    'social_media_4k', // 4K سوشيال ميديا
    'landscape_fhd', // FHD 16:9
    'landscape_4k', // 4K 16:9
  ];
  static final List<String> shootingLocations = [
    'indoor_day',
    'outdoor_day',
    'indoor_night',
    'outdoor_night',
    'studio',
    'at_client',
    'other',
  ];
  static const List<String> statusList = [
    'status_under_revision',
    'status_ready_to_publish',
    'status_awaiting_manager',
    'status_approved',
    'status_scheduled',
    'status_task_completed',
    'status_published',
    'status_rejected',
    'status_in_edit',
    'status_edit_requested',
    'status_processing',
    'status_not_start_yet',
  ];

  /// الحالات الجارية (مهام نعمل عليها حالياً)
  static const List<String> statusListOngoing = [
    'status_not_start_yet',
    'status_processing',
    'status_under_revision',
    'status_in_edit',
    'status_edit_requested',
    'status_ready_to_publish',
    'status_awaiting_manager',
    'status_approved',
    'status_scheduled',
  ];

  /// الحالات المنتهية (لا تظهر افتراضياً في إدارة المهام)
  static const List<String> statusListEnded = [
    'status_task_completed',
    'status_published',
    'status_rejected',
  ];

  // --- مهام قسم الترويج (type == '0') — حالات خاصة ---
  static const String status_promotion_in_progress =
      'status_promotion_in_progress';
  static const String status_promotion_ad_platform_review =
      'status_promotion_ad_platform_review';
  static const String status_promotion_running = 'status_promotion_running';
  static const String status_promotion_finished =
      'status_promotion_finished';

  static const List<String> promotionTaskStatusList = [
    status_promotion_in_progress,
    status_promotion_ad_platform_review,
    status_promotion_running,
    status_promotion_finished,
  ];

  /// جارية في لوحة مهام الترويج (قبل انتهاء الترويج).
  static const List<String> promotionTaskStatusListOngoing = [
    status_promotion_in_progress,
    status_promotion_ad_platform_review,
    status_promotion_running,
  ];

  /// مهام ترويج قديمة ما زالت تستخدم حالات مسار النشر العام.
  static const Set<String> legacyPromotionOngoingTaskStatuses = {
    status_not_start_yet,
    status_processing,
    status_under_revision,
    status_in_edit,
    status_edit_requested,
    status_ready_to_publish,
    status_awaiting_manager,
    status_approved,
    status_scheduled,
  };

  static bool isOngoingStatus(String status) =>
      statusListOngoing.contains(status);

  static bool isEndedStatus(String status) =>
      statusListEnded.contains(status) ||
      status == status_promotion_finished;

  /// مهمة انتهت بنجاح (تسليم نهائي أو بيانات قديمة بـ [status_published]).
  static bool isTaskSuccessfulTerminalStatus(String status) =>
      status == status_task_completed || status == status_published;

  /// مهمة ترويج قديمة ما زالت تستخدم حالات أقسام أخرى.
  static bool isLegacyPromotionOngoingStatus(String status) =>
      legacyPromotionOngoingTaskStatuses.contains(status);

  static bool isTaskOngoing(TaskModel t) {
    if (t.type == '0') {
      if (promotionTaskStatusListOngoing.contains(t.status)) return true;
      if (t.status == status_promotion_finished) return false;
      if (statusListEnded.contains(t.status)) return false;
      return legacyPromotionOngoingTaskStatuses.contains(t.status);
    }
    return statusListOngoing.contains(t.status);
  }

  static bool isTaskEnded(TaskModel t) {
    if (t.type == '0') {
      if (t.status == status_promotion_finished) return true;
      return statusListEnded.contains(t.status);
    }
    return statusListEnded.contains(t.status);
  }

  /// Employee dashboard stat bucket index (0–3). Pass status from
  /// [FunHelper.canonicalStoredStatus]. Covers [statusList] and [promotionTaskStatusList].
  static const int employeeDashboardStatNeedsWork = 0;
  static const int employeeDashboardStatAwaiting = 1;
  static const int employeeDashboardStatCompleted = 2;
  static const int employeeDashboardStatRejected = 3;

  static int employeeDashboardStatIndex(String canonicalStatus) {
    final s = canonicalStatus.trim();
    if (s.isEmpty) return employeeDashboardStatNeedsWork;
    if (s == status_rejected) return employeeDashboardStatRejected;
    if (isTaskSuccessfulTerminalStatus(s) || s == status_promotion_finished) {
      return employeeDashboardStatCompleted;
    }
    const needsWork = <String>{
      status_not_start_yet,
      status_processing,
      status_in_edit,
      status_edit_requested,
      status_promotion_in_progress,
      status_promotion_running,
    };
    if (needsWork.contains(s)) return employeeDashboardStatNeedsWork;
    const awaiting = <String>{
      status_under_revision,
      status_ready_to_publish,
      status_awaiting_manager,
      status_approved,
      status_scheduled,
      status_promotion_ad_platform_review,
    };
    if (awaiting.contains(s)) return employeeDashboardStatAwaiting;
    return employeeDashboardStatNeedsWork;
  }

  static List<String> ongoingStatusFilterKeysForTaskType(String taskType) {
    if (taskType == '0') {
      return [
        '',
        ...promotionTaskStatusListOngoing,
        ...legacyPromotionOngoingTaskStatuses,
      ];
    }
    return ['', ...statusListOngoing];
  }

  /// عناصر قائمة «فلتر الحالة» في صفحة المهام الجارية حسب نوع القسم.
  static List<String> ongoingStatusFilterDropdownValues(String taskType) {
    if (taskType == '0') {
      return [
        ...promotionTaskStatusListOngoing,
        ...legacyPromotionOngoingTaskStatuses,
      ];
    }
    return List<String>.from(statusListOngoing);
  }

  static bool isSelectedOngoingFilterValid(String taskType, String selected) {
    if (selected.isEmpty) return true;
    final allowed = ongoingStatusFilterKeysForTaskType(taskType).toSet();
    return allowed.contains(selected);
  }

  /// Any "ongoing" status that can appear in the active task list (all departments + promotion).
  static bool isOngoingCombinedStatusFilter(String status) =>
      statusListOngoing.contains(status) ||
      promotionTaskStatusListOngoing.contains(status) ||
      legacyPromotionOngoingTaskStatuses.contains(status);

  /// Status filter options on the employee dashboard, scoped by department so promotion-only
  /// statuses are not mixed with the general workflow (avoids duplicate-looking labels).
  static List<String> employeeDashboardTaskStatusFilterDropdownValuesForDepartment(
    String? departmentRaw,
  ) {
    if (departmentRaw == null || departmentRaw.trim().isEmpty) {
      final seen = <String>{};
      final out = <String>[];
      for (final s in [
        ...promotionTaskStatusListOngoing,
        ...statusListOngoing,
      ]) {
        if (seen.add(s)) out.add(s);
      }
      if (seen.add(status_rejected)) out.add(status_rejected);
      return out;
    }
    if (matchesDepartment(departmentRaw, departmentPromotion)) {
      final seen = <String>{};
      final out = <String>[];
      for (final s in [
        ...promotionTaskStatusListOngoing,
        ...statusListOngoing,
      ]) {
        if (seen.add(s)) out.add(s);
      }
      if (seen.add(status_rejected)) out.add(status_rejected);
      return out;
    }
    return [...statusListOngoing, status_rejected];
  }

  /// Whether a saved or selected status is valid for this employee’s department filter.
  static bool isEmployeeDashboardStatusFilterAllowedForDepartment(
    String status,
    String? departmentRaw,
  ) {
    final s = status.trim();
    if (s.isEmpty) return true;
    if (departmentRaw == null || departmentRaw.trim().isEmpty) {
      final allowed = <String>{
        ...promotionTaskStatusListOngoing,
        ...statusListOngoing,
        ...legacyPromotionOngoingTaskStatuses,
        status_rejected,
      };
      return allowed.contains(s);
    }
    if (matchesDepartment(departmentRaw, departmentPromotion)) {
      final allowed = <String>{
        ...promotionTaskStatusListOngoing,
        ...statusListOngoing,
        status_rejected,
      };
      return allowed.contains(s);
    }
    return statusListOngoing.contains(s) || s == status_rejected;
  }

  static String prefsEmployeeDashboardTaskFiltersKey(String employeeId) =>
      'point_employee_dash_task_filters_v1_${employeeId.trim()}';

  static String prefsPublishFiltersKey(String employeeId) =>
      'point_publish_filters_v1_${employeeId.trim()}';

  /// Meta publish queue statuses used by the Publish filters UI.
  static const List<String> publishStatusFilterOptions = [
    'created',
    'queued',
    'scheduled',
    'publishing',
    'published',
    'failed',
    'cancelled',
  ];

  static const List<String> publishPlatformFilterOptions = [
    'facebook',
    'instagram',
  ];

  static const List<String> publishPostTypeFilterOptions = [
    'feed',
    'story',
    'reel',
  ];

  static const List<String> publishMediaTypeFilterOptions = [
    'photo',
    'video',
  ];

  /// Sentinel for posts with no linked client in the Publish client filter.
  static const String publishClientFilterNone = '__none__';

  /// Default status filter: every status except successful `published`.
  static List<String> get defaultPublishStatusFilters =>
      publishStatusFilterOptions.where((s) => s != 'published').toList();

  static List<String> endedStatusFilterKeysForTaskType(String taskType) {
    if (taskType == '0') {
      return ['', status_promotion_finished, ...statusListEnded];
    }
    return ['', ...statusListEnded];
  }

  static List<String> endedStatusFilterDropdownValues(String taskType) {
    if (taskType == '0') {
      return [status_promotion_finished, ...statusListEnded];
    }
    return List<String>.from(statusListEnded);
  }

  static bool isSelectedEndedFilterValid(String taskType, String selected) {
    if (selected.isEmpty) return true;
    return endedStatusFilterKeysForTaskType(taskType).contains(selected);
  }
  static const List<String> promations = [
    'no_promotion',
    'under_promotion',

    'end_promotion',
  ];
  

  //tasks
  static const String status_under_revision = "status_under_revision";
  static const String status_ready_to_publish = "status_ready_to_publish";
  static const String status_approved = "status_approved";
  static const String status_scheduled = "status_scheduled";
  static const String status_processing = "status_processing";

  /// مهمة اكتملت بعد تسليم العمل النهائي (يُفضّل هذا بدلاً من [status_published] للمهام).
  static const String status_task_completed = "status_task_completed";

  /// محتوى «تم النشر» أو مهام قديمة وُسمت بهذه الحالة قبل [status_task_completed].
  static const String status_published = "status_published";
  static const String status_rejected = "status_rejected";
  static const String status_in_edit = "status_in_edit";
  static const String status_edit_requested = "status_edit_requested";
  static const String status_not_start_yet = "status_not_start_yet";
  static const String status_awaiting_manager = "status_awaiting_manager";
  static const String finalWorkTypePost = 'final_work_post';
  static const String finalWorkTypeStory = 'final_work_story';
  static const String finalWorkTypeVideoReel = 'final_work_video_reel';
  /// PDFs, Office docs, and similar (Library folder: documents).
  static const String finalWorkTypeDocuments = 'final_work_documents';
  /// Saved on the task only; excluded from the Library (not post/story/video).
  static const String finalWorkTypeOther = 'final_work_other';
  static const List<String> finalWorkTypes = [
    finalWorkTypePost,
    finalWorkTypeStory,
    finalWorkTypeVideoReel,
    finalWorkTypeDocuments,
    finalWorkTypeOther,
  ];

  //user
  static const String status_user_pending = "status_user_pending";

  static var contentTypes = [
    'monthly_content_plan', // خطة محتوى شهري
    'marketing_plan', // خطة تسويقية
    'video_script', // سكربت فديو
    'design_idea', // فكرة تصميم
    'other', // أخري
  ];
  // Semantic department keys (preferred in code).
  static const String departmentPromotion = 'promotion';
  static const String departmentDesign = 'design';
  static const String departmentPhotography = 'photography';
  static const String departmentContentWriting = 'content-writing';
  static const String departmentMontage = 'montage';
  static const String departmentPublishing = 'publishing';
  static const String departmentProgramming = 'programming';
  static const String departmentAdministration = 'administration';

  static const String programmingUpdateStatusPending = 'pending';
  static const String programmingUpdateStatusConverted = 'converted';

  static const List<String> departmentSlugs = [
    departmentPromotion,
    departmentDesign,
    departmentPhotography,
    departmentContentWriting,
    departmentMontage,
    departmentPublishing,
    departmentProgramming,
    departmentAdministration,
  ];

  /// Canonical department values for new writes.
  static const List<String> departments = departmentSlugs;

  /// Converts stored department value to semantic key.
  static String normalizeDepartment(String? department) {
    final raw = (department ?? '').trim();
    if (raw.isEmpty) return '';
    final value = raw.toLowerCase();
    if (departmentSlugs.contains(value)) return value;

    // Latin / shorthand (legacy or manual entry)
    const Map<String, String> aliases = {
      'promotions': departmentPromotion,
      'promo': departmentPromotion,
      'publishing': departmentPublishing,
      'publish': departmentPublishing,
      'administrative': departmentAdministration,
      'administration': departmentAdministration,
      'admin': departmentAdministration,
    };
    if (aliases.containsKey(value)) return aliases[value]!;

    // Arabic or mixed labels often stored in Firestore instead of slugs
    if (raw.contains('إداري') ||
        raw.contains('إدارية') ||
        raw.contains('قسم إداري') ||
        raw.contains('الإداري')) {
      return departmentAdministration;
    }
    if (raw.contains('ترويج')) return departmentPromotion;
    if (raw.contains('النشر') || raw.contains('قسم النشر')) {
      return departmentPublishing;
    }
    if (value.contains('promotion') || value.contains('promo')) {
      return departmentPromotion;
    }
    if (value.contains('publishing') || value.contains('publish')) {
      return departmentPublishing;
    }
    if (value.contains('administration') || value.contains('administrative')) {
      return departmentAdministration;
    }

    return '';
  }

  /// Preferred translation key for UI labels.
  static String semanticDepartmentLabelKey(String? department) {
    final normalized = normalizeDepartment(department);
    if (normalized.isEmpty) {
      return 'department.$departmentPromotion';
    }
    return 'department.$normalized';
  }

  static bool matchesDepartment(String? value, String semanticDepartment) =>
      normalizeDepartment(value) == normalizeDepartment(semanticDepartment);

  /// Normalizes, de-duplicates, and keeps only known department slugs.
  static List<String> normalizeDepartments(Iterable<String?> raw) {
    final out = <String>[];
    final seen = <String>{};
    for (final r in raw) {
      final n = normalizeDepartment(r);
      if (n.isEmpty || seen.contains(n)) continue;
      seen.add(n);
      out.add(n);
    }
    return out;
  }

  /// True if [a] and [b] share at least one normalized department slug.
  static bool departmentListsOverlap(Iterable<String> a, Iterable<String> b) {
    final sa = normalizeDepartments(a);
    final sb = normalizeDepartments(b);
    if (sa.isEmpty || sb.isEmpty) return false;
    final setB = sb.toSet();
    for (final x in sa) {
      if (setB.contains(x)) return true;
    }
    return false;
  }

  /// أدوار تُضاف تلقائياً إلى كل مجموعات أقسام الدردشة (مدير / مشرف).
  static bool isChatElevatedRole(dynamic role) {
    final r = role?.toString().trim().toLowerCase();
    return r == 'admin' || r == 'supervisor';
  }

  static var designTypes = [
    'monthly_plan_design', // تصميم خطة شهرية
    'single_design', // تصميم مفرد
    'urgent_design', // عاجل
  ];

  static var interestsList = [
    'تجميل',
    'تكنولوجيا',
    'رياضة',
    'سفر',
    'تعليم',
    'مطاعم',
  ];

  /// خريطة دولة → قائمة مدنها (لربط المدن بالبلد المختار)
  static final Map<String, List<String>> countryCitiesMap = {
    'العراق': [
      'بغداد',
      'البصرة',
      'الموصل',
      'أربيل',
      'الناصرية',
      'النجف',
      'كربلاء',
      'السليمانية',
      'دهوك',
      'العمارة',
      'الكوت',
      'الحلة',
      'الرمادي',
      'تكريت',
      'سامراء',
      'ديالى',
    ],

    'مصر': [
      'القاهرة',
      'الإسكندرية',
      'الجيزة',
      'شرم الشيخ',
      'الأقصر',
      'أسوان',
      'طنطا',
      'المنصورة',
      'الزقازيق',
      'أسيوط',
      'سوهاج',
      'بورسعيد',
      'الإسماعيلية',
      'السويس',
      'دمياط',
    ],

    'السعودية': [
      'الرياض',
      'جدة',
      'مكة',
      'المدينة',
      'الدمام',
      'الخبر',
      'تبوك',
      'بريدة',
      'حائل',
      'أبها',
      'خميس مشيط',
      'نجران',
      'الجبيل',
      'الطائف',
      'ينبع',
      'عرعر',
      'سكاكا',
    ],

    'السودان': [
      'الخرطوم',
      'أم درمان',
      'بورتسودان',
      'كسلا',
      'مدني',
      'الأبيض',
      'الفاشر',
      'نيالا',
      'عطبرة',
      'دنقلا',
    ],

    'تونس': [
      'تونس',
      'صفاقس',
      'سوسة',
      'القيروان',
      'بنزرت',
      'قابس',
      'قفصة',
      'مدنين',
      'نابل',
      'المنستير',
    ],

    'الجزائر': [
      'الجزائر',
      'وهران',
      'قسنطينة',
      'عنابة',
      'سيدي بلعباس',
      'باتنة',
      'بجاية',
      'تلمسان',
      'ورقلة',
      'البليدة',
      'تيزي وزو',
    ],

    'ليبيا': [
      'طرابلس',
      'بنغازي',
      'مصراتة',
      'طبرق',
      'سبها',
      'البيضاء',
      'سرت',
      'الزاوية',
      'درنة',
      'غريان',
    ],

    'موريتانيا': ['نواكشوط', 'نواذيبو', 'كيهيدي', 'روصو', 'أطار', 'النعمة'],

    'المغرب': [
      'الرباط',
      'الدار البيضاء',
      'فاس',
      'مراكش',
      'طنجة',
      'أغادير',
      'وجدة',
      'مكناس',
      'تطوان',
      'القنيطرة',
      'العيون',
    ],

    'جيبوتي': ['جيبوتي', 'علي صابح', 'دخيل', 'تاجورة', 'أوبوك'],

    'الصومال': [
      'مقديشو',
      'هرجيسا',
      'بوساسو',
      'مركة',
      'كيسمايو',
      'بلدوين',
      'جالكعيو',
    ],

    'سوريا': [
      'دمشق',
      'حلب',
      'حمص',
      'حماة',
      'اللاذقية',
      'طرطوس',
      'درعا',
      'السويداء',
      'القامشلي',
      'دير الزور',
      'الرقة',
    ],

    'لبنان': [
      'بيروت',
      'طرابلس',
      'صيدا',
      'صور',
      'زحلة',
      'جبيل',
      'بعلبك',
      'جونية',
      'النبطية',
    ],

    'فلسطين': [
      'القدس',
      'غزة',
      'رام الله',
      'نابلس',
      'الخليل',
      'بيت لحم',
      'جنين',
      'طولكرم',
      'قلقيلية',
      'رفح',
    ],

    'اليمن': [
      'صنعاء',
      'عدن',
      'تعز',
      'الحديدة',
      'المكلا',
      'إب',
      'ذمار',
      'سيئون',
      'البيضاء',
      'صعدة',
    ],

    'قطر': [
      'الدوحة',
      'الريان',
      'الخور',
      'الوكرة',
      'أم صلال',
      'الظعاين',
      'الشمال',
    ],

    'الكويت': [
      'الكويت',
      'الجهراء',
      'الأحمدي',
      'حولي',
      'الفروانية',
      'مبارك الكبير',
    ],

    'عُمان': [
      'مسقط',
      'صلالة',
      'صحار',
      'نزوى',
      'صور',
      'الرستاق',
      'عبري',
      'البريمي',
    ],

    'الإمارات': [
      'أبوظبي',
      'دبي',
      'الشارقة',
      'عجمان',
      'رأس الخيمة',
      'الفجيرة',
      'أم القيوين',
      'العين',
      'خورفكان',
      'دبا الفجيرة',
    ],

    'الأردن': [
      'عمّان',
      'الزرقاء',
      'إربد',
      'العقبة',
      'الكرك',
      'السلط',
      'مادبا',
      'معان',
      'جرش',
      'عجلون',
    ],

    'البحرين': [
      'المنامة',
      'المحرق',
      'الرفاع',
      'مدينة حمد',
      'مدينة عيسى',
      'سترة',
    ],

    'جزر القمر': ['موروني', 'متسامودو', 'فومبوني', 'دوموني'],
  };

  /// يرجع قائمة مدن مدمجة (بدون تكرار) لجميع الدول المختارة، أو قائمة فارغة إذا لم يُختر أي بلد.
  static List<String> getCitiesForCountries(List<String> countryNames) {
    if (countryNames.isEmpty) return [];
    final Set<String> seen = {};
    final List<String> result = [];
    for (final country in countryNames) {
      final cities = countryCitiesMap[country];
      if (cities != null) {
        for (final city in cities) {
          if (seen.add(city)) result.add(city);
        }
      }
    }
    return result;
  }

  static var specialist = [
    'تجميل',
    'تكنولوجيا',
    'رياضة',
    'سفر',
    'تعليم',
    'مطاعم',
  ];
  static var tasktype = ['تصميم طباعي ', 'تصميم سوشيل ميديا', 'اخري'];
}
