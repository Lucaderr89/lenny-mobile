import 'package:flutter_test/flutter_test.dart';

import 'package:driver/logic/nav_guidance.dart';
import 'package:driver/logic/regole_home.dart';
import 'package:driver/models/nav_route.dart';
import 'package:driver/models/order.dart';

/// Rotta sintetica a L: ~1 km verso nord, svolta a destra, ~1 km verso est.
/// Le tolleranze larghe (15 m) assorbono la proiezione equirettangolare.
NavRoute _rottaAelle() {
  return NavRoute.fromJson({
    'distance': 2004,
    'time': 240,
    'coordinates': [
      [12.4400, 43.9000],
      [12.4400, 43.9090],
      [12.4525, 43.9090],
    ],
    'instructions': [
      {
        'text': 'Continua su Via Prova',
        'street_name': 'Via Prova',
        'distance': 1002,
        'time': 120,
        'sign': 0,
        'interval': [0, 1],
      },
      {
        'text': 'Gira a destra su Via Test',
        'street_name': 'Via Test',
        'distance': 1002,
        'time': 120,
        'sign': 2,
        'interval': [1, 2],
      },
      {
        'text': 'Arrivato a destinazione',
        'street_name': '',
        'distance': 0,
        'time': 0,
        'sign': 4,
        'interval': [2, 2],
      },
    ],
  });
}

Order _ordine(int id, String status, {String? pickedUpAt}) {
  return Order(
    id: id,
    dateOrder: '2026-08-10',
    timeSlotId: 234,
    restaurantId: 1,
    restaurantName: 'Ristorante $id',
    restaurantAddress: 'Via Ristorante $id',
    restaurantLat: 43.90,
    restaurantLng: 12.44,
    customerName: 'Cliente $id',
    customerPhone: '333000000$id',
    deliveryAddress: 'Via Cliente $id',
    deliveryLat: 43.91,
    deliveryLng: 12.45,
    total: 20,
    status: status,
    assignedAt: '2026-08-10 12:00:00',
    pickedUpAt: pickedUpAt,
    confirmedAt: '2026-08-10 12:01:00',
    timeSlot: '19:30 - 20:00',
    batchId: 'b$id',
    paymentMethodId: 1,
  );
}

void main() {
  group('NavGuidance: metri che scalano sulla geometria', () {
    test('a inizio rotta la manovra e\' la svolta, a distanza piena', () {
      final g = NavGuidance(_rottaAelle());
      final p = g.proietta(43.9000, 12.4400);
      expect(p.metriPercorsi, closeTo(0, 15));
      final m = g.prossimaManovraDa(p)!;
      expect(m.istruzione.text, 'Gira a destra su Via Test');
      expect(m.metriRestanti, closeTo(1002, 15));
    });

    test('a meta\' del primo tratto i metri sono scesi della meta\'', () {
      final g = NavGuidance(_rottaAelle());
      final p = g.proietta(43.9045, 12.4400);
      final m = g.prossimaManovraDa(p)!;
      expect(m.metriRestanti, closeTo(501, 15));
      expect(g.metriAllArrivoDa(p), closeTo(1503, 20));
    });

    test('dopo la svolta la manovra diventa l\'arrivo', () {
      final g = NavGuidance(_rottaAelle());
      // ~480 m a est del punto di svolta, sul secondo tratto
      final p = g.proietta(43.9090, 12.4460);
      final m = g.prossimaManovraDa(p)!;
      expect(m.istruzione.sign, 4);
      expect(g.metriAllArrivoDa(p), closeTo(522, 20));
    });

    test('fuori percorso: scatta solo dopo 3 fix consecutivi oltre 40 m', () {
      final g = NavGuidance(_rottaAelle());
      // ~100 m a ovest del primo tratto
      final fuori = g.proietta(43.9045, 12.4388);
      expect(fuori.distanzaDalPercorsoM, greaterThan(40));
      expect(g.registraProiezione(fuori), isFalse);
      expect(g.registraProiezione(fuori), isFalse);
      expect(g.registraProiezione(fuori), isTrue);
    });

    test('un rientro sul percorso azzera il conteggio fuori-percorso', () {
      final g = NavGuidance(_rottaAelle());
      final fuori = g.proietta(43.9045, 12.4388);
      final dentro = g.proietta(43.9045, 12.4400);
      g.registraProiezione(fuori);
      g.registraProiezione(fuori);
      expect(g.registraProiezione(dentro), isFalse);
      expect(g.registraProiezione(fuori), isFalse);
      expect(g.registraProiezione(fuori), isFalse);
      expect(g.registraProiezione(fuori), isTrue);
    });

    test('fix con accuracy scarsa non giudicano il fuori-percorso', () {
      final g = NavGuidance(_rottaAelle());
      final fuori = g.proietta(43.9045, 12.4388);
      expect(g.registraProiezione(fuori, accuracy: 80), isFalse);
      expect(g.registraProiezione(fuori, accuracy: 80), isFalse);
      expect(g.registraProiezione(fuori, accuracy: 80), isFalse);
    });
  });

  group('RegoleHome: cursore tappa con stati freschi (override)', () {
    test('l\'override in_delivery chiude il ritiro senza aspettare il polling',
        () {
      final o = _ordine(7, 'picking_up');
      final tappe = RegoleHome.stepsSintetici([o]);
      final byId = {7: o};

      // Senza override: la prossima tappa e' ancora il ritiro
      expect(RegoleHome.prossimaTappa(tappe, byId)!.isPickup, isTrue);

      // Con override (risposta di track-location): si passa alla consegna
      final dopo = RegoleHome.prossimaTappa(
        tappe,
        byId,
        statiOverride: const {7: 'in_delivery'},
      );
      expect(dopo!.isDelivery, isTrue);
    });

    test('ordine sparito dagli attivi = tappe chiuse (consegnato)', () {
      final o = _ordine(7, 'in_delivery');
      final tappe = RegoleHome.stepsSintetici([o]);
      expect(RegoleHome.prossimaTappa(tappe, const {}), isNull);
    });

    test('tappaInCorso segue l\'override', () {
      final o = _ordine(7, 'picking_up', pickedUpAt: '2026-08-10 19:40:00');
      final delivery = RegoleHome.stepsSintetici([o])[1];
      expect(RegoleHome.tappaInCorso(delivery, o), isFalse);
      expect(
        RegoleHome.tappaInCorso(
          delivery,
          o,
          statiOverride: const {7: 'in_delivery'},
        ),
        isTrue,
      );
    });
  });
}
