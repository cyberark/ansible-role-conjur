#!/usr/bin/env groovy

pipeline {
  agent { label 'executor-v2' }

  options {
    timestamps()
    buildDiscarder(logRotator(daysToKeepStr: '14'))
  }

  stages {
    stage('Run tests') {
      steps {
        sh './test.sh'

        // junit ''
      }
    }

    stage("Publish 'conjur' role to Galaxy") {
      when {
        branch 'master'
      }
      steps {
        sh './publish.sh'
      }
    }
  }

  post {
    always {
      sh 'sudo chown -R jenkins:jenkins .'  // bad docker mount creates unreadable files TODO fix this
      deleteDir()  // delete current workspace, for a clean build
    }
    failure {
      slackSend(color: 'danger', message: "${env.JOB_NAME} #${env.BUILD_NUMBER} FAILURE (<${env.BUILD_URL}|Open>)")
    }
    unstable {
      slackSend(color: 'warning', message: "${env.JOB_NAME} #${env.BUILD_NUMBER} UNSTABLE (<${env.BUILD_URL}|Open>)")
    }
  }
}
