import 'package:flutter_test/flutter_test.dart';
import 'package:driver/logic/navigazione_esterna.dart';
import 'package:driver/logic/regole_home.dart';
import 'package:driver/models/delivery_history.dart';
import 'package:driver/models/order.dart';
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

  group('Numero d ordine da mostrare', () {
    test('e il numero lenny-app quando l API lo manda', () {
      final o = Order.fromJson({'id': 19634, 'numero_ordine': '131234'});
      expect(o.numeroOrdine, '131234');
      expect(o.id, 19634, reason: 'l id resta la chiave delle chiamate');
    });

    test('senza numero esterno (o vuoto) si mostra l id', () {
      expect(Order.fromJson({'id': 19634}).numeroOrdine, '19634');
      expect(
        Order.fromJson({'id': 19634, 'numero_ordine': ' '}).numeroOrdine,
        '19634',
      );
    });

    test('anche lo storico mostra il numero dello scontrino', () {
      Map<String, dynamic> consegna(Map<String, dynamic> extra) => {
        'id': 20091,
        'date_order': '2026-10-12',
        'time_slot_id': 76,
        'restaurant_id': 1,
        'assigned_at': '',
        'delivered_at': '',
        'total': '10',
        ...extra,
      };
      expect(
        DeliveryHistory.fromJson(consegna({'numero_ordine': '131747'}))
            .numeroOrdine,
        '131747',
      );
      expect(DeliveryHistory.fromJson(consegna({})).numeroOrdine, '20091');
    });

    test('i prodotti portano extra e nota', () {
      final o = Order.fromJson({
        'id': 1,
        'products': [
          {
            'name': 'Pizza',
            'quantity': 2,
            'price': '8.00',
            'total': '16.00',
            'extras': ['senza cipolla', ''],
            'note': ' ben cotta ',
          },
        ],
      });
      expect(o.products.single.extras, ['senza cipolla']);
      expect(o.products.single.note, 'ben cotta');
    });
  });

  group('Destinazione per Google Maps', () {
    test('con le coordinate si naviga sul punto', () {
      expect(
        NavigazioneEsterna.destinazione(43.9394, 12.4468, 'Via Roma 1'),
        '43.939400,12.446800',
      );
    });

    test('senza coordinate (0,0) si usa l indirizzo, mai il mare', () {
      expect(
        NavigazioneEsterna.destinazione(0, 0, ' Via Roma 1, Serravalle '),
        'Via Roma 1, Serravalle',
      );
      expect(NavigazioneEsterna.destinazione(0, 0, ''), '');
    });

    test('gli URL partono gia in navigazione e codificano l indirizzo', () {
      final dest = 'Via Roma 1, Serravalle';
      expect(
        NavigazioneEsterna.androidNavigazione(dest).toString(),
        'google.navigation:q=Via%20Roma%201%2C%20Serravalle&mode=d',
      );
      expect(
        NavigazioneEsterna.iosGoogleMaps(dest).toString(),
        'comgooglemaps://?daddr=Via%20Roma%201%2C%20Serravalle&directionsmode=driving',
      );
      expect(
        NavigazioneEsterna.linkUniversale('43.9,12.4').toString(),
        'https://www.google.com/maps/dir/?api=1&destination=43.9%2C12.4&travelmode=driving',
      );
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
