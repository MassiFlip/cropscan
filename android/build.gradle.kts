allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val buildRoot = rootProject.layout.projectDirectory.dir("../build")
rootProject.layout.buildDirectory.set(buildRoot)

subprojects {
    layout.buildDirectory.set(buildRoot.dir(name))
    if (path != ":app") {
        evaluationDependsOn(":app")
    }
}

tasks.register<Delete>("clean") {
    delete(buildRoot)
}
