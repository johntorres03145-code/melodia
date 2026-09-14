/// Saludo según la hora del día (porte de `newCustomFunction` del diseño FlutterFlow).
String greetingByHour(DateTime now) {
  final hour = now.hour;
  if (hour >= 5 && hour < 12) {
    return 'Good morning';
  } else if (hour >= 12 && hour < 19) {
    return 'Good afternoon';
  } else if (hour >= 19 && hour < 24) {
    return 'Good evening';
  } else {
    return 'Good night';
  }
}