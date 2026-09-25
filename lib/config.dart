/// كل الثوابت القابلة للضبط بمكان واحد.
class AppConfig {
  AppConfig._();

  /// أسماء ألبومات الواتساب (اسم المجلد كما يظهر بـ MediaStore).
  static const whatsappAlbumNames = <String>[
    'WhatsApp Images',
    'WhatsApp Business Images',
  ];

  /// أي صورة احتمالها من المودل فوق هالعتبة بتنعدّ معايدة.
  static const greetingThreshold = 0.7;

  /// أقصى فرق (عدد بتات من 64) بين بصمتين لنعتبرهم نفس الصورة تقريبًا.
  static const hashMatchDistance = 6;

  /// مسار ملف المودل ضمن الأصول.
  static const modelAsset = 'assets/models/greeting_classifier.tflite';

  /// حجم مدخل المودل (مربع).
  static const modelInputSize = 224;

  /// حجم الصورة المصغرة المستخدمة للبصمة والمودل والعرض بالشبكة.
  static const thumbnailSize = 256;

  /// كم صورة نجيب من المعرض بكل دفعة.
  static const galleryPageSize = 100;

  /// اسم ملف قاعدة البيانات.
  static const databaseName = 'greeting_cleaner.db';

  /// كم شهر لورا نعرض بمنتقي الشهور.
  static const monthsBack = 24;
}
