/// 🔧 ثوابت النظام المركزية
class ApexConstants {
  // 🚨 المنفذ الرئيسي - تم تغييره من 8080 إلى منفذ عالي لتجنب الحظر
  static const int transferPort = 45678;
  
  // منافذ احتياطية في حال فشل المنفذ الأساسي
  static const List<int> fallbackPorts = [45679, 45680, 45681];
}
