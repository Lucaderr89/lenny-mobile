/// Come si manda il driver a una tappa con Google Maps (l'app che usano
/// davvero). Logica pura, senza plugin, cosi' si prova con un test.
///
/// Un solo principio: Maps deve aprirsi gia' in navigazione verso il
/// posto giusto. Se l'ordine ha le coordinate si usano quelle; se non le
/// ha (COAL fuori riquadro, geocoding fallito) si passa l'indirizzo in
/// chiaro, che Maps risolve da solo. Prima si navigava verso 0,0.
class NavigazioneEsterna {
  NavigazioneEsterna._();

  /// Destinazione per Maps: "lat,lng" oppure l'indirizzo in chiaro.
  /// Vuota se non c'e' niente di utilizzabile.
  static String destinazione(double lat, double lng, String indirizzo) {
    final conCoordinate = lat.abs() > 0.0001 || lng.abs() > 0.0001;
    if (conCoordinate) {
      return '${lat.toStringAsFixed(6)},${lng.toStringAsFixed(6)}';
    }
    return indirizzo.trim();
  }

  /// Schema nativo di Google Maps su Android: navigazione gia' avviata.
  static Uri androidNavigazione(String dest) =>
      Uri.parse('google.navigation:q=${Uri.encodeComponent(dest)}&mode=d');

  /// Schema dell'app Google Maps su iPhone (va dichiarato in Info.plist
  /// sotto LSApplicationQueriesSchemes, altrimenti il sistema dice sempre
  /// "non apribile").
  static Uri iosGoogleMaps(String dest) => Uri.parse(
    'comgooglemaps://?daddr=${Uri.encodeComponent(dest)}&directionsmode=driving',
  );

  /// Link universale: su un telefono con Google Maps apre l'app, senza
  /// apre Maps nel browser. Vale per entrambi i sistemi ed e' l'ultimo
  /// ripiego: non lascia mai il driver senza indicazioni.
  static Uri linkUniversale(String dest) => Uri.parse(
    'https://www.google.com/maps/dir/?api=1'
    '&destination=${Uri.encodeComponent(dest)}&travelmode=driving',
  );
}
