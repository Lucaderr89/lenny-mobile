package com.lenny.drivers

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.media.AudioAttributes
import android.net.Uri
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        createNotificationChannels()
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
