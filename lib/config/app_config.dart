class AppConfig {
  static const String googleMapsApiKey = 'AIzaSyDtOY4mSwiJlUlb51SAcH7xhgyeV-0hFt4';
  
  // Places API Configuration
  static const String placesApiBaseUrl = 'https://maps.googleapis.com/maps/api/place';
  static const String placesApiKey = googleMapsApiKey; // Using the same key for now
  
  // General Configuration
  static const bool isDevelopment = true;
  static const String apiBaseUrl = 'https://maps.googleapis.com/maps/api';
  
  // Google Maps Configuration
  static const List<String> placeTypes = ['establishment', 'geocode'];
  static const List<String> placeFields = ['geometry'];
} 