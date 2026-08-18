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
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Il Sunmi del ristorante esegue solo questa app: lo schermo deve
        // restare sempre acceso, gli ordini si guardano al volo dal banco.
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        createNotificationChannels()
        KeepAliveService.avvia(this)
    }

    /// Permessi di affidabilita', chiesti in sequenza SUBITO DOPO IL LOGIN
    /// (li avvia l'app via MethodChannel: a chi non ha fatto accesso non
    /// servono). Ognuno viene chiesto una volta sola per sessione, e il
    /// successivo parte al rientro dalla schermata di sistema, cosi' il
    /// ristoratore li concede tutti in un giro solo:
    /// 1) esenzione dal risparmio batteria: senza, a SCHERMO SPENTO Android
    ///    taglia rete e CPU (Doze) e le comande non escono piu';
    /// 2) "Mostra sopra altre app": senza, il BootReceiver non puo' riaprire
    ///    l'app dal background dopo un riavvio.
    private var flussoPermessiAvviato = false
    private var batteriaGiaChiesta = false
    private var overlayGiaChiesto = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CANALE_PERMESSI
        ).setMethodCallHandler { call, result ->
            if (call.method == "avvia") {
                flussoPermessiAvviato = true
                prossimoPermesso()
                result.success(null)
            } else {
                result.notImplemented()
            }
        }
    }

    override fun onResume() {
        super.onResume()
        // Rientro da una schermata di sistema: si passa al permesso dopo.
        if (flussoPermessiAvviato) prossimoPermesso()
    }

    private fun prossimoPermesso() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return

        val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
        if (!pm.isIgnoringBatteryOptimizations(packageName) && !batteriaGiaChiesta) {
            batteriaGiaChiesta = true
            Toast.makeText(
                this,
                "Consenti: serve a stampare le comande anche a schermo spento",
                Toast.LENGTH_LONG
            ).show()
            apri(
                Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS,
                Uri.parse("package:$packageName")
            )
            return
        }

        if (!Settings.canDrawOverlays(this) && !overlayGiaChiesto) {
            overlayGiaChiesto = true
            Toast.makeText(
                this,
                "Concedi \"Mostra sopra altre app\": serve a riaprire " +
                    "l'app da sola all'accensione del dispositivo",
                Toast.LENGTH_LONG
            ).show()
            apri(
                Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                Uri.parse("package:$packageName")
            )
        }
    }

    private fun apri(azione: String, dati: Uri) {
        try {
            startActivity(Intent(azione, dati))
        } catch (e: Exception) {
            // ROM senza la schermata dedicata: si riprova al prossimo login.
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

    companion object {
        private const val CANALE_PERMESSI = "lenny.partner/permessi"
    }
}
