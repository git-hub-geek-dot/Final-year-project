import 'dart:math';

class GoaCities {
  // Coordinates (latitude, longitude) for all Goa cities and towns
  static const Map<String, List<double>> coordinates = {
    // North Goa - Tiswadi Taluka
    'panjim': [15.4909, 73.8278],
    'panaji': [15.4909, 73.8278],
    'taleigao': [15.4700, 73.8300],
    'ribandar': [15.4833, 73.8500],
    'old goa': [15.5025, 73.9117],
    'ella': [15.4833, 73.8167],
    
    // North Goa - Bardez Taluka
    'mapusa': [15.5900, 73.8100],
    'calangute': [15.5447, 73.7561],
    'candolim': [15.5197, 73.7619],
    'anjuna': [15.5733, 73.7394],
    'baga': [15.5556, 73.7517],
    'sinquerim': [15.5050, 73.7700],
    'saligao': [15.5550, 73.7800],
    'siolim': [15.6000, 73.7667],
    'assagao': [15.5900, 73.7500],
    'aldona': [15.5950, 73.8150],
    'penha de franca': [15.5333, 73.8167],
    
    // North Goa - Pernem Taluka
    'pernem': [15.7211, 73.7928],
    'arambol': [15.6850, 73.7050],
    'mandrem': [15.6650, 73.7250],
    'morjim': [15.6333, 73.7333],
    'querim': [15.7167, 73.6833],
    
    // North Goa - Bicholim Taluka
    'bicholim': [15.5900, 73.9500],
    'mayem': [15.5833, 73.9167],
    'pale': [15.6167, 73.9500],
    
    // North Goa - Satari Taluka
    'valpoi': [15.5333, 74.1333],
    'sanquelim': [15.5333, 73.9833],
    'keri': [15.5167, 74.2333],
    
    // North Goa - Ponda Taluka
    'ponda': [15.4000, 74.0167],
    'farmagudi': [15.4333, 73.9500],
    'borim': [15.3833, 73.9667],
    'priol': [15.4500, 73.9333],
    'porvorim': [15.5333, 73.8167],
    
    // South Goa - Mormugao Taluka
    'vasco da gama': [15.3983, 73.8158],
    'vasco': [15.3983, 73.8158],
    'dabolim': [15.3800, 73.8333],
    'bogmalo': [15.3667, 73.8333],
    'cansaulim': [15.3500, 73.9167],
    'cortalim': [15.4167, 73.9000],
    
    // South Goa - Salcete Taluka
    'margao': [15.2700, 73.9500],
    'madgaon': [15.2700, 73.9500],
    'navelim': [15.2833, 73.9333],
    'benaulim': [15.2583, 73.9333],
    'colva': [15.2800, 73.9133],
    'nuvem': [15.2833, 73.9667],
    'raia': [15.2833, 73.9833],
    'curtorim': [15.2667, 74.0000],
    'chinchinim': [15.2000, 73.9667],
    'cuncolim': [15.1833, 73.9833],
    'loutolim': [15.3000, 74.0167],
    'majorda': [15.3167, 73.9167],
    'sancoale': [15.3667, 73.8667],
    'chicalim': [15.4000, 73.8333],
    
    // South Goa - Quepem Taluka
    'quepem': [15.2167, 74.0833],
    'paroda': [15.2333, 74.0500],
    'balli': [15.2500, 74.0667],
    
    // South Goa - Canacona Taluka
    'canacona': [15.0167, 74.0500],
    'palolem': [15.0100, 74.0233],
    'agonda': [15.0500, 74.0000],
    'patnem': [15.0050, 74.0350],
    'chaudi': [15.0167, 74.0667],
    
    // South Goa - Sanguem Taluka
    'sanguem': [15.2333, 74.1833],
    'rivona': [15.2167, 74.1333],
    'curchorem': [15.2667, 74.1000],
    
    // South Goa - Dharbandora Taluka
    'mollem': [15.4167, 74.2333],
  };

  /// Calculate distance between two cities in kilometers using Haversine formula
  static double calculateDistance(String city1, String city2) {
    final coords1 = coordinates[city1.toLowerCase().trim()];
    final coords2 = coordinates[city2.toLowerCase().trim()];
    
    if (coords1 == null || coords2 == null) {
      return double.infinity; // Unknown cities go to the end
    }

    const double earthRadiusKm = 6371.0;
    
    final lat1 = coords1[0] * pi / 180;
    final lat2 = coords2[0] * pi / 180;
    final dLat = (coords2[0] - coords1[0]) * pi / 180;
    final dLon = (coords2[1] - coords1[1]) * pi / 180;

    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadiusKm * c;
  }

  /// Check if a city is known
  static bool isKnownCity(String city) {
    return coordinates.containsKey(city.toLowerCase().trim());
  }

  /// Get all city names
  static List<String> getAllCities() {
    final cities = coordinates.keys.toList();
    cities.sort();
    return cities;
  }
}
