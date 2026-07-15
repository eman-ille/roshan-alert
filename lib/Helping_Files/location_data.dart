/// Single source of truth for Pakistan location data used across the app —
/// currently by both Onboarding (first-time pick) and Settings (change
/// later). Keeping the Province -> City -> Area mapping here means both
/// screens automatically stay in sync — update coverage in ONE place.
class LocationData {
  LocationData._();

  static const Map<String, List<String>> provinceCities = {
    'Punjab': [
      'Lahore',
      'Faisalabad',
      'Sialkot',
      'Islamabad',
      'Rawalpindi',
      'Multan',
      'Gujranwala',
    ],
    'Sindh': ['Karachi', 'Hyderabad', 'Sukkur', 'Larkana'],
    'KPK': ['Peshawar', 'Abbottabad', 'Mardan', 'Swat'],
    'Balochistan': ['Quetta', 'Gwadar', 'Turbat', 'Sibi'],
  };

  // Real city -> area/locality mapping, so the Area dropdown shows actual
  // neighborhoods instead of placeholder text. Coverage is intentionally
  // light for now (a handful of well-known localities per city) — extend
  // per-city as real feeder/area data becomes available from the scraper
  // backend.
  static const Map<String, List<String>> cityAreas = {
    // Punjab
    'Lahore': ['Gulberg', 'DHA', 'Model Town', 'Johar Town', 'Faisal Town', 'Township', 'Iqbal Town', 'Bahria Town', 'Cantt', 'Shalimar', 'Wapda Town', 'Garden Town'],
    'Faisalabad': ['Madina Town', 'Peoples Colony', 'Gulberg', 'Jinnah Colony', 'D Ground', 'Samanabad'],
    'Sialkot': ['Cantt', 'Kutchery Road', 'Paris Road', 'Model Town', 'Rangpura'],
    'Islamabad': ['F-6', 'F-7', 'F-8', 'F-10', 'F-11', 'G-9', 'G-10', 'G-11', 'Blue Area', 'Bahria Town'],
    'Rawalpindi': ['Satellite Town', 'Saddar', 'Cantt', 'Bahria Town', 'Chaklala', 'Westridge'],
    'Multan': ['Cantt', 'Gulgasht Colony', "Shah Rukn-e-Alam", 'Bosan Road', 'Model Town'],
    'Gujranwala': ['Model Town', 'Satellite Town', 'Civil Lines', "People's Colony"],
    // Sindh
    'Karachi': ['Clifton', 'DHA', 'Gulshan-e-Iqbal', 'North Nazimabad', 'Saddar', 'Malir', 'Korangi'],
    'Hyderabad': ['Latifabad', 'Qasimabad', 'City Area', 'Hussainabad'],
    'Sukkur': ['Military Road', 'Barrage Colony', 'Shikarpur Road'],
    'Larkana': ['Old Larkana', 'Model Colony'],
    // KPK
    'Peshawar': ['University Town', 'Hayatabad', 'Cantt', 'Gulbahar'],
    'Abbottabad': ['Jinnahabad', 'Mandian', 'Supply Bazaar'],
    'Mardan': ['Bank Road', 'Cantt Area'],
    'Swat': ['Mingora', 'Saidu Sharif'],
    // Balochistan
    'Quetta': ['Jinnah Town', 'Satellite Town', 'Cantt', 'Sariab Road'],
    'Gwadar': ['New Town', 'Old Town'],
    'Turbat': ['City Center'],
    'Sibi': ['City Area'],
  };

  static List<String> get provinces => provinceCities.keys.toList();

  static List<String> citiesFor(String? province) =>
      province == null ? const [] : (provinceCities[province] ?? const []);

  static List<String> areasFor(String? city) =>
      city == null ? const [] : (cityAreas[city] ?? const []);
}