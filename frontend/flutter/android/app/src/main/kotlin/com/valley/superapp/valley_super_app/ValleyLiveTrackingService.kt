package com.valley.superapp.valley_super_app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Path
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import kotlin.math.max
import kotlin.math.min

class ValleyLiveTrackingService : Service() {
    private val handler = Handler(Looper.getMainLooper())
    private val executor: ExecutorService = Executors.newSingleThreadExecutor()
    private var state = TrackingState()
    private var running = false
    private var lastMapBitmap: Bitmap? = null

    override fun onCreate() {
        super.onCreate()
        createChannels()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                stopTracking()
                return START_NOT_STICKY
            }
            ACTION_UPDATE -> {
                state = state.merge(intent)
                publishNotifications()
            }
            else -> {
                state = TrackingState.fromIntent(intent)
                startTracking()
            }
        }
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        running = false
        handler.removeCallbacksAndMessages(null)
        executor.shutdownNow()
        super.onDestroy()
    }

    private fun startTracking() {
        running = true
        publishNotifications()
        scheduleNextTick(immediate = true)
    }

    private fun stopTracking() {
        running = false
        handler.removeCallbacksAndMessages(null)
        val notificationManager = getSystemService(NotificationManager::class.java)
        notificationManager.cancel(MAP_NOTIFICATION_ID)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
        stopSelf()
    }

    private fun scheduleNextTick(immediate: Boolean = false) {
        if (!running) {
            return
        }
        handler.postDelayed({ tick() }, if (immediate) 1_000L else UPDATE_INTERVAL_MS)
    }

    private fun tick() {
        if (!running) {
            return
        }
        executor.submit {
            val updated = fetchRemoteState() ?: state.nextSyntheticStep()
            val snapshot = updated.mapSnapshotUrl
                ?.takeIf { it.startsWith("https://", ignoreCase = true) }
                ?.let { downloadBitmap(it) }
            handler.post {
                state = updated
                if (snapshot != null) {
                    lastMapBitmap = snapshot
                }
                publishNotifications()
                scheduleNextTick()
            }
        }
    }

    private fun fetchRemoteState(): TrackingState? {
        val endpoint = state.trackingUrl.takeIf { it.isNotBlank() } ?: return null
        return try {
            val connection = (URL(endpoint).openConnection() as HttpURLConnection).apply {
                connectTimeout = 5_000
                readTimeout = 5_000
                requestMethod = "GET"
                setRequestProperty("Accept", "application/json")
                if (state.authToken.isNotBlank()) {
                    setRequestProperty("Authorization", "Bearer ${state.authToken}")
                }
            }
            connection.inputStream.bufferedReader().use { reader ->
                val json = JSONObject(reader.readText())
                val tracking = json.optJSONObject("tracking")
                if (tracking != null) {
                    state.merge(tracking)
                } else {
                    state.merge(json)
                }
            }
        } catch (_: Exception) {
            null
        }
    }

    private fun downloadBitmap(url: String): Bitmap? {
        return try {
            val connection = (URL(url).openConnection() as HttpURLConnection).apply {
                connectTimeout = 5_000
                readTimeout = 5_000
                requestMethod = "GET"
            }
            connection.inputStream.use { input -> BitmapFactory.decodeStream(input) }
        } catch (_: Exception) {
            null
        }
    }

    private fun publishNotifications() {
        val primary = buildLiveStatusNotification()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                LIVE_NOTIFICATION_ID,
                primary,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC,
            )
        } else {
            startForeground(LIVE_NOTIFICATION_ID, primary)
        }

        getSystemService(NotificationManager::class.java)
            .notify(MAP_NOTIFICATION_ID, buildMapNotification())
    }

    private fun buildLiveStatusNotification(): Notification {
        val etaText = state.etaMinutes?.let { "${it}min" } ?: "a caminho"
        val builder = notificationBuilder(LIVE_CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_menu_mylocation)
            .setContentTitle("Valley - ${state.orderLabel}")
            .setContentText("${state.statusLabel} • $etaText")
            .setSubText("Rastreio em tempo real")
            .setContentIntent(openAppIntent())
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setShowWhen(true)
            .setWhen(System.currentTimeMillis() + ((state.etaMinutes ?: 1) * 60_000L))
            .setVisibility(Notification.VISIBILITY_PUBLIC)
            .setCategory(Notification.CATEGORY_PROGRESS)
            .setStyle(Notification.BigTextStyle().bigText(state.expandedStatusText()))
            .setProgress(100, state.progress.coerceIn(0, 100), state.progress <= 0)
            .addAction(
                android.R.drawable.ic_menu_close_clear_cancel,
                "Encerrar",
                stopIntent(),
            )

        requestPromotedOngoing(builder, etaText)
        return builder.build()
    }

    private fun buildMapNotification(): Notification {
        val bitmap = lastMapBitmap ?: renderFallbackMap(state)
        val builder = notificationBuilder(MAP_CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_dialog_map)
            .setContentTitle("Mapa do entregador")
            .setContentText("${state.courierName} • ${state.vehicleLabel}")
            .setContentIntent(openAppIntent())
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setVisibility(Notification.VISIBILITY_PUBLIC)
            .setCategory(Notification.CATEGORY_PROGRESS)
            .setLargeIcon(bitmap)
            .setStyle(
                Notification.BigPictureStyle()
                    .bigPicture(bitmap)
                    .setBigContentTitle("Valley - mapa em tempo real")
                    .setSummaryText(state.expandedStatusText()),
            )
        return builder.build()
    }

    private fun requestPromotedOngoing(builder: Notification.Builder, chipText: String) {
        if (Build.VERSION.SDK_INT < 36) {
            return
        }
        try {
            builder.javaClass
                .getMethod("setRequestPromotedOngoing", java.lang.Boolean.TYPE)
                .invoke(builder, true)
        } catch (_: Exception) {
        }
        try {
            builder.javaClass
                .getMethod("setShortCriticalText", CharSequence::class.java)
                .invoke(builder, chipText)
        } catch (_: Exception) {
        }
    }

    private fun renderFallbackMap(current: TrackingState): Bitmap {
        val width = 960
        val height = 520
        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG)

        canvas.drawColor(Color.rgb(229, 244, 238))

        paint.color = Color.rgb(207, 226, 219)
        paint.strokeWidth = 3f
        for (x in 0..width step 96) {
            canvas.drawLine(x.toFloat(), 0f, x.toFloat(), height.toFloat(), paint)
        }
        for (y in 0..height step 74) {
            canvas.drawLine(0f, y.toFloat(), width.toFloat(), y.toFloat(), paint)
        }

        val pickup = current.pickupPoint()
        val courier = current.courierPoint()
        val destination = current.destinationPoint()
        val points = listOf(pickup, courier, destination)
        val minLat = points.minOf { it.lat } - 0.003
        val maxLat = points.maxOf { it.lat } + 0.003
        val minLng = points.minOf { it.lng } - 0.003
        val maxLng = points.maxOf { it.lng } + 0.003

        fun x(lng: Double): Float {
            val span = max(0.0001, maxLng - minLng)
            return (72 + ((lng - minLng) / span) * (width - 144)).toFloat()
        }

        fun y(lat: Double): Float {
            val span = max(0.0001, maxLat - minLat)
            return (height - 72 - ((lat - minLat) / span) * (height - 144)).toFloat()
        }

        val route = Path().apply {
            moveTo(x(pickup.lng), y(pickup.lat))
            quadTo(width * 0.5f, height * 0.32f, x(destination.lng), y(destination.lat))
        }
        paint.style = Paint.Style.STROKE
        paint.strokeWidth = 18f
        paint.color = Color.rgb(188, 222, 204)
        canvas.drawPath(route, paint)
        paint.strokeWidth = 9f
        paint.color = Color.rgb(0, 128, 83)
        canvas.drawPath(route, paint)

        drawMapPin(canvas, x(pickup.lng), y(pickup.lat), "Loja", Color.rgb(42, 73, 61))
        drawMapPin(canvas, x(destination.lng), y(destination.lat), "Cliente", Color.rgb(34, 87, 126))
        drawCourierMarker(canvas, x(courier.lng), y(courier.lat))

        paint.style = Paint.Style.FILL
        paint.color = Color.argb(224, 14, 45, 34)
        canvas.drawRoundRect(32f, 30f, width - 32f, 122f, 28f, 28f, paint)
        paint.color = Color.WHITE
        paint.textSize = 30f
        paint.isFakeBoldText = true
        canvas.drawText("Valley - ${current.statusLabel}", 62f, 70f, paint)
        paint.textSize = 24f
        paint.isFakeBoldText = false
        canvas.drawText("${current.courierName} • ${current.vehicleLabel} • ${current.etaText()}", 62f, 104f, paint)
        return bitmap
    }

    private fun drawMapPin(canvas: Canvas, x: Float, y: Float, label: String, color: Int) {
        val paint = Paint(Paint.ANTI_ALIAS_FLAG)
        paint.color = color
        paint.style = Paint.Style.FILL
        canvas.drawCircle(x, y, 20f, paint)
        paint.color = Color.WHITE
        canvas.drawCircle(x, y, 8f, paint)
        paint.color = color
        paint.textSize = 24f
        paint.isFakeBoldText = true
        canvas.drawText(label, x + 26f, y + 8f, paint)
    }

    private fun drawCourierMarker(canvas: Canvas, x: Float, y: Float) {
        val paint = Paint(Paint.ANTI_ALIAS_FLAG)
        paint.color = Color.rgb(0, 148, 96)
        paint.style = Paint.Style.FILL
        canvas.drawCircle(x, y, 30f, paint)
        paint.color = Color.WHITE
        paint.textSize = 28f
        paint.textAlign = Paint.Align.CENTER
        paint.isFakeBoldText = true
        canvas.drawText("V", x, y + 10f, paint)
        paint.textAlign = Paint.Align.LEFT
    }

    private fun createChannels() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return
        }
        val manager = getSystemService(NotificationManager::class.java)
        val live = NotificationChannel(
            LIVE_CHANNEL_ID,
            "Valley rastreio em tempo real",
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "Status dinamico de pedidos aceitos."
            lockscreenVisibility = Notification.VISIBILITY_PUBLIC
        }
        val map = NotificationChannel(
            MAP_CHANNEL_ID,
            "Valley mapa do entregador",
            NotificationManager.IMPORTANCE_DEFAULT,
        ).apply {
            description = "Mapa por snapshot atualizado do entregador."
            lockscreenVisibility = Notification.VISIBILITY_PUBLIC
        }
        manager.createNotificationChannel(live)
        manager.createNotificationChannel(map)
    }

    private fun notificationBuilder(channelId: String): Notification.Builder {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, channelId)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }
    }

    private fun openAppIntent(): PendingIntent {
        val intent = packageManager.getLaunchIntentForPackage(packageName)
            ?: Intent(this, MainActivity::class.java)
        intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
        return PendingIntent.getActivity(
            this,
            10,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun stopIntent(): PendingIntent {
        val intent = Intent(this, ValleyLiveTrackingService::class.java).apply {
            action = ACTION_STOP
        }
        return PendingIntent.getService(
            this,
            11,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    data class GeoPoint(val lat: Double, val lng: Double)

    data class TrackingState(
        val orderId: String = "pedido",
        val orderLabel: String = "pedido aceito",
        val status: String = "accepted",
        val statusLabel: String = "Pedido aceito",
        val courierName: String = "Entregador Valley",
        val vehicleLabel: String = "veiculo em rota",
        val etaMinutes: Int? = 14,
        val progress: Int = 8,
        val courierLat: Double = -23.5615,
        val courierLng: Double = -46.6550,
        val pickupLat: Double = -23.5650,
        val pickupLng: Double = -46.6620,
        val destinationLat: Double = -23.5535,
        val destinationLng: Double = -46.6425,
        val trackingUrl: String = "",
        val authToken: String = "",
        val mapSnapshotUrl: String? = null,
        val startedAtMillis: Long = System.currentTimeMillis(),
    ) {
        fun expandedStatusText(): String =
            "$statusLabel. $courierName esta em rota com $vehicleLabel. ${etaText()}."

        fun etaText(): String = etaMinutes?.let { "Chegada estimada em ${it}min" } ?: "ETA recalculando"

        fun pickupPoint(): GeoPoint = GeoPoint(pickupLat, pickupLng)
        fun courierPoint(): GeoPoint = GeoPoint(courierLat, courierLng)
        fun destinationPoint(): GeoPoint = GeoPoint(destinationLat, destinationLng)

        fun nextSyntheticStep(): TrackingState {
            if (trackingUrl.isNotBlank()) {
                return this
            }
            val nextProgress = min(98, progress + 3)
            val ratio = nextProgress / 100.0
            val nextLat = pickupLat + ((destinationLat - pickupLat) * ratio)
            val nextLng = pickupLng + ((destinationLng - pickupLng) * ratio)
            return copy(
                progress = nextProgress,
                courierLat = nextLat,
                courierLng = nextLng,
                etaMinutes = etaMinutes?.let { max(1, it - 1) },
                status = if (nextProgress > 70) "nearby" else "on_route",
                statusLabel = if (nextProgress > 70) "Entregador proximo" else "Entregador em rota",
            )
        }

        fun merge(intent: Intent?): TrackingState {
            if (intent == null) {
                return this
            }
            return copy(
                orderId = intent.getStringExtra("order_id") ?: orderId,
                orderLabel = intent.getStringExtra("order_label") ?: orderLabel,
                status = intent.getStringExtra("status") ?: status,
                statusLabel = intent.getStringExtra("status_label") ?: statusLabel,
                courierName = intent.getStringExtra("courier_name") ?: courierName,
                vehicleLabel = intent.getStringExtra("vehicle_label") ?: vehicleLabel,
                etaMinutes = if (intent.hasExtra("eta_minutes")) intent.getIntExtra("eta_minutes", etaMinutes ?: 0) else etaMinutes,
                progress = if (intent.hasExtra("progress")) intent.getIntExtra("progress", progress) else progress,
                courierLat = if (intent.hasExtra("courier_lat")) intent.getDoubleExtra("courier_lat", courierLat) else courierLat,
                courierLng = if (intent.hasExtra("courier_lng")) intent.getDoubleExtra("courier_lng", courierLng) else courierLng,
                pickupLat = if (intent.hasExtra("pickup_lat")) intent.getDoubleExtra("pickup_lat", pickupLat) else pickupLat,
                pickupLng = if (intent.hasExtra("pickup_lng")) intent.getDoubleExtra("pickup_lng", pickupLng) else pickupLng,
                destinationLat = if (intent.hasExtra("destination_lat")) intent.getDoubleExtra("destination_lat", destinationLat) else destinationLat,
                destinationLng = if (intent.hasExtra("destination_lng")) intent.getDoubleExtra("destination_lng", destinationLng) else destinationLng,
                trackingUrl = intent.getStringExtra("tracking_url") ?: trackingUrl,
                authToken = intent.getStringExtra("auth_token") ?: authToken,
                mapSnapshotUrl = intent.getStringExtra("map_snapshot_url") ?: mapSnapshotUrl,
            )
        }

        fun merge(json: JSONObject): TrackingState =
            copy(
                orderId = json.optString("order_id", orderId),
                orderLabel = json.optString("order_label", orderLabel),
                status = json.optString("status", status),
                statusLabel = json.optString("status_label", statusLabel),
                courierName = json.optString("courier_name", courierName),
                vehicleLabel = json.optString("vehicle_label", vehicleLabel),
                etaMinutes = if (json.has("eta_minutes")) json.optInt("eta_minutes") else etaMinutes,
                progress = if (json.has("progress")) json.optInt("progress") else progress,
                courierLat = json.optDouble("courier_lat", courierLat),
                courierLng = json.optDouble("courier_lng", courierLng),
                pickupLat = json.optDouble("pickup_lat", pickupLat),
                pickupLng = json.optDouble("pickup_lng", pickupLng),
                destinationLat = json.optDouble("destination_lat", destinationLat),
                destinationLng = json.optDouble("destination_lng", destinationLng),
                mapSnapshotUrl = json.optString("map_snapshot_url", mapSnapshotUrl ?: "").ifBlank { mapSnapshotUrl },
            )

        companion object {
            fun fromIntent(intent: Intent?): TrackingState = TrackingState().merge(intent)
        }
    }

    companion object {
        const val ACTION_START = "com.valley.superapp.live_tracking.START"
        const val ACTION_UPDATE = "com.valley.superapp.live_tracking.UPDATE"
        const val ACTION_STOP = "com.valley.superapp.live_tracking.STOP"
        private const val LIVE_CHANNEL_ID = "valley_live_tracking"
        private const val MAP_CHANNEL_ID = "valley_live_tracking_map"
        private const val LIVE_NOTIFICATION_ID = 7201
        private const val MAP_NOTIFICATION_ID = 7202
        private const val UPDATE_INTERVAL_MS = 3_000L
    }
}
