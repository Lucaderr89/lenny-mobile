package com.lenny.partner

import android.annotation.SuppressLint
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import android.os.PowerManager

/**
 * Servizio in primo piano: tiene alta la priorita' del processo, cosi'
 * Android non uccide l'app tra un aggiornamento ordini e l'altro.
 * Non fa lavoro in proprio: il polling vive nell'app Flutter. La notifica
 * persistente e' il prezzo richiesto da Android per questo privilegio.
 *
 * Il wakelock PARZIALE tiene la CPU sveglia anche a SCHERMO SPENTO: il
 * ristorante spegne lo schermo per risparmiare batteria e le comande
 * devono uscire lo stesso. Insieme all'esenzione dal risparmio batteria
 * (chiesta all'avvio dell'app) copre anche la rete sotto Doze.
 */
class KeepAliveService : Service() {

    private var wakeLock: PowerManager.WakeLock? = null

    @SuppressLint("WakelockTimeout")
    override fun onCreate() {
        super.onCreate()
        creaCanale()
        startForeground(ID_NOTIFICA, notifica())

        val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
        wakeLock = pm.newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK,
            "LennyPartner:ricezioneOrdini"
        ).apply {
            setReferenceCounted(false)
            // Senza timeout: e' un chiosco, il servizio vive quanto l'app.
            acquire()
        }
    }

    override fun onDestroy() {
        try {
            wakeLock?.release()
        } catch (_: Exception) {
        }
        wakeLock = null
        super.onDestroy()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        // STICKY: se il sistema lo termina, lo fa ripartire da solo.
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun creaCanale() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val canale = NotificationChannel(
                CANALE_ID,
                "Servizio ordini",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Tiene attiva la ricezione degli ordini"
                setShowBadge(false)
            }
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            nm.createNotificationChannel(canale)
        }
    }

    private fun notifica(): Notification {
        val apri = PendingIntent.getActivity(
            this,
            0,
            Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_IMMUTABLE
        )
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CANALE_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }
        return builder
            .setContentTitle("Lenny Ristoranti attivo")
            .setContentText("Ricezione ordini in corso")
            .setSmallIcon(R.drawable.ic_notification)
            .setContentIntent(apri)
            .setOngoing(true)
            .build()
    }

    companion object {
        private const val CANALE_ID = "lenny_keepalive"
        private const val ID_NOTIFICA = 1001

        fun avvia(context: Context) {
            val intent = Intent(context, KeepAliveService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }
    }
}
