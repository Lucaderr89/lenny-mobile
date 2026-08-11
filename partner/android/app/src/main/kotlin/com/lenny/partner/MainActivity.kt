package com.lenny.partner

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.PowerManager
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
        richiediPermessi()
        KeepAliveService.avvia(this)
    }

    /// Permessi di affidabilita', chiesti UNO alla volta a ogni avvio
    /// finche' non concessi (sul Sunmi si fa una volta sola):
    /// 1) esenzione dal risparmio batteria: senza, a SCHERMO SPENTO Android
    ///    taglia rete e CPU (Doze) e le comande non escono piu';
    /// 2) "Mostra sopra altre app": senza, il BootReceiver non puo' riaprire
    ///    l'app dal background dopo un riavvio.
    private fun richiediPermessi() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return

        val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
        if (!pm.isIgnoringBatteryOptimizations(packageName)) {
            Toast.makeText(
                this,
                "Consenti: serve a stampare le comande anche a schermo spento",
                Toast.LENGTH_LONG
            ).show()
            try {
                startActivity(
                    Intent(
                        Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS,
                        Uri.parse("package:$packageName")
                    )
                )
            } catch (e: Exception) {
                // ROM senza la schermata dedicata: si riprova al prossimo avvio.
            }
            return // un permesso alla volta
        }

        if (!Settings.canDrawOverlays(this)) {
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
                // Come sopra: non bloccante.
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
