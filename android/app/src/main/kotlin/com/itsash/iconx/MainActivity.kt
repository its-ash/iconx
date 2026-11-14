package com.itsash.iconx

import android.content.ActivityNotFoundException
import android.content.ComponentName
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

/**
 * MethodChannel "com.itsash.iconx/launcher" (Dart: lib/platform/launcher_channel.dart):
 *   - apps() -> [{label, component}]: every launcher activity on the phone (needs the MAIN/LAUNCHER
 *     <queries> entry in the manifest), component as "package/full.Class".
 *   - launchers() -> [{id, name, installed, isDefault}] for [Launchers.known].
 *   - apply({id}) -> "applied" | "opened" | "failed": sends the launcher's apply-icon-pack intent, or
 *     opens the launcher (the user then picks iconX in its settings).
 *   - share({text}): system share sheet with plain text (icon requests).
 *
 * The icon pack itself is static resources (appfilter.xml, drawables) generated at build time;
 * launchers find it through the THEME intent filters on this activity.
 */
class MainActivity : FlutterActivity() {
    private val io = Executors.newSingleThreadExecutor()
    private val ui = Handler(Looper.getMainLooper())

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.itsash.iconx/launcher").setMethodCallHandler { call, result ->
            when (call.method) {
                "apps" -> io.execute {
                    val apps = runCatching { installedApps() }
                    ui.post { apps.onSuccess { result.success(it) }.onFailure { result.error("apps", it.message, null) } }
                }
                "launchers" -> result.success(launchers())
                "apply" -> result.success(apply(call.argument<String>("id")))
                "share" -> {
                    val text = call.argument<String>("text") ?: ""
                    val send = Intent(Intent.ACTION_SEND).setType("text/plain").putExtra(Intent.EXTRA_TEXT, text)
                    startActivity(Intent.createChooser(send, null))
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        io.shutdown()
        super.onDestroy()
    }

    private fun installedApps(): List<Map<String, String>> {
        val pm = packageManager
        val main = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
        return pm.queryIntentActivities(main, 0)
            .map { r ->
                mapOf(
                    "label" to r.loadLabel(pm).toString(),
                    "component" to "${r.activityInfo.packageName}/${r.activityInfo.name}",
                )
            }
            .distinctBy { it["component"] }
            .sortedBy { it["label"]!!.lowercase() }
    }

    private fun installed(pkg: String): Boolean = runCatching {
        packageManager.getPackageInfo(pkg, 0)
        true
    }.getOrDefault(false)

    private fun defaultLauncher(): String? {
        val home = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME)
        return packageManager.resolveActivity(home, PackageManager.MATCH_DEFAULT_ONLY)?.activityInfo?.packageName
    }

    private fun launchers(): List<Map<String, Any>> {
        val current = defaultLauncher()
        return Launchers.known.map { l ->
            val pkg = l.packages.firstOrNull { installed(it) }
            mapOf(
                "id" to l.id,
                "name" to l.name,
                "installed" to (pkg != null),
                "isDefault" to (pkg != null && pkg == current),
            )
        }
    }

    private fun apply(id: String?): String {
        val l = Launchers.known.firstOrNull { it.id == id } ?: return "failed"
        val pkg = l.packages.firstOrNull { installed(it) } ?: return "failed"
        val intent = l.applyIntent(pkg, packageName)
        if (intent != null && start(intent)) return "applied"
        val open = packageManager.getLaunchIntentForPackage(pkg)
            ?: Intent(Settings.ACTION_HOME_SETTINGS)
        return if (start(open)) "opened" else "failed"
    }

    private fun start(intent: Intent): Boolean = try {
        startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        true
    } catch (_: ActivityNotFoundException) {
        false
    } catch (_: SecurityException) {
        false
    }
}

/** Launchers that support icon packs, with their apply intents where one exists. */
data class Launcher(val id: String, val name: String, val packages: List<String>, val apply: ((String, String) -> Intent)?) {
    fun applyIntent(launcherPkg: String, packPkg: String): Intent? = apply?.invoke(launcherPkg, packPkg)
}

object Launchers {
    val known = listOf(
        Launcher("nova", "Nova Launcher", listOf("com.teslacoilsw.launcher", "com.teslacoilsw.launcher.prime")) { _, pack ->
            Intent("com.teslacoilsw.launcher.APPLY_ICON_THEME")
                .setPackage("com.teslacoilsw.launcher")
                .putExtra("com.teslacoilsw.launcher.extra.ICON_THEME_TYPE", "GO")
                .putExtra("com.teslacoilsw.launcher.extra.ICON_THEME_PACKAGE", pack)
        },
        Launcher("lawnchair", "Lawnchair", listOf("app.lawnchair", "app.lawnchair.play", "ch.deletescape.lawnchair.plah"), null),
        Launcher("smart", "Smart Launcher", listOf("ginlemon.flowerfree", "ginlemon.flowerpro")) { launcher, pack ->
            Intent("ginlemon.smartlauncher.setGSLTHEME").setPackage(launcher).putExtra("package", pack)
        },
        Launcher("niagara", "Niagara Launcher", listOf("bitpit.launcher"), null),
        Launcher("action", "Action Launcher", listOf("com.actionlauncher.playstore")) { launcher, pack ->
            Intent(Intent.ACTION_MAIN).setComponent(ComponentName(launcher, "com.actionlauncher.ActionLauncher"))
                .putExtra("apply_icon_pack", pack)
        },
        Launcher("hyperion", "Hyperion Launcher", listOf("projekt.launcher"), null),
        Launcher("kiss", "KISS Launcher", listOf("fr.neamar.kiss"), null),
    )
}
