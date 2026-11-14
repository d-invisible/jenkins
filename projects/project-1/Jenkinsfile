pipeline {
    agent none

    triggers {
        githubPush()
    }

    parameters {
        string(
            name: 'NOTIFICATION_EMAIL',
            defaultValue: '',
            description: 'Email address for approval, success, and failure notifications.',
            trim: true
        )
        string(
            name: 'APPROVER_USERS',
            defaultValue: 'admin',
            description: 'Comma-separated Jenkins user IDs allowed to approve deployment.',
            trim: true
        )
    }

    options {
        timestamps()
        disableConcurrentBuilds()
        skipDefaultCheckout(true)
        preserveStashes(buildCount: 5)
    }

    stages {
        stage('CI on Agent 1') {
            agent {
                label 'spring-gradle-agent'
            }

            environment {
                GRADLE_USER_HOME = '/home/jenkins-agent/.gradle'
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
                            if (fileExists('code/build.gradle')) {
                                env.PROJECT_DIR = 'code'
                                env.PROJECT_PREFIX = 'code/'
                            } else if (fileExists('projects/project-1/code/build.gradle')) {
                                env.PROJECT_DIR = 'projects/project-1/code'
                                env.PROJECT_PREFIX = 'projects/project-1/code/'
                            } else {
                                error 'Could not find the Project 1 Gradle application.'
                            }
                        }
                    }
                }

                stage('Verify agent') {
                    steps {
                        sh '''
                            set -eu
                            echo "Node: $NODE_NAME"
                            echo "Workspace: $WORKSPACE"
                            chmod +x "$PROJECT_DIR/gradlew"
                            java -version
                            git --version
                            "$PROJECT_DIR/gradlew" --version
                        '''
                    }
                }

                stage('Unit tests') {
                    steps {
                        dir(env.PROJECT_DIR) {
                            sh './gradlew clean test --build-cache --no-daemon'
                        }
                    }
                    post {
                        always {
                            junit testResults: "${env.PROJECT_PREFIX}build/test-results/test/*.xml"
                            archiveArtifacts(
                                artifacts: "${env.PROJECT_PREFIX}build/reports/tests/**,${env.PROJECT_PREFIX}build/reports/jacoco/**",
                                allowEmptyArchive: true
                            )
                        }
                    }
                }

                stage('Build executable JAR') {
                    steps {
                        dir(env.PROJECT_DIR) {
                            sh './gradlew bootJar --build-cache --no-daemon'
                        }
                    }
                }

                stage('Static code scan') {
                    steps {
                        dir(env.PROJECT_DIR) {
                            sh './gradlew spotbugsMain --build-cache --no-daemon'
                        }
                    }
                    post {
                        always {
                            archiveArtifacts(
                                artifacts: "${env.PROJECT_PREFIX}build/reports/spotbugs/**",
                                allowEmptyArchive: true
                            )
                        }
                    }
                }

                stage('Dependency security scan') {
                    steps {
                        withCredentials([string(credentialsId: 'nvd-api-key', variable: 'NVD_API_KEY')]) {
                            dir(env.PROJECT_DIR) {
                                sh './gradlew dependencyCheckAnalyze --no-daemon'
                            }
                        }
                    }
                    post {
                        always {
                            archiveArtifacts(
                                artifacts: "${env.PROJECT_PREFIX}build/reports/dependency-check-*",
                                allowEmptyArchive: true
                            )
                        }
                    }
                }

                stage('Publish CI artifact') {
                    steps {
                        archiveArtifacts(
                            artifacts: "${env.PROJECT_PREFIX}build/libs/project-1.jar",
                            fingerprint: true
                        )
                        dir(env.PROJECT_DIR) {
                            stash(
                                name: 'project-1-deployable',
                                includes: 'build/libs/project-1.jar'
                            )
                        }
                    }
                }

                stage('Email: ready for approval') {
                    steps {
                        script {
                            if (params.NOTIFICATION_EMAIL?.trim()) {
                                emailext(
                                    to: params.NOTIFICATION_EMAIL,
                                    subject: "[READY] ${env.JOB_NAME} #${env.BUILD_NUMBER} awaits deployment approval",
                                    body: "Build, tests, and security scans passed. Approve or reject deployment at: ${env.BUILD_URL}input/"
                                )
                            } else {
                                echo 'NOTIFICATION_EMAIL is empty; approval email skipped.'
                            }
                        }
                    }
                }
            }
        }

        stage('Confirm deployment') {
            options {
                timeout(time: 30, unit: 'MINUTES')
            }
            steps {
                script {
                    env.APPROVED_BY = input(
                        id: 'project1DeployApproval',
                        message: "Deploy ${env.JOB_NAME} #${env.BUILD_NUMBER} to the target VM?",
                        ok: 'Deploy',
                        submitter: params.APPROVER_USERS,
                        submitterParameter: 'APPROVED_BY'
                    )
                    echo "Deployment approved by ${env.APPROVED_BY}"
                }
            }
        }

        stage('Deploy with Publish Over SSH') {
            agent {
                label 'spring-gradle-agent'
            }
            steps {
                unstash 'project-1-deployable'

                sshPublisher(
                    failOnError: true,
                    continueOnError: false,
                    publishers: [
                        sshPublisherDesc(
                            configName: 'project-1-target',
                            verbose: true,
                            transfers: [
                                sshTransfer(
                                    sourceFiles: 'build/libs/project-1.jar',
                                    removePrefix: 'build/libs',
                                    remoteDirectory: 'incoming',
                                    execCommand: 'sudo /usr/local/sbin/deploy-project-1.sh /home/deployer/incoming/project-1.jar',
                                    execTimeout: 180000,
                                    flatten: false,
                                    makeEmptyDirs: false,
                                    noDefaultExcludes: false,
                                    patternSeparator: '[, ]+',
                                    remoteDirectorySDF: false,
                                    cleanRemote: false,
                                    excludes: '',
                                    usePty: false
                                )
                            ],
                            usePromotionTimestamp: false,
                            useWorkspaceInPromotion: false
                        )
                    ]
                )
            }
        }
    }

    post {
        success {
            script {
                if (params.NOTIFICATION_EMAIL?.trim()) {
                    emailext(
                        to: params.NOTIFICATION_EMAIL,
                        subject: "[SUCCESS] ${env.JOB_NAME} #${env.BUILD_NUMBER} deployed",
                        body: "Deployment completed successfully. Approved by: ${env.APPROVED_BY ?: 'not recorded'}. Build: ${env.BUILD_URL}"
                    )
                }
            }
        }
        failure {
            script {
                if (params.NOTIFICATION_EMAIL?.trim()) {
                    emailext(
                        to: params.NOTIFICATION_EMAIL,
                        subject: "[FAILURE] ${env.JOB_NAME} #${env.BUILD_NUMBER}",
                        body: "The pipeline failed. Review Console Output: ${env.BUILD_URL}console"
                    )
                }
            }
        }
        aborted {
            script {
                if (params.NOTIFICATION_EMAIL?.trim()) {
                    emailext(
                        to: params.NOTIFICATION_EMAIL,
                        subject: "[ABORTED] ${env.JOB_NAME} #${env.BUILD_NUMBER}",
                        body: "The pipeline or deployment approval was aborted/timed out. Build: ${env.BUILD_URL}"
                    )
                }
            }
        }
    }
}

