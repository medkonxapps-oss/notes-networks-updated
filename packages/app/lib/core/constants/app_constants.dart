class AppConstants {
  AppConstants._();
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static const List<String> boards = [
    'CBSE', 'ICSE', 'State Board', 'IB', 'Cambridge (IGCSE)', 'Other',
  ];

  static const List<String> classLevels = [
    'Class 6', 'Class 7', 'Class 8', 'Class 9', 'Class 10',
    'Class 11', 'Class 12', 'JEE/NEET Dropper',
    'UG 1st Year', 'UG 2nd Year', 'UG 3rd Year', 'UG Final Year',
    'PG', 'Competitive Exam',
  ];

  static const List<String> subjects = [
    'Mathematics', 'Physics', 'Chemistry', 'Biology',
    'English', 'Hindi', 'History', 'Geography', 'Economics',
    'Political Science', 'Computer Science', 'Accounts',
    'Business Studies', 'Psychology', 'Sociology', 'Philosophy',
    'Physical Education', 'Fine Arts', 'Music', 'Sanskrit',
    'JEE Maths', 'JEE Physics', 'JEE Chemistry',
    'NEET Biology', 'UPSC GS', 'CA Foundation', 'GATE',
  ];

  static const List<String> reportReasons = [
    'inappropriate', 'spam', 'copyright', 'misleading', 'other',
  ];

  static const List<String> folderColors = [
    '#4F46E5', '#10B981', '#F59E0B', '#EF4444',
    '#8B5CF6', '#06B6D4', '#EC4899', '#84CC16',
  ];

  static const Map<String, int> pointsTable = {
    'upload': 50,
    'like_received': 5,
    'save_received': 10,
    'streak_bonus': 25,
    'first_upload': 100,
    'verification_bonus': 200,
  };
}
