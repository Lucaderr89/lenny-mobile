import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:driver/config/app_colors.dart';
import 'package:driver/config/app_theme.dart';

/// Il tema notte esisteva gia' e sembrava a posto, ma le schermate si
/// scrivevano i colori a mano e restavano chiare. Questi test verificano il
/// ponte che le ha rimesse in riga: i colori devono uscire dal TEMA, non da
/// costanti fisse.
void main() {
  /// MaterialApp ANIMA il passaggio da un tema all'altro: con un solo
  /// pump si legge ancora il tema vecchio. Serve pumpAndSettle, altrimenti
  /// il test fallisce per colpa dell'animazione e non del prodotto.
  Future<BuildContext> contestoCon(WidgetTester tester, ThemeData tema) async {
    late BuildContext catturato;
    await tester.pumpWidget(
      MaterialApp(
        theme: tema,
        home: Builder(
          builder: (context) {
            catturato = context;
            return const SizedBox();
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    return catturato;
  }

  testWidgets('di giorno: fondi chiari e testo scuro', (tester) async {
    final context = await contestoCon(tester, AppTheme.lightTheme);

    expect(context.notte, isFalse);
    expect(context.cSfondo, AppColors.background);
    expect(context.cCard, Colors.white);
    expect(context.cTesto, AppColors.dark);
    expect(context.cBordoCard, isNull, reason: 'di giorno resta l ombra');
    expect(context.cOmbra, isNotEmpty);
  });

  testWidgets('di notte: fondi scuri, testo chiaro, card bordate', (
    tester,
  ) async {
    final context = await contestoCon(tester, AppTheme.darkTheme);

    expect(context.notte, isTrue);
    expect(context.cSfondo, AppColors.nightBackground);
    expect(context.cCard, AppColors.nightSurface);
    expect(context.cTesto, AppColors.nightText);
    expect(
      context.cBordoCard,
      isNotNull,
      reason: 'su fondo scuro l ombra non si vede: serve il bordo',
    );
    expect(context.cOmbra, isEmpty);
  });

  testWidgets('i due temi non condividono nessun colore di fondo', (
    tester,
  ) async {
    final chiaro = await contestoCon(tester, AppTheme.lightTheme);
    final sfondoChiaro = chiaro.cSfondo;
    final cardChiara = chiaro.cCard;
    final testoChiaro = chiaro.cTesto;

    final scuro = await contestoCon(tester, AppTheme.darkTheme);

    expect(scuro.cSfondo, isNot(sfondoChiaro));
    expect(scuro.cCard, isNot(cardChiara));
    expect(scuro.cTesto, isNot(testoChiaro));
  });

  test('lo scaffold dei due temi segue la palette giusta', () {
    expect(AppTheme.lightTheme.scaffoldBackgroundColor, AppColors.background);
    expect(
      AppTheme.darkTheme.scaffoldBackgroundColor,
      AppColors.nightBackground,
    );
    expect(AppTheme.darkTheme.brightness, Brightness.dark);
  });
}
