/// A building or area of the USEK main campus (Kaslik) that students can pick
/// as the location of a report, instead of typing it.
class CampusPlace {
  const CampusPlace(this.name, [this.hint]);

  final String name;

  /// What the place is known for, to help students recognise it.
  final String? hint;
}

/// USEK Kaslik buildings and areas. Descriptions come from public sources
/// (USEK website, Wikipedia) and are partial; correct them with the campus
/// information desk before a real launch. Students can still type any
/// location that is not in this list (FR6).
const campusPlaces = <CampusPlace>[
  CampusPlace('Building A', 'Financial Aid Office'),
  CampusPlace('Building AA', 'Administration'),
  CampusPlace('Building AB'),
  CampusPlace('Building AC', 'Student services'),
  CampusPlace('Building AM'),
  CampusPlace('Building B'),
  CampusPlace('Building C', 'Arts and Architecture'),
  CampusPlace('Building D', 'Business School, Career Services'),
  CampusPlace('Building E', 'Agronomy'),
  CampusPlace('Building F', 'Residence'),
  CampusPlace('Building G', 'Administrative and technical offices'),
  CampusPlace('Building H'),
  CampusPlace('Building I', 'Sports department, tennis courts'),
  CampusPlace('Library'),
  CampusPlace('Cafeteria'),
  CampusPlace('Amphitheater'),
  CampusPlace('Infirmary'),
  CampusPlace('Parking'),
  CampusPlace('Online services', 'Student portal, e-learning'),
];

/// The building or area part of a stored location, e.g. "Building B" for
/// "Building B, Lab 3".
String placeOf(String location) => location.split(',').first.trim();
