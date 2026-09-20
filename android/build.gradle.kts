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
    afterEvaluate {
        val androidExt = extensions.findByName("android")
        if (androidExt != null) {
            try {
                androidExt.javaClass.getMethod("compileSdkVersion", Int::class.javaPrimitiveType).invoke(androidExt, 35)
                
                val namespaceProp = androidExt.javaClass.getMethod("getNamespace").invoke(androidExt)
                if (namespaceProp == null) {
                    androidExt.javaClass.getMethod("setNamespace", String::class.java).invoke(androidExt, project.group.toString())
                }
            } catch (e: Exception) {
                // Ignore reflection errors
            }
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
