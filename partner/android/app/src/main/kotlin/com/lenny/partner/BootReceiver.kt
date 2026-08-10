package com.lenny.partner

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * Avvia l'app al boot del dispositivo: dopo un riavvio (aggiornamento,
 * mancanza di corrente) il Sunmi deve tornare operativo da solo, senza
 * che in cucina qualcuno debba ricordarsi di aprire l'app.
 *
 * NB: da Android 10 in poi l'avvio di activity dal background e' soggetto
 * a restrizioni; sui Sunmi (Android 7-11 con ROM permissiva) funziona, ma
 * va verificato sul dispositivo reale.
 */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val azione = intent.action ?: return
        if (azione != Intent.ACTION_BOOT_COMPLETED &&
            azione != "android.intent.action.QUICKBOOT_POWERON"
        ) {
            return
        }

        val launch = Intent(context, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        context.startActivity(launch)
    }
}
