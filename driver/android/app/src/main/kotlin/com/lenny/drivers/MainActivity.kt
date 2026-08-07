package com.lenny.drivers

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private var canaleBollaPronto = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        createNotificationChannels()
        collegaCanaleBolla()
    }

    /**
     * Canale delle azioni della BOLLA.
     *
     * La bolla gira in un secondo motore Flutter che il plugin crea SENZA
     * registrarci i plugin dell'app: da li' dentro non esistono ne'
     * url_launcher ne' il canale su cui viaggia closeOverlay. Far rimbalzare
     * le azioni fino all'app principale passando per il messaggero del
     * plugin funzionava sulla carta ma non in mano al driver, e falliva in
     * silenzio.
     *
     * Qui invece agganciamo un canale NOSTRO direttamente al motore della
     * bolla e le azioni le esegue il codice nativo: nessun rimbalzo, niente
     * da cui dipendere.
     *
     * Si usa il context dell'applicazione, non l'Activity: mentre la bolla
     * e' in uso il driver e' dentro Google Maps e l'Activity puo' non
     * esserci piu'.
     */
    private fun collegaCanaleBolla(tentativiRimasti: Int = 6) {
        if (canaleBollaPronto) return

        val motoreBolla = FlutterEngineCache.getInstance().get("myCachedEngine")
        if (motoreBolla == null) {
            // Il motore lo crea il plugin quando si aggancia all'Activity:
            // se non c'e' ancora si riprova, senza insistere all'infinito.
            if (tentativiRimasti > 0) {
                Handler(Looper.getMainLooper()).postDelayed(
                    { collegaCanaleBolla(tentativiRimasti - 1) },
                    300
                )
            }
            return
        }

        canaleBollaPronto = true
        val app = applicationContext

        MethodChannel(motoreBolla.dartExecutor.binaryMessenger, "lenny/bolla")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "chiama" -> {
                        val numero = call.argument<String>("numero").orEmpty()
                        if (numero.isEmpty()) {
                            result.success(false)
                        } else {
                            // Comporre da app in secondo piano e' lecito
                            // perche' l'app ha il permesso di sovrapposizione,
                            // che e' proprio quello richiesto per la bolla.
                            val chiamata = Intent(
                                Intent.ACTION_DIAL,
                                Uri.parse("tel:$numero")
                            ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            app.startActivity(chiamata)
                            result.success(true)
                        }
                    }

                    "chiudi" -> {
                        // Stessa cosa che fa closeOverlay del plugin, ma
                        // raggiungibile da dentro la bolla.
                        val servizio = Intent().setClassName(
                            app.packageName,
                            "flutter.overlay.window.flutter_overlay_window.OverlayService"
                        )
                        app.stopService(servizio)
                        result.success(true)
                    }

                    else -> result.notImplemented()
                }
            }
    }

    private fun createNotificationChannels() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val notificationManager =
                getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

            // Canale principale consegne con suono personalizzato
            val soundUri = Uri.parse(
                "android.resource://${packageName}/raw/notifica"
            )
            val audioAttributes = AudioAttributes.Builder()
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .setUsage(AudioAttributes.USAGE_NOTIFICATION)
                .build()

            val channel = NotificationChannel(
                "lenny_orders",
                "Consegne Lenny",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Notifiche per nuove consegne e aggiornamenti"
                setSound(soundUri, audioAttributes)
                enableVibration(true)
                vibrationPattern = longArrayOf(0, 250, 250, 250)
            }

            notificationManager.createNotificationChannel(channel)

            // Canale della BOLLA. Android obbliga ogni servizio in primo
            // piano ad avere una notifica fissa, e la bolla gira come
            // servizio: quella notifica non si puo' togliere. Il plugin pero'
            // creerebbe il canale a importanza NORMALE, quindi ogni NAVIGA
            // suonava e appariva come un avviso vero, confondendolo con un
            // ordine nuovo.
            //
            // Lo creiamo NOI per primi a importanza MINIMA: Android ignora
            // i cambi di importanza su un canale gia' esistente, quindi la
            // creazione del plugin non lo rialza. Risultato: notifica muta,
            // relegata in fondo, senza banner.
            val canaleBolla = NotificationChannel(
                "Overlay Channel",
                "Bolla sopra il navigatore",
                NotificationManager.IMPORTANCE_MIN
            ).apply {
                description =
                    "Notifica fissa richiesta da Android mentre la bolla e' attiva"
                setSound(null, null)
                enableVibration(false)
                setShowBadge(false)
            }

            notificationManager.createNotificationChannel(canaleBolla)
        }
    }
}
