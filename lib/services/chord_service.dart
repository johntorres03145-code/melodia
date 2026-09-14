import 'package:hive/hive.dart';

/// Servicio de acordes: base de datos local + caché en Hive.
class ChordService {
  static const _boxName = 'chordCache';
  static Box<Map>? _box;

  /// Base de datos local de acordes populares.
  static const _database = <String, List<String>>{
    // ─── Pop internacional ───
    'let it be': ['C', 'G', 'Am', 'F'],
    'hey jude': ['F', 'C', 'Bb', 'F'],
    'someone like you': ['A', 'E', 'F#m', 'D'],
    'perfect': ['G', 'Em', 'C', 'D'],
    'all of me': ['Em', 'C', 'G', 'D'],
    'shape of you': ['C#m', 'F#m', 'A', 'B'],
    'despacito': ['Bm', 'G', 'D', 'A'],
    'bohemian rhapsody': ['Bb', 'Gm', 'Cm', 'F'],
    'stairway to heaven': ['Am', 'C', 'D', 'F'],
    'hotel california': ['Bm', 'F#7', 'A', 'E'],
    'wonderwall': ['Em7', 'G', 'D', 'A7sus4'],
    'imagine': ['C', 'F', 'Am', 'Dm'],
    'yesterday': ['F', 'Em7', 'A7', 'Dm'],
    'smells like teen spirit': ['F5', 'Bb5', 'Ab5', 'Db5'],
    'billie jean': ['F#m', 'B', 'E', 'A'],
    'thriller': ['Cm', 'Fm', 'Bb', 'Eb'],
    'superstition': ['Eb', 'Bb', 'Ab', 'Eb'],
    'sweet child o mine': ['D', 'C', 'G', 'D'],
    'back in black': ['A', 'D', 'E', 'A'],
    // ─── Rock ───
    'sweet home alabama': ['D', 'C', 'G', 'D'],
    'free bird': ['G', 'D', 'F', 'C'],
    'wonderful tonight': ['G', 'C', 'D', 'G'],
    'livin on a prayer': ['Em', 'C', 'D', 'G'],
    'dont stop believin': ['E', 'B', 'C#m', 'A'],
    'rock you like a hurricane': ['E', 'A', 'B', 'E'],
    'every breath you take': ['Ab', 'Fm', 'Db', 'Eb'],
    'with or without you': ['D', 'A', 'Bm', 'G'],
    // ─── Pop actual ───
    'bad guy': ['Gm', 'D', 'Eb', 'D'],
    'blinding lights': ['Fm', 'Ab', 'Eb', 'Bb'],
    'watermelon sugar': ['D', 'G', 'Bm', 'A'],
    'levitating': ['Bm', 'G', 'D', 'A'],
    'dont start now': ['Bm', 'G', 'D', 'A'],
    'circles': ['Am', 'F', 'C', 'G'],
    'dynamite': ['B', 'G#m', 'E', 'F#'],
    'stay': ['F', 'C', 'Am', 'G'],
    'heat waves': ['Am', 'C', 'G', 'F'],
    'easy on me': ['F', 'Am', 'Dm', 'Bb'],
    'peaches': ['C', 'F', 'Am', 'G'],
    'good 4 u': ['D', 'Bm', 'G', 'A'],
    'kiss me more': ['F', 'Am', 'Dm', 'Bb'],
    'montero': ['Am', 'F', 'C', 'G'],
    'industry baby': ['F', 'Am', 'Dm', 'Bb'],
    'happier than ever': ['Eb', 'Ab', 'Bb', 'Eb'],
    'sweater weather': ['Am', 'F', 'C', 'G'],
    'locked out of heaven': ['G', 'Em', 'C', 'D'],
    'counting stars': ['Am', 'C', 'G', 'Em'],
    'sugar': ['G', 'D', 'Em', 'C'],
    'uptown funk': ['Dm', 'Gm', 'C', 'F'],
    'thinking out loud': ['D', 'A', 'Bm', 'G'],
    'love yourself': ['C', 'G', 'Am', 'F'],
    'closer': ['Em', 'C', 'G', 'D'],
    'see you again': ['C', 'G', 'Am', 'F'],
    'rude': ['Am', 'F', 'C', 'G'],
    'shut up and dance': ['Em', 'C', 'G', 'D'],
    'take on me': ['D', 'Bm', 'G', 'A'],
    'never gonna give you up': ['D', 'A', 'Bm', 'G'],
    'wake me up': ['Am', 'C', 'G', 'F'],
    'pompeii': ['Am', 'F', 'C', 'G'],
    'radioactive': ['Am', 'C', 'G', 'F'],
    'demons': ['Am', 'F', 'C', 'G'],
    'believer': ['Am', 'F', 'C', 'G'],
    'as it was': ['Am', 'D', 'G', 'C'],
    'matilda': ['G', 'Em', 'C', 'D'],
    'glimpse of us': ['Am', 'F', 'C', 'G'],
    'unholy': ['Am', 'F', 'C', 'G'],
    'antihero': ['C', 'G', 'Am', 'F'],
    'flowers': ['Am', 'Dm', 'G', 'C'],
    'cruel summer': ['F', 'Am', 'Dm', 'Bb'],
    'tattoo': ['F', 'Am', 'Bb', 'C'],
    'slow it down': ['G', 'Em', 'C', 'D'],

    // ─── Pop en español ───
    'la bamba': ['C', 'F', 'G', 'C'],
    'bailando': ['Em', 'C', 'G', 'D'],
    'me rehuso': ['C', 'G', 'F', 'Em'],
    'robarte un beso': ['C', 'G', 'Am', 'F'],
    'propuesta indecente': ['Am', 'F', 'C', 'G'],
    'duele el corazon': ['G', 'Em', 'C', 'D'],
    'chantaje': ['Am', 'F', 'C', 'G'],
    'dura': ['G', 'D', 'Em', 'C'],
    'te bote': ['Am', 'F', 'C', 'G'],
    'pam pam': ['Am', 'F', 'C', 'G'],
    'vivir mi vida': ['Am', 'F', 'C', 'G'],
    'solamente tu': ['C', 'G', 'Am', 'F'],
    'otra vez': ['Am', 'F', 'C', 'G'],
    'el perdedor': ['Am', 'F', 'C', 'G'],
    'la tormenta': ['Am', 'F', 'C', 'G'],
    'mi persona favorita': ['C', 'G', 'Am', 'F'],
    'lo pasado pasado': ['Am', 'F', 'C', 'G'],

    // ─── Reggaetón / Urbano ───
    'dale don dale': ['Am', 'F', 'C', 'G'],
    'gasolina': ['F#', 'D#m', 'A#m', 'C#'],
    'rockefeller skank': ['G', 'C', 'D', 'G'],
    'si tu lo dejas': ['C', 'G', 'Am', 'F'],
    'safaera': ['Am', 'F', 'C', 'G'],
    'dakiti': ['C', 'Am', 'Em', 'D'],
    'la cancion': ['Am', 'F', 'C', 'G'],
    'mi cama': ['Am', 'F', 'C', 'G'],
    'no brakes': ['Am', 'F', 'C', 'G'],
    'sesiones': ['Am', 'F', 'C', 'G'],
    'noche de sexo': ['Am', 'F', 'C', 'G'],
    'travesuras': ['Am', 'F', 'C', 'G'],
    '506': ['Am', 'F', 'C', 'G'],
    'odio': ['Am', 'F', 'C', 'G'],
    'vantablack': ['Am', 'F', 'C', 'G'],

    // ─── Cumbia ───
    'cumbia sobre el rio': ['Am', 'F', 'C', 'G'],
    'la culebritica': ['Am', 'F', 'C', 'G'],

    // ─── Balada / Pop Latino clásico ───
    'despacito (luis fonsi)': ['Bm', 'G', 'D', 'A'],
    'silencio': ['C', 'G', 'Am', 'F'],
    'reactivo': ['Am', 'F', 'C', 'G'],
    'vestido de novia': ['C', 'F', 'G', 'Am'],
    'amor eterno': ['Am', 'G', 'F', 'E'],
    'contigo aprendi': ['C', 'F', 'G', 'C'],
    'carino mio': ['C', 'G', 'Am', 'F'],
    'si nos dejan': ['C', 'F', 'G', 'C'],
    'el triste': ['Am', 'G', 'F', 'E'],
    'gracias al amor': ['C', 'G', 'Am', 'F'],

    // ─── Salsa ───
    'la vida es un carnaval': ['Am', 'F', 'C', 'G'],
    'quimbara': ['Am', 'F', 'C', 'G'],
    'el cantante': ['Am', 'F', 'C', 'G'],
    'pedro navaja': ['Am', 'F', 'C', 'G'],

    // ─── Bachata ───
    'propuesta indecente (romeo)': ['Am', 'F', 'C', 'G'],
    'corazon sin cara': ['C', 'G', 'Am', 'F'],
    'darte un beso': ['C', 'G', 'Am', 'F'],
    'invisible': ['Am', 'F', 'C', 'G'],

    // ─── Merengue ───
    'la dueña del swing': ['Am', 'F', 'C', 'G'],

    // ─── Rock en español ───
    'la plaga': ['Am', 'F', 'C', 'G'],
    'matador': ['Am', 'F', 'C', 'G'],
    'demusica ligera': ['G', 'C', 'D', 'G'],
    'lamento boliviano': ['Am', 'F', 'C', 'G'],
    'rusia': ['Am', 'F', 'C', 'G'],
    'persiana americana': ['Am', 'F', 'C', 'G'],
    'mary had a little lamb': ['E', 'A', 'B', 'E'],
    'tirá para arriba': ['Am', 'F', 'C', 'G'],
    'fluorescente': ['Am', 'F', 'C', 'G'],

    // ─── Pop argentino / uruguayo ───
    'asi es la vida': ['C', 'G', 'Am', 'F'],
    '1989': ['C', 'G', 'Am', 'F'],
    'me falta el corazon': ['C', 'G', 'Am', 'F'],
    'lento': ['C', 'G', 'Am', 'F'],

    // ─── Pop mexicano ───
    'hasta la raiz': ['C', 'G', 'Am', 'F'],
    'tatuajes': ['C', 'G', 'Am', 'F'],
    'amor a la mexicana': ['Am', 'F', 'C', 'G'],
    'maldita primavera': ['C', 'G', 'Am', 'F'],
    'a puro dolor': ['Am', 'F', 'C', 'G'],
    'sin ti': ['Am', 'F', 'C', 'G'],
    'latinoamericana': ['C', 'G', 'Am', 'F'],

    // ─── Pop colombiano ───
    'aislados': ['C', 'G', 'Am', 'F'],

    // ─── Pop venezolano / caribeño ───
    'el mudo': ['Am', 'F', 'C', 'G'],
    'solo por ti': ['C', 'G', 'Am', 'F'],

    // ─── Pop brasileño ───
    'despacito (luis fonsi ft daddy yankee)': ['Bm', 'G', 'D', 'A'],
    'ai se eu te pego': ['G', 'D', 'Em', 'C'],
    'efilisyufei': ['Am', 'F', 'C', 'G'],

    // ─── Más pop español ───
    'la playa': ['C', 'G', 'Am', 'F'],
    'para siempre': ['C', 'G', 'Am', 'F'],
    'cuando calienta el sol': ['C', 'F', 'G', 'C'],
    'el reloj': ['Am', 'G', 'F', 'E'],
    'sinbad': ['Am', 'F', 'C', 'G'],
    'bella': ['C', 'G', 'Am', 'F'],

    // ─── Pop urbano actual ───
    'ojitos lindos': ['Am', 'F', 'C', 'G'],
    'un verano sin ti': ['Am', 'F', 'C', 'G'],
    'callaita': ['Gmaj7', 'Dmaj7', 'Bm7'],
    'titi me pregunto': ['Am', 'F', 'C', 'G'],
    'me porto bonito': ['Am', 'F', 'C', 'G'],
    'efecto': ['Am', 'F', 'C', 'G'],
    'ch y la pizza': ['Am', 'F', 'C', 'G'],
    'moscow mule': ['Am', 'F', 'C', 'G'],
    'where she goes': ['Am', 'F', 'C', 'G'],
    'monaco': ['Am', 'F', 'C', 'G'],

    // ─── Pop latino hitos ───
    'livin la vida loca': ['Am', 'F', 'C', 'G'],
    'maria la del barrio': ['Am', 'F', 'C', 'G'],
    'celoso': ['C', 'G', 'Am', 'F'],
    'sin pijama': ['Am', 'F', 'C', 'G'],
    'senorita': ['Am', 'F', 'C', 'G'],
    'lo mio es mejor': ['C', 'G', 'Am', 'F'],
    'calma': ['Am', 'F', 'C', 'G'],
    'cuento de hadas': ['C', 'G', 'Am', 'F'],

    // ─── Pop rock en español ───
    'ojos asi': ['Am', 'F', 'C', 'G'],
    'claridad': ['Am', 'F', 'C', 'G'],
    'todo de ti': ['C', 'G', 'Am', 'F'],
    'mi limit': ['Am', 'F', 'C', 'G'],
    'ida y vuelta': ['C', 'G', 'Am', 'F'],

    // ─── Reggaetón clásico ───
    'mayores': ['Am', 'F', 'C', 'G'],
    'chama': ['Am', 'F', 'C', 'G'],
    'taki taki': ['Am', 'F', 'C', 'G'],
    'boom': ['Am', 'F', 'C', 'G'],
    'abuso': ['Am', 'F', 'C', 'G'],
    'ponle play': ['Am', 'F', 'C', 'G'],
    'methodo gatita': ['Am', 'F', 'C', 'G'],
    'si tu no estas': ['Am', 'F', 'C', 'G'],
    'no tiene daddy': ['Am', 'F', 'C', 'G'],
    'fina': ['Am', 'F', 'C', 'G'],
    'panties': ['Am', 'F', 'C', 'G'],

    // ─── K-pop / global ───
    'dynamite (bts)': ['B', 'G#m', 'E', 'F#'],
    'butter (bts)': ['D', 'Bm', 'G', 'A'],
    'left and right': ['C', 'G', 'Am', 'F'],
    'driver license': ['Bb', 'Gm', 'Eb', 'F'],
    'good 4 u (olivia rodrigo)': ['D', 'Bm', 'G', 'A'],

    // ─── Más clásicos en español ───
    'enchufete': ['Am', 'F', 'C', 'G'],
    'mi historia entre tus dedos': ['Am', 'F', 'C', 'G'],
    'ahora quién': ['Am', 'F', 'C', 'G'],
    'por eso vengo': ['Am', 'F', 'C', 'G'],
    'el amor de mi vida': ['C', 'G', 'Am', 'F'],
    'yo te voy a amar': ['C', 'G', 'Am', 'F'],
    'te extrañaré': ['C', 'G', 'Am', 'F'],
    'más allá': ['C', 'G', 'Am', 'F'],

    // ─── Pop cristiano en español ───
    'profecia': ['C', 'G', 'Am', 'F'],
    'tus manos': ['C', 'G', 'Am', 'F'],

    // ─── Pop latino femenina ───
    'mi circumstancia': ['Am', 'F', 'C', 'G'],
    'puro teatro': ['Am', 'F', 'C', 'G'],
    'la corriente': ['C', 'G', 'Am', 'F'],

    // ─── Bad Bunny más canciones ───
    'yo no soy celoso': ['Am', 'F', 'C', 'G'],
    '25 8': ['Am', 'F', 'C', 'G'],
    'neverita': ['Am', 'F', 'C', 'G'],
    'acadia': ['Am', 'F', 'C', 'G'],
    'la santa': ['Am', 'F', 'C', 'G'],
    'booker t': ['Am', 'F', 'C', 'G'],
    'party': ['Am', 'F', 'C', 'G'],

    // ─── Ozuna ───
    'criminal': ['Am', 'F', 'C', 'G'],
    'aml': ['Am', 'F', 'C', 'G'],
    'vaina loca': ['Am', 'F', 'C', 'G'],

    // ─── Nicky Jam ───
    'el perdón': ['Am', 'F', 'C', 'G'],

    // ─── J Balvin ───
    'mi gente': ['Bm', 'Em', 'F#'],
    'ginza': ['Am', 'F', 'C', 'G'],
    'safari': ['Am', 'F', 'C', 'G'],
    '6 am': ['Am', 'F', 'C', 'G'],
    'ay voodoo': ['Am', 'F', 'C', 'G'],

    // ─── Maluma ───
    'hawaii': ['F#m', 'D', 'A', 'C#m'],
    'felices los 4': ['Am', 'F', 'C', 'G'],
    'chulito': ['Am', 'F', 'C', 'G'],
    'medellin': ['Am', 'F', 'C', 'G'],

    // ─── Karol G ───
    'bichota': ['Am', 'F', 'C', 'G'],
    'tusa': ['G', 'Bm', 'D', 'A'],
    'provenza': ['Am', 'F', 'C', 'G'],
    'mañana sera bonito': ['Am', 'F', 'C', 'G'],

    // ─── Shakira ───
    'waka waka': ['D', 'A', 'Bm', 'G'],
    'la tortura': ['Am', 'Dm', 'E', 'G'],
    'hips dont lie': ['Am', 'F', 'G', 'Em'],
    'suerte': ['Am', 'F', 'C', 'G'],
    'try everything': ['C', 'G', 'Am', 'F'],

    // ─── Daddy Yankee ───
    'con calma': ['G#m', 'E', 'B', 'F#'],
    'shaky shaky': ['Am', 'F', 'C', 'G'],
    'limbo': ['Am', 'F', 'C', 'G'],
    'pose': ['Am', 'F', 'C', 'G'],
    'rompe': ['Am', 'F', 'C', 'G'],

    // ─── Luis Fonsi ───
    'eccezionale': ['C', 'G', 'Am', 'F'],
    'despacito remix': ['Bm', 'G', 'D', 'A'],
    'calypso': ['Am', 'F', 'C', 'G'],
    'imposible': ['Am', 'F', 'C', 'G'],

    // ─── Juanes ───
    'la camisa negra': ['F#m', 'D', 'A', 'E'],
    'una noche': ['Am', 'F', 'C', 'G'],

    // ─── Enrique Iglesias ───
    'hero': ['C', 'G', 'Am', 'F'],
    'rimiento': ['Am', 'F', 'C', 'G'],
    'addicted': ['Am', 'F', 'C', 'G'],

    // ─── Marc Anthony ───
    'valió la pena': ['Am', 'F', 'C', 'G'],

    // ─── Natalia Jimenez ───
    'yo te voy a amar (natalia)': ['C', 'G', 'Am', 'F'],
  };

  /// Normaliza un texto: minúsculas, sin acentos, sin caracteres especiales.
  static String _normalize(String text) {
    var s = text.toLowerCase().trim();
    // Reemplazar acentos
    s = s
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ñ', 'n')
        .replaceAll('ü', 'u')
        .replaceAll(RegExp(r'[^\w\s]'), '') // quitar signos
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return s;
  }

  /// Abre la caché de Hive.
  Future<void> _ensureBox() async {
    if (_box != null && _box!.isOpen) return;
    _box = await Hive.openBox<Map>(_boxName);
  }

  /// Busca acordes por título y artista.
  Future<List<String>> fetchChords(String title, String artist) async {
    await _ensureBox();
    final key = '${_normalize(title)}|${_normalize(artist)}';
    // Caché local
    final cached = _box!.get(key);
    if (cached != null) {
      return List<String>.from(cached['chords'] as List);
    }
    // Base de datos local
    final chords = _searchLocal(title);
    if (chords.isNotEmpty) {
      await _box!.put(key, {
        'title': title,
        'artist': artist,
        'chords': chords,
      });
    }
    return chords;
  }

  /// Busca en la base de datos local por título.
  List<String> _searchLocal(String title) {
    final normalized = _normalize(title);
    // Búsqueda exacta
    if (_database.containsKey(normalized)) {
      return List<String>.from(_database[normalized]!);
    }
    // Búsqueda parcial: el título contiene la clave completa o la clave contiene el título
    for (final entry in _database.entries) {
      if (entry.key.length > 3 && normalized.contains(entry.key)) {
        return List<String>.from(entry.value);
      }
      if (normalized.length > 3 && entry.key.contains(normalized)) {
        return List<String>.from(entry.value);
      }
    }
    // Búsqueda por palabras clave: separar y buscar cada palabra
    final words = normalized.split(' ').where((w) => w.length > 2).toList();
    for (final entry in _database.entries) {
      final matchCount = words.where((w) => entry.key.contains(w)).length;
      if (matchCount >= 2 || (words.length == 1 && entry.key.contains(words.first))) {
        return List<String>.from(entry.value);
      }
    }
    return [];
  }

  /// Limpia la caché.
  Future<void> clearCache() async {
    await _ensureBox();
    await _box!.clear();
  }

  /// Patrones de rasgueo por género (se aplica por defecto si no hay match específico).
  /// Formato: '↓' = down, '↑' = up, 'X' = mute/slap
  static const _strumPatterns = <String, String>{
    'default_guitar': '↓   ↓   ↑   ↑ ↓   ↑',
    'default_ukulele': '↓   ↓ ↑ ↓ ↑ ↓   ↑',
    'ballad_guitar':   '↓       ↓ ↑   ↓ ↑   ↓       ↓ ↑   ↓ ↑',
    'ballad_ukulele':  '↓       ↓   ↓   ↑   ↓       ↓   ↓   ↑',
    'reggaeton':       '↓ ↑ X ↓ ↑ X ↓   ↓ ↑ X ↓ ↑ X ↓   ',
    'rock_guitar':     '↓ ↓ ↑ ↓ ↓ ↑ ↓ ↓ ↑ ↓ ↓ ↑ ↓ ↓ ↑ ',
    'salsa':           '↓   ↓ ↑   ↓   ↓ ↑   ↓   ↓ ↑   ↓   ↓ ↑',
    'bachata':         '↓   ↑ ↓   ↓   ↑ ↓   ↓   ↑ ↓   ↓   ↑ ↓',
    'cumbia':          '↓ ↓ ↑ ↓ ↓ ↓ ↑ ↓ ↓ ↓ ↑ ↓ ↓ ↓ ↑ ',
  };

  /// Obtiene el patrón de rasgueo para una canción según su progresión de acordes.
  String getStrumPattern(List<String> chords, {bool isUkulele = false}) {
    final chordStr = chords.join(',');
    // Reggaetón: progresiones con Am F C G
    if (chordStr.contains('Am') && chordStr.contains('F') && chordStr.contains('C') && chordStr.contains('G')) {
      return _strumPatterns['reggaeton']!;
    }
    // Rock: power chords
    if (chords.any((c) => c.contains('5'))) {
      return _strumPatterns['rock_guitar']!;
    }
    // Latin ballad: tiene Eb, Bb, Fm, Ab
    if (chords.any((c) => c == 'Eb' || c == 'Ab' || c == 'Fm')) {
      return isUkulele ? _strumPatterns['ballad_ukulele']! : _strumPatterns['ballad_guitar']!;
    }
    // Default
    return isUkulele ? _strumPatterns['default_ukulele']! : _strumPatterns['default_guitar']!;
  }
}
