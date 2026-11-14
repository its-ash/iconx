import java.awt.image.BufferedImage
import javax.imageio.ImageIO

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.itsash.iconx"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.itsash.iconx"
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // Signed with this Mac's debug key, like every Ash Store app (updates install over it).
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

// ---------------------------------------------------------------------------------------------
// Icon pack generation. The single source is assets/icons/*.txt (format in google.txt). For each
// variant this writes, under build/generated:
//   res/drawable-nodpi/<name>.png   20x20-cell pixel tile, 12 px per cell (240 px)
//   res/drawable-nodpi/iconback.png plain tile behind apps the pack does not cover
//   res/xml/appfilter.xml           component -> drawable map read by launchers
//   res/xml/drawable.xml            icon list for launcher icon pickers, grouped by file
//   assets/appfilter.xml, assets/drawable.xml  same files, for launchers that read assets
//   res/raw/iconx_keep.xml          tools:keep for all of the above (release resource shrinking)
// The Flutter gallery parses the same .txt files (lib/icons/icon_source.dart).
// ---------------------------------------------------------------------------------------------

abstract class IconPackTask : DefaultTask() {
    @get:InputDirectory
    @get:PathSensitive(PathSensitivity.RELATIVE)
    abstract val sourceDir: DirectoryProperty

    @get:OutputDirectory
    abstract val resDir: DirectoryProperty

    @get:OutputDirectory
    abstract val assetsDir: DirectoryProperty

    private data class Icon(
        val name: String,
        val label: String,
        val bg: Int,
        val fg: Int,
        val apps: List<String>,
        val rows: List<String>,
        val group: String,
    )

    private companion object {
        const val GRID = 16
        const val TILE = 20
        const val CELL = 12
        const val BACK_COLOR = 0xFF1F2937.toInt()
        val NAME = Regex("[a-z][a-z0-9_]*")
        val ROW = Regex("[.#]{16}")
    }

    @TaskAction
    fun generate() {
        val files = sourceDir.get().asFile.listFiles { f -> f.extension == "txt" }!!.sortedBy { it.name }
        val icons = files.flatMap { parse(it) }
        val dupes = icons.groupBy { it.name }.filter { it.value.size > 1 }.keys
        if (dupes.isNotEmpty()) throw GradleException("iconX: duplicate icon names: $dupes")

        val res = resDir.get().asFile.apply { deleteRecursively(); mkdirs() }
        val assets = assetsDir.get().asFile.apply { deleteRecursively(); mkdirs() }
        val drawables = File(res, "drawable-nodpi").apply { mkdirs() }
        for (icon in icons) ImageIO.write(render(icon.rows, icon.bg, icon.fg), "png", File(drawables, "${icon.name}.png"))
        ImageIO.write(render(null, BACK_COLOR, 0), "png", File(drawables, "iconback.png"))

        val appfilter = buildString {
            appendLine("<?xml version=\"1.0\" encoding=\"utf-8\"?>")
            appendLine("<resources>")
            appendLine("    <iconback img1=\"iconback\" />")
            appendLine("    <scale factor=\"0.7\" />")
            for (icon in icons) for (app in icon.apps) {
                appendLine("    <item component=\"ComponentInfo{$app}\" drawable=\"${icon.name}\" />")
            }
            appendLine("</resources>")
        }
        val drawableXml = buildString {
            appendLine("<?xml version=\"1.0\" encoding=\"utf-8\"?>")
            appendLine("<resources>")
            appendLine("    <version>1</version>")
            for ((group, list) in icons.groupBy { it.group }) {
                appendLine("    <category title=\"$group\" />")
                for (icon in list) appendLine("    <item drawable=\"${icon.name}\" />")
            }
            appendLine("</resources>")
        }
        // Release builds shrink resources, and nothing in code references these: launchers load them
        // by name from another app. tools:keep stops the shrinker from deleting the whole pack.
        val keep = (icons.map { "@drawable/${it.name}" } + "@drawable/iconback" + "@xml/appfilter" + "@xml/drawable")
            .joinToString(",")
        File(res, "raw").apply { mkdirs() }.resolve("iconx_keep.xml").writeText(
            "<?xml version=\"1.0\" encoding=\"utf-8\"?>\n" +
                "<resources xmlns:tools=\"http://schemas.android.com/tools\" tools:keep=\"$keep\" />\n",
        )
        val xml = File(res, "xml").apply { mkdirs() }
        for (dir in listOf(xml, assets)) {
            File(dir, "appfilter.xml").writeText(appfilter)
            File(dir, "drawable.xml").writeText(drawableXml)
        }
        logger.lifecycle("iconX: ${icons.size} icons, ${icons.sumOf { it.apps.size }} components")
    }

    private fun parse(file: File): List<Icon> {
        // Group title; keep in sync with _groupOf in lib/icons/icon_source.dart.
        val group = if (file.nameWithoutExtension == "itsash") "Ash Store" else file.nameWithoutExtension.replaceFirstChar { it.uppercase() }
        val out = mutableListOf<Icon>()
        var name: String? = null
        var startLine = 0
        val props = mutableMapOf<String, String>()
        val apps = mutableListOf<String>()
        val rows = mutableListOf<String>()

        fun fail(line: Int, msg: String): Nothing = throw GradleException("iconX: ${file.name}:$line: $msg")

        fun flush() {
            val n = name ?: return
            fun color(key: String): Int {
                val v = props[key] ?: fail(startLine, "[$n] has no $key")
                if (!Regex("#[0-9A-Fa-f]{6}").matches(v)) fail(startLine, "[$n] $key must be #RRGGBB, got $v")
                return (0xFF000000 or v.substring(1).toLong(16)).toInt()
            }
            if (rows.size != GRID) fail(startLine, "[$n] has ${rows.size} grid rows, needs $GRID")
            if (apps.isEmpty()) fail(startLine, "[$n] has no app = lines")
            out += Icon(n, props["label"] ?: n, color("bg"), color("fg"), apps.toList(), rows.toList(), group)
            props.clear(); apps.clear(); rows.clear()
        }

        file.readLines().forEachIndexed { i, raw ->
            val line = raw.trim()
            val no = i + 1
            when {
                line.isEmpty() -> Unit
                ROW.matches(line) -> {
                    if (name == null) fail(no, "grid row outside an icon")
                    rows += line
                }
                line.startsWith("#") -> Unit // comment (grid rows are matched first)
                line.startsWith("[") && line.endsWith("]") -> {
                    flush()
                    val n = line.substring(1, line.length - 1)
                    if (!NAME.matches(n)) fail(no, "icon name '$n' must match ${NAME.pattern}")
                    name = n
                    startLine = no
                }
                line.contains("=") -> {
                    if (name == null) fail(no, "property outside an icon")
                    val key = line.substringBefore("=").trim()
                    val value = line.substringAfter("=").trim()
                    when (key) {
                        "app" -> apps += component(value) ?: fail(no, "app must be package/Activity, got '$value'")
                        "label", "bg", "fg" -> props[key] = value
                        else -> fail(no, "unknown key '$key'")
                    }
                }
                else -> fail(no, "cannot read '$line' (a grid row is 16 of . and #)")
            }
        }
        flush()
        return out
    }

    /** "pkg/.Act" -> "pkg/pkg.Act". Null when malformed. */
    private fun component(value: String): String? {
        val pkg = value.substringBefore("/", "")
        val cls = value.substringAfter("/", "")
        if (pkg.isEmpty() || cls.isEmpty()) return null
        return "$pkg/${if (cls.startsWith(".")) pkg + cls else cls}"
    }

    /** The tile: 20x20 cells with pixel-rounded corners, the 16x16 motif in the middle. */
    private fun render(rows: List<String>?, bg: Int, fg: Int): BufferedImage {
        val img = BufferedImage(TILE * CELL, TILE * CELL, BufferedImage.TYPE_INT_ARGB)
        for (cy in 0 until TILE) for (cx in 0 until TILE) {
            if (corner(cx, cy)) continue
            val gx = cx - 2
            val gy = cy - 2
            val on = rows != null && gx in 0 until GRID && gy in 0 until GRID && rows[gy][gx] == '#'
            val color = if (on) fg else bg
            for (y in cy * CELL until (cy + 1) * CELL) for (x in cx * CELL until (cx + 1) * CELL) img.setRGB(x, y, color)
        }
        return img
    }

    /** Cells cut from each corner for the rounded tile: 3 per corner (an L of 2 + 1). */
    private fun corner(x: Int, y: Int): Boolean {
        val dx = minOf(x, TILE - 1 - x)
        val dy = minOf(y, TILE - 1 - y)
        return dx + dy < 2
    }
}

androidComponents {
    onVariants { variant ->
        val task = tasks.register<IconPackTask>("generate${variant.name.replaceFirstChar { it.uppercase() }}IconPack") {
            sourceDir.set(layout.projectDirectory.dir("../../assets/icons"))
        }
        variant.sources.res?.addGeneratedSourceDirectory(task, IconPackTask::resDir)
        variant.sources.assets?.addGeneratedSourceDirectory(task, IconPackTask::assetsDir)
    }
}
