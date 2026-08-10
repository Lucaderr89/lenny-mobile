import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:driver/widgets/nav/nav_banner.dart';

void main() {
  testWidgets(
      'il banner manovra resta una fascia in alto, non copre lo schermo',
      (tester) async {
    // Stessa disposizione della schermata di navigazione: figlio NON
    // posizionato di uno Stack (vincoli di altezza limitati ma loose).
    // Una Column senza mainAxisSize.min qui si prendeva tutto lo schermo.
    await tester.pumpWidget(
      MaterialApp(
        home: Stack(
          children: [
            const Positioned.fill(child: SizedBox()),
            SafeArea(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Expanded(
                    child: NavBanner(
                      icona: Icons.turn_sharp_right,
                      titolo: 'Gira a destra su Via Venticinque Marzo',
                      sottotitolo: 'tra 200 m - Green Clover Irish Pub',
                      colore: Colors.blue,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    final size = tester.getSize(find.byType(NavBanner));
    expect(size.height, lessThan(120));
  });
}
