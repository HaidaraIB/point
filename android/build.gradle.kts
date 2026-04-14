import org.gradle.api.tasks.compile.JavaCompile
import org.gradle.api.logging.LogLevel

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

// Suppress third-party Java unchecked/deprecation notes during Android builds.
subprojects {
    tasks.withType<JavaCompile>().configureEach {
        options.isWarnings = false
        logging.captureStandardError(LogLevel.DEBUG)
        doFirst {
            if (!options.compilerArgs.contains("-nowarn")) {
                options.compilerArgs.add("-nowarn")
            }
            if (!options.compilerArgs.contains("-Xlint:none")) {
                options.compilerArgs.add("-Xlint:none")
            }
        }
    }
}

// Work around intermittent Windows file-lock failures in plugin lint cache.
subprojects {
    tasks.matching { it.name == "lintVitalAnalyzeRelease" }.configureEach {
        enabled = false
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
