import 'package:point/config/app_config.dart';

class StorageKeys {
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
    'status_approved',
    'status_scheduled',
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
    'status_scheduled',
  ];

  /// الحالات المنتهية (لا تظهر افتراضياً في إدارة المهام)
  static const List<String> statusListEnded = [
    'status_approved',
    'status_published',
    'status_rejected',
  ];

  static bool isOngoingStatus(String status) =>
      statusListOngoing.contains(status);
  static bool isEndedStatus(String status) => statusListEnded.contains(status);
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

  static const String status_published = "status_published";
  static const String status_rejected = "status_rejected";
  static const String status_in_edit = "status_in_edit";
  static const String status_edit_requested = "status_edit_requested";
  static const String status_not_start_yet = "status_not_start_yet";

  //user
  static const String status_user_pending = "status_user_pending";

  static var contentTypes = [
    'monthly_content_plan', // خطة محتوى شهري
    'marketing_plan', // خطة تسويقية
    'video_script', // سكربت فديو
    'design_idea', // فكرة تصميم
    'other', // أخري
  ];
  static var departments = [
    'cat1',
    'cat2',
    'cat3',
    'cat4',
    'cat5',
    'cat6',
    'cat7',
  ];

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
