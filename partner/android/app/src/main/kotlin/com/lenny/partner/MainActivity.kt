package com.lenny.partner

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.view.WindowManager
import android.widget.Toast
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Il Sunmi del ristorante esegue solo questa app: lo schermo deve
        // restare sempre acceso, gli ordini si guardano al volo dal banco.
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        createNotificationChannels()
        richiediPermessoAvvioAutomatico()
        KeepAliveService.avvia(this)
    }

    /// Il riavvio automatico al boot su Android recenti richiede il permesso
    /// "Mostra sopra altre app": senza, il BootReceiver non puo' aprire
    /// l'activity dal background. Si chiede a ogni avvio finche' non viene
    /// concesso: sul Sunmi si fa una volta sola e non ci si pensa piu'.
    private fun richiediPermessoAvvioAutomatico() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M &&
            !Settings.canDrawOverlays(this)
        ) {
            Toast.makeText(
                this,
                "Concedi \"Mostra sopra altre app\": serve a riaprire " +
                    "l'app da sola all'accensione del dispositivo",
                Toast.LENGTH_LONG
            ).show()
            try {
                startActivity(
                    Intent(
                        Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                        Uri.parse("package:$packageName")
                    )
                )
            } catch (e: Exception) {
                // Alcune ROM non hanno la schermata dedicata: pazienza,
                // l'app resta usabile e riprova al prossimo avvio.
            }
        }
    }

    private fun createNotificationChannels() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val notificationManager =
                getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

            // Canale principale ordini con suono personalizzato
            val soundUri = Uri.parse(
                "android.resource://${packageName}/raw/notifica"
            )
            val audioAttributes = AudioAttributes.Builder()
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .setUsage(AudioAttributes.USAGE_NOTIFICATION)
                .build()

            val channel = NotificationChannel(
                "lenny_orders",
                "Ordini Lenny",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Notifiche per nuovi ordini e aggiornamenti"
                setSound(soundUri, audioAttributes)
                enableVibration(true)
                vibrationPattern = longArrayOf(0, 250, 250, 250)
            }

            notificationManager.createNotificationChannel(channel)
        }
    }
}
