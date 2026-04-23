package com.bili.tv.bili_tv_app

import android.app.SearchManager
import android.content.ContentUris
import android.content.Intent
import android.graphics.BitmapFactory
import android.media.MediaCodecList
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.BaseColumns
import android.util.Log
import androidx.core.content.FileProvider
import androidx.tvprovider.media.tv.PreviewChannel
import androidx.tvprovider.media.tv.PreviewChannelHelper
import androidx.tvprovider.media.tv.PreviewProgram
import androidx.tvprovider.media.tv.TvContractCompat
import androidx.tvprovider.media.tv.WatchNextProgram
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val UPDATE_CHANNEL = "com.bili.tv/update"
    private val CODEC_CHANNEL = "com.bili.tv/codec"
    private val LAUNCH_CHANNEL = "com.bili.tv/launch"
    private val TV_HOME_CHANNEL = "com.bili.tv/tv_home"
    private val TV_HOME_TAG = "BiliTV-TVHome"
    private val TV_HOME_PREFS = "bilitv_tv_home"
    private val PREVIEW_CHANNEL_ID_KEY = "preview_channel_id"
    private val PREVIEW_CHANNEL_INTERNAL_ID = "preview:bilitv_home"
    private var launchChannel: MethodChannel? = null
    private var pendingLaunchAction: Map<String, Any>? = null
    private var lastTvHomeError: String? = null
    private val previewChannelHelper by lazy { PreviewChannelHelper(this) }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        cacheLaunchAction(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        cacheLaunchAction(intent)
        pendingLaunchAction?.let { action ->
            launchChannel?.invokeMethod("onLaunchAction", action)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // 更新安装 Channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, UPDATE_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "installApk" -> {
                    val path = call.argument<String>("path")
                    if (path != null) {
                        try {
                            installApk(path)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("INSTALL_ERROR", e.message, null)
                        }
                    } else {
                        result.error("INVALID_PATH", "APK path is null", null)
                    }
                }
                else -> result.notImplemented()
            }
        }
        
        // 编码器检测 Channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CODEC_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getHardwareDecoders" -> {
                    try {
                        val hwCodecs = getHardwareDecoders()
                        result.success(hwCodecs)
                    } catch (e: Exception) {
                        result.error("CODEC_ERROR", e.message, null)
                    }
                }
                "getDeviceInfo" -> {
                    try {
                        result.success(getDeviceInfo())
                    } catch (e: Exception) {
                        result.error("DEVICE_INFO_ERROR", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }

        launchChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, LAUNCH_CHANNEL)
        launchChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "consumePendingLaunchAction" -> {
                    val action = pendingLaunchAction
                    pendingLaunchAction = null
                    result.success(action)
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, TV_HOME_CHANNEL).setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "publishRecommendations" -> {
                        val items = call.argument<List<*>>("items") ?: emptyList<Any>()
                        publishRecommendations(items)
                        result.success(true)
                    }
                    "publishWatchNext" -> {
                        val item = call.argument<Map<*, *>>("item")
                        if (item == null) {
                            result.success(false)
                        } else {
                            publishWatchNext(item)
                            result.success(true)
                        }
                    }
                    "clearWatchNext" -> {
                        val internalId = call.argument<String>("internalId").orEmpty()
                        clearWatchNext(internalId)
                        result.success(true)
                    }
                    "getDebugState" -> {
                        result.success(getTvHomeDebugState())
                    }
                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                lastTvHomeError = e.message
                Log.e(TV_HOME_TAG, "TV Home call failed: ${call.method}", e)
                result.error("TV_HOME_ERROR", e.message, null)
            }
        }
    }
    
    // 获取硬件解码器支持的格式
    private fun getHardwareDecoders(): List<String> {
        val supportedFormats = mutableSetOf<String>()
        val codecList = MediaCodecList(MediaCodecList.ALL_CODECS)
        
        for (info in codecList.codecInfos) {
            // 只检查解码器，跳过编码器
            if (info.isEncoder) continue
            
            // 检查是否是硬件解码器 (不包含 google/software)
            val name = info.name.lowercase()
            val isHardware = !name.contains("google") && 
                            !name.contains("software") &&
                            !name.contains("sw") &&
                            !name.startsWith("c2.android")
            
            if (isHardware) {
                for (type in info.supportedTypes) {
                    when {
                        type.equals("video/avc", ignoreCase = true) -> supportedFormats.add("avc")
                        type.equals("video/hevc", ignoreCase = true) -> supportedFormats.add("hevc")
                        type.equals("video/av01", ignoreCase = true) -> supportedFormats.add("av1")
                        type.equals("video/x-vnd.on2.vp9", ignoreCase = true) -> supportedFormats.add("vp9")
                    }
                }
            }
        }
        
        return supportedFormats.toList()
    }

    private fun getDeviceInfo(): Map<String, Any> {
        return mapOf(
            "brand" to Build.BRAND,
            "manufacturer" to Build.MANUFACTURER,
            "model" to Build.MODEL,
            "device" to Build.DEVICE,
            "sdkInt" to Build.VERSION.SDK_INT,
            "supportedAbis" to Build.SUPPORTED_ABIS.toList()
        )
    }

    private fun cacheLaunchAction(intent: Intent?) {
        val action = parseLaunchAction(intent) ?: return
        pendingLaunchAction = action
    }

    private fun parseLaunchAction(intent: Intent?): Map<String, Any>? {
        if (intent == null) return null

        when (intent.action) {
            Intent.ACTION_SEARCH,
            "android.media.action.MEDIA_PLAY_FROM_SEARCH" -> {
                val query = intent.getStringExtra(SearchManager.QUERY)
                    ?: intent.getStringExtra("query")
                    ?: ""
                if (query.isNotBlank()) {
                    return mapOf("type" to "search", "value" to query.trim())
                }
            }

            Intent.ACTION_VIEW -> {
                val data = intent.data ?: return null
                if (data.scheme != "bilitv") return null

                return when (data.host) {
                    "video" -> {
                        val bvid = data.lastPathSegment.orEmpty()
                        if (bvid.isBlank()) null
                        else mapOf("type" to "video", "value" to bvid)
                    }

                    "search" -> {
                        val keyword = data.getQueryParameter("keyword").orEmpty()
                        if (keyword.isBlank()) null
                        else mapOf("type" to "search", "value" to keyword)
                    }

                    "live" -> {
                        val roomId = data.lastPathSegment.orEmpty()
                        if (roomId.isBlank()) null
                        else mapOf("type" to "live", "value" to roomId)
                    }

                    else -> null
                }
            }
        }

        return null
    }

    private fun publishRecommendations(items: List<*>) {
        val channelId = ensurePreviewChannel()
        if (channelId <= 0L) return

        clearPreviewPrograms(channelId)
        var publishedCount = 0

        items.mapNotNull { raw ->
            (raw as? Map<*, *>)?.mapKeys { entry -> entry.key.toString() }
        }.take(10).forEachIndexed { index, item ->
            val title = item["title"] as? String ?: return@forEachIndexed
            val imageUrl = item["imageUrl"] as? String ?: return@forEachIndexed
            val intentUri = item["intentUri"] as? String ?: return@forEachIndexed
            val internalId = item["internalId"] as? String ?: "preview_$index"
            val description = item["description"] as? String ?: ""

            val program = PreviewProgram.Builder()
                .setChannelId(channelId)
                .setType(TvContractCompat.PreviewPrograms.TYPE_CLIP)
                .setTitle(title)
                .setDescription(description)
                .setPosterArtUri(Uri.parse(imageUrl))
                .setIntentUri(Uri.parse(intentUri))
                .setInternalProviderId(internalId)
                .setWeight(100 - index)
                .build()

            val programId = previewChannelHelper.publishPreviewProgram(program)
            publishedCount++
            Log.d(
                TV_HOME_TAG,
                "Published preview program id=$programId internalId=$internalId channelId=$channelId"
            )
        }
        Log.d(TV_HOME_TAG, "Published $publishedCount preview programs to channel $channelId")
    }

    private fun publishWatchNext(item: Map<*, *>) {
        val normalized = item.mapKeys { entry -> entry.key.toString() }
        val internalId = normalized["internalId"] as? String ?: return
        val title = normalized["title"] as? String ?: return
        val imageUrl = normalized["imageUrl"] as? String ?: return
        val intentUri = normalized["intentUri"] as? String ?: return
        val description = normalized["description"] as? String ?: ""
        val durationMillis = (normalized["durationMillis"] as? Number)?.toLong() ?: 0L
        val progressMillis = (normalized["progressMillis"] as? Number)?.toLong() ?: 0L

        val values = WatchNextProgram.Builder()
            .setType(TvContractCompat.PreviewPrograms.TYPE_CLIP)
            .setWatchNextType(TvContractCompat.WatchNextPrograms.WATCH_NEXT_TYPE_CONTINUE)
            .setTitle(title)
            .setDescription(description)
            .setPosterArtUri(Uri.parse(imageUrl))
            .setIntentUri(Uri.parse(intentUri))
            .setInternalProviderId(internalId)
            .setLastPlaybackPositionMillis(progressMillis.toInt())
            .setDurationMillis(durationMillis.toInt())
            .setLastEngagementTimeUtcMillis(System.currentTimeMillis())
            .build()

        val existingProgramIds = findWatchNextProgramIds(internalId)
        if (existingProgramIds.isNotEmpty()) {
            previewChannelHelper.updateWatchNextProgram(
                values,
                existingProgramIds.first()
            )
            existingProgramIds.drop(1).forEach { duplicateId ->
                contentResolver.delete(TvContractCompat.buildWatchNextProgramUri(duplicateId), null, null)
                Log.d(TV_HOME_TAG, "Deleted duplicate Watch Next id=$duplicateId internalId=$internalId")
            }
            Log.d(
                TV_HOME_TAG,
                "Updated Watch Next id=${existingProgramIds.first()} internalId=$internalId progress=$progressMillis/$durationMillis"
            )
        } else {
            val programId = previewChannelHelper.publishWatchNextProgram(values)
            Log.d(
                TV_HOME_TAG,
                "Published Watch Next id=$programId internalId=$internalId progress=$progressMillis/$durationMillis"
            )
        }
    }

    private fun clearWatchNext(internalId: String) {
        if (internalId.isBlank()) return
        findWatchNextProgramIds(internalId).forEach { programId ->
            contentResolver.delete(
                TvContractCompat.buildWatchNextProgramUri(programId),
                null,
                null
            )
            Log.d(TV_HOME_TAG, "Cleared Watch Next id=$programId internalId=$internalId")
        }
    }

    private fun ensurePreviewChannel(): Long {
        val prefs = getSharedPreferences(TV_HOME_PREFS, MODE_PRIVATE)
        val cachedId = prefs.getLong(PREVIEW_CHANNEL_ID_KEY, -1L)
        if (cachedId > 0L && channelExists(cachedId) && matchesPreviewChannelInternalId(cachedId)) {
            Log.d(TV_HOME_TAG, "Using cached preview channel id=$cachedId")
            return cachedId
        }

        val existingChannel = previewChannelHelper.getAllChannels().firstOrNull {
            it.internalProviderId == PREVIEW_CHANNEL_INTERNAL_ID
        }
        if (existingChannel != null && channelExists(existingChannel.id)) {
            prefs.edit().putLong(PREVIEW_CHANNEL_ID_KEY, existingChannel.id).apply()
            Log.d(TV_HOME_TAG, "Using existing preview channel id=${existingChannel.id}")
            return existingChannel.id
        }

        if (cachedId > 0L) {
            prefs.edit().remove(PREVIEW_CHANNEL_ID_KEY).apply()
        }

        val logo = loadPreviewChannelLogo()
        val channelBuilder = PreviewChannel.Builder()
            .setDisplayName("BiliTV 推荐")
            .setDescription("主页推荐与继续观看")
            .setAppLinkIntentUri(Uri.parse("bilitv://search?keyword=BiliTV"))
            .setInternalProviderId(PREVIEW_CHANNEL_INTERNAL_ID)
        if (logo != null) {
            channelBuilder.setLogo(logo)
        }

        val channelId = try {
            previewChannelHelper.publishChannel(channelBuilder.build())
        } catch (logoError: Exception) {
            Log.w(
                TV_HOME_TAG,
                "publishChannel with embedded logo failed, retrying with manual logo",
                logoError
            )
            val channelUri = contentResolver.insert(
                TvContractCompat.Channels.CONTENT_URI,
                PreviewChannel.Builder(channelBuilder.build())
                    .build()
                    .toContentValues()
            ) ?: return -1L
            val manualChannelId = ContentUris.parseId(channelUri)
            if (logo != null) {
                setPreviewChannelLogo(manualChannelId, logo)
            }
            manualChannelId
        }
        prefs.edit().putLong(PREVIEW_CHANNEL_ID_KEY, channelId).apply()
        TvContractCompat.requestChannelBrowsable(this, channelId)
        Log.d(TV_HOME_TAG, "Published preview channel id=$channelId")
        return channelId
    }

    private fun loadPreviewChannelLogo() =
        BitmapFactory.decodeResource(resources, R.drawable.ic_launcher_foreground)
            ?: BitmapFactory.decodeResource(resources, R.drawable.banner)
            ?: BitmapFactory.decodeResource(resources, R.mipmap.ic_launcher)

    private fun setPreviewChannelLogo(channelId: Long, bitmap: android.graphics.Bitmap) {
        contentResolver.openOutputStream(TvContractCompat.buildChannelLogoUri(channelId))?.use { output ->
            bitmap.compress(android.graphics.Bitmap.CompressFormat.PNG, 100, output)
        }
    }

    private fun clearPreviewPrograms(channelId: Long) {
        val uri = TvContractCompat.buildPreviewProgramsUriForChannel(channelId)
        contentResolver.query(uri, arrayOf(BaseColumns._ID), null, null, null)?.use { cursor ->
            while (cursor.moveToNext()) {
                val id = cursor.getLong(0)
                previewChannelHelper.deletePreviewProgram(id)
            }
        }
    }

    private fun channelExists(channelId: Long): Boolean {
        contentResolver.query(
            TvContractCompat.buildChannelUri(channelId),
            arrayOf(BaseColumns._ID),
            null,
            null,
            null
        )?.use { cursor ->
            return cursor.moveToFirst()
        }
        return false
    }

    private fun matchesPreviewChannelInternalId(channelId: Long): Boolean {
        contentResolver.query(
            TvContractCompat.buildChannelUri(channelId),
            arrayOf("internal_provider_id"),
            null,
            null,
            null
        )?.use { cursor ->
            if (cursor.moveToFirst()) {
                return cursor.getString(0) == PREVIEW_CHANNEL_INTERNAL_ID
            }
        }
        return false
    }

    private fun findWatchNextProgramIds(internalId: String): List<Long> {
        val ids = mutableListOf<Long>()
        val projection = arrayOf(BaseColumns._ID, "internal_provider_id")
        contentResolver.query(
            TvContractCompat.WatchNextPrograms.CONTENT_URI,
            projection,
            null,
            null,
            null
        )?.use { cursor ->
            val idIndex = cursor.getColumnIndex(BaseColumns._ID)
            val internalIdIndex = cursor.getColumnIndex("internal_provider_id")
            if (idIndex == -1 || internalIdIndex == -1) {
                return ids
            }

            while (cursor.moveToNext()) {
                if (cursor.getString(internalIdIndex) == internalId) {
                    ids.add(cursor.getLong(idIndex))
                }
            }
        }
        return ids
    }

    private fun countPreviewPrograms(channelId: Long): Int {
        if (channelId <= 0L) return 0
        return contentResolver.query(
            TvContractCompat.buildPreviewProgramsUriForChannel(channelId),
            arrayOf(BaseColumns._ID),
            null,
            null,
            null
        )?.use { cursor ->
            cursor.count
        } ?: 0
    }

    private fun countWatchNextPrograms(): Int {
        return contentResolver.query(
            TvContractCompat.WatchNextPrograms.CONTENT_URI,
            arrayOf(BaseColumns._ID),
            null,
            null,
            null
        )?.use { cursor ->
            cursor.count
        } ?: 0
    }

    private fun findExistingPreviewChannelId(cachedChannelId: Long): Long {
        if (cachedChannelId > 0L &&
            channelExists(cachedChannelId) &&
            matchesPreviewChannelInternalId(cachedChannelId)
        ) {
            return cachedChannelId
        }

        return previewChannelHelper.getAllChannels().firstOrNull {
            it.internalProviderId == PREVIEW_CHANNEL_INTERNAL_ID
        }?.id ?: -1L
    }

    private fun getTvHomeDebugState(): Map<String, Any> {
        val prefs = getSharedPreferences(TV_HOME_PREFS, MODE_PRIVATE)
        val cachedChannelId = prefs.getLong(PREVIEW_CHANNEL_ID_KEY, -1L)
        val channelId = findExistingPreviewChannelId(cachedChannelId)
        val channels = previewChannelHelper.getAllChannels()
        val launcherIntent = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME)
        val launcherPackage = packageManager.resolveActivity(launcherIntent, 0)?.activityInfo?.packageName

        return mapOf(
            "cachedPreviewChannelId" to cachedChannelId,
            "resolvedPreviewChannelId" to channelId,
            "previewChannelExists" to (channelId > 0L && channelExists(channelId)),
            "previewChannelCount" to channels.size,
            "previewProgramCount" to countPreviewPrograms(channelId),
            "watchNextProgramCount" to countWatchNextPrograms(),
            "launcherPackage" to (launcherPackage ?: ""),
            "lastError" to (lastTvHomeError ?: ""),
            "channels" to channels.map { channel ->
                mapOf(
                    "id" to channel.id,
                    "displayName" to (channel.displayName?.toString() ?: ""),
                    "internalProviderId" to (channel.internalProviderId ?: "")
                )
            }
        )
    }

    private fun installApk(path: String) {
        val file = File(path)
        if (!file.exists()) {
            throw Exception("APK file not found: $path")
        }

        val intent = Intent(Intent.ACTION_VIEW)
        intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            // Android 7.0+ 使用 FileProvider
            val uri = FileProvider.getUriForFile(
                this,
                "${packageName}.fileprovider",
                file
            )
            intent.setDataAndType(uri, "application/vnd.android.package-archive")
            intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        } else {
            // 旧版本直接使用文件路径
            intent.setDataAndType(
                android.net.Uri.fromFile(file),
                "application/vnd.android.package-archive"
            )
        }

        startActivity(intent)
    }
}
