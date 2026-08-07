import 'package:flutter_test/flutter_test.dart';
import 'package:driver/logic/regole_home.dart';
import 'package:driver/models/order.dart';
import 'package:driver/services/tts_service.dart';
import 'package:driver/widgets/azione_card.dart';

/// Ordine di prova costruito dal JSON dell'API, cosi' il test passa anche
/// dal parsing vero e non solo dalla logica.
Order ordine({
  required int id,
  required String fascia,
  String stato = 'assigned',
  bool confermato = true,
  int metodoPagamento = 1,
}) {
  return Order.fromJson({
    'id': id,
    'date_order': '2026-08-07',
    'time_slot': '$fascia - 00:00',
    'restaurant_name': 'Ristorante $id',
    'customer_name': 'Cliente $id',
    'status': stato,
    'confirmed_at': confermato ? '2026-08-07 10:00:00' : null,
    'payment_method_id': metodoPagamento,
    'total': '20.00',
  });
}

void main() {
  group('Bolla: quale ordine segue', () {
    test(
      'resta sull ordine scelto col NAVIGA anche se un altro va in consegna',
      () {
        // Il caso reale segnalato: si naviga verso l ordine delle 15:00 e
        // intanto quello delle 15:30 passa in consegna da solo.
        final ordini = [
          ordine(id: 15597, fascia: '15:00'),
          ordine(id: 15591, fascia: '15:30', stato: 'in_delivery'),
        ];

        final scelto = RegoleHome.ordinePerBolla(ordini, 15597);

        expect(scelto?.id, 15597);
      },
    );

    test('segue il cambio di stato dello stesso ordine scelto', () {
      final scelto = RegoleHome.ordinePerBolla([
        ordine(id: 15597, fascia: '15:00', stato: 'in_delivery'),
      ], 15597);

      expect(scelto?.id, 15597);
      expect(scelto?.isInDelivery, isTrue);
    });

    test('se l ordine scelto non e piu in carico torna all automatico', () {
      final ordini = [ordine(id: 15591, fascia: '15:30', stato: 'in_delivery')];

      final scelto = RegoleHome.ordinePerBolla(ordini, 15597);

      expect(scelto?.id, 15591);
    });

    test('senza scelta esplicita vince il piu avanti nel flusso', () {
      final ordini = [
        ordine(id: 1, fascia: '19:00'),
        ordine(id: 2, fascia: '19:30', stato: 'picking_up'),
        ordine(id: 3, fascia: '20:00', stato: 'in_delivery'),
      ];

      expect(RegoleHome.ordinePerBolla(ordini, null)?.id, 3);
    });

    test('gli ordini non ancora confermati non prendono la bolla', () {
      final ordini = [ordine(id: 7, fascia: '19:00', confermato: false)];

      expect(RegoleHome.ordinePerBolla(ordini, null), isNull);
    });

    test('nessun ordine, nessuna bolla', () {
      expect(RegoleHome.ordinePerBolla([], 15597), isNull);
    });
  });

  group('Giro: un giro sta dentro una fascia', () {
    test('ordini di fasce diverse NON finiscono nella stessa card', () {
      // Il caso reale segnalato: 15579 delle 12:30 finito insieme a
      // 15594/15595 delle 14:30 sotto un intestazione 12:30-13:00.
      final giri = RegoleHome.giriPerFascia([
        ordine(id: 15579, fascia: '12:30'),
        ordine(id: 15594, fascia: '14:30'),
        ordine(id: 15595, fascia: '14:30'),
      ]);

      expect(giri.keys.toList(), ['12:30', '14:30']);
      expect(giri['12:30']!.map((o) => o.id), [15579]);
      expect(giri['14:30']!.map((o) => o.id), [15594, 15595]);
    });

    test('le fasce escono in ordine cronologico', () {
      final giri = RegoleHome.giriPerFascia([
        ordine(id: 3, fascia: '20:00'),
        ordine(id: 1, fascia: '12:30'),
        ordine(id: 2, fascia: '19:00'),
      ]);

      expect(giri.keys.toList(), ['12:30', '19:00', '20:00']);
    });

    test('i non confermati restano fuori dal giro', () {
      final giri = RegoleHome.giriPerFascia([
        ordine(id: 1, fascia: '19:00'),
        ordine(id: 2, fascia: '19:00', confermato: false),
      ]);

      expect(giri['19:00']!.map((o) => o.id), [1]);
    });
  });

  group('INCASSA solo per gli ordini da riscuotere', () {
    test('contanti, bancomat e smac sono da incassare', () {
      for (final metodo in [1, 2, 3]) {
        expect(
          ordine(id: 1, fascia: '19:00', metodoPagamento: metodo).isPaid,
          isFalse,
          reason: 'metodo $metodo deve risultare da incassare',
        );
      }
    });

    test('stripe e nexi sono gia pagati: niente INCASSA', () {
      for (final metodo in [4, 5]) {
        expect(
          ordine(id: 1, fascia: '19:00', metodoPagamento: metodo).isPaid,
          isTrue,
          reason: 'metodo $metodo e pagato online',
        );
      }
    });

    test('metodo mancante non chiede soldi al cliente', () {
      expect(ordine(id: 1, fascia: '19:00', metodoPagamento: 0).isPaid, isTrue);
    });
  });

  group('Fascia pronunciata dalla voce', () {
    test('legge solo inizio fascia, senza trattino ne seconda ora', () {
      expect(TtsService.fasciaParlata('19:30 - 20:00'), '19 e 30');
      expect(TtsService.fasciaParlata('12:00 - 12:30'), '12');
      expect(TtsService.fasciaParlata('09:05 - 09:35'), '9 e 5');
    });

    test('fascia illeggibile: si dice quello che c e, senza rompere', () {
      expect(TtsService.fasciaParlata('prima possibile'), 'prima possibile');
    });
  });

  group('Numeri di telefono scritti a mano in anagrafica', () {
    test('spazi, punti e prefisso: restano solo cifre e il + iniziale', () {
      expect(ChiamaRiga.normalizza('339 833 1545'), '3398331545');
      expect(ChiamaRiga.normalizza('+39.33.14.57.52.43'), '+393314575243');
      expect(ChiamaRiga.normalizza('0549 905280'), '0549905280');
    });

    test('numero vuoto o senza cifre non compone niente', () {
      expect(ChiamaRiga.normalizza(''), '');
      expect(ChiamaRiga.normalizza('n/d'), '');
    });
  });
}
