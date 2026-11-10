pipeline {
    agent any

    tools {
        jdk 'jdk17'
        maven 'maven3'
    }

    options {
        timestamps()
        disableConcurrentBuilds()
        skipDefaultCheckout(true)
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Locate project') {
            steps {
                script {
                    if (fileExists('practice/practice-1/code/pom.xml')) {
                        env.PROJECT_DIR = 'practice/practice-1/code'
                    } else if (fileExists('code/pom.xml')) {
                        env.PROJECT_DIR = 'code'
                    } else {
                        error 'Could not find the practice-1 code directory.'
                    }
                }
            }
        }

        stage('Build and test') {
            steps {
                dir(env.PROJECT_DIR) {
                    script {
                        if (isUnix()) {
                            sh 'mvn --batch-mode clean verify'
                        } else {
                            bat 'mvn --batch-mode clean verify'
                        }
                    }
                }
            }
            post {
                always {
                    junit testResults: "${env.PROJECT_DIR}/target/surefire-reports/*.xml", allowEmptyResults: true
                }
            }
        }

        stage('Publish artifact') {
            steps {
                archiveArtifacts artifacts: "${env.PROJECT_DIR}/target/practice-1.jar", fingerprint: true
            }
        }

        stage('Deploy') {
            when {
                expression {
                    env.BRANCH_NAME == 'main' || env.GIT_BRANCH == 'origin/main' || env.GIT_BRANCH == 'main'
                }
            }
            steps {
                echo 'Beginner CD complete: the tested JAR is published in this Jenkins build.'
                echo 'Download practice-1.jar from Build Artifacts and run: java -jar practice-1.jar'
            }
        }
    }

    post {
        success {
            echo 'Pipeline succeeded.'
        }
        failure {
            echo 'Pipeline failed. Open the failed stage and read its console output.'
        }
    }
}

