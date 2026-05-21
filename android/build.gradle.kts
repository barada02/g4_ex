import com.android.build.gradle.LibraryExtension
import org.gradle.api.Project

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

subprojects {
    val updateProject = { proj: Project ->
        if (proj.plugins.hasPlugin("com.android.application") ||
            proj.plugins.hasPlugin("com.android.library")
        ) {
            if (proj.name == "isar_flutter_libs") {
                proj.extensions.findByType(LibraryExtension::class.java)?.apply {
                    namespace = "dev.isar.isar_flutter_libs"
                }
            }
        }
    }

    if (project.state.executed) {
        updateProject(project)
    } else {
        project.afterEvaluate {
            updateProject(project)
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
