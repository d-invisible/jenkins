pipeline {
    agent any

    tools {
        jdk 'jdk21'
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
                    if (fileExists('pom.xml')) {
                        env.PROJECT_DIR = '.'
                        env.PROJECT_PREFIX = ''
                    } else if (fileExists('practice/practice-1/code/pom.xml')) {
                        env.PROJECT_DIR = 'practice/practice-1/code'
                        env.PROJECT_PREFIX = 'practice/practice-1/code/'
                    } else {
                        error 'Could not find the p1-simple-java-app Maven project.'
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
                    junit testResults: "${env.PROJECT_PREFIX}target/surefire-reports/*.xml", allowEmptyResults: true
                }
            }
        }

        stage('Publish artifact') {
            steps {
                archiveArtifacts artifacts: "${env.PROJECT_PREFIX}target/practice-1.jar", fingerprint: true
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

