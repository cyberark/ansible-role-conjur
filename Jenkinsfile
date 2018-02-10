#!/usr/bin/env groovy

pipeline {
  agent { label 'executor-v2' }

  options {
    timestamps()
    buildDiscarder(logRotator(daysToKeepStr: '14'))
  }

  stages {
    stage('Build') {
      steps {
        sh './build.sh'

        archiveArtifacts artifacts: 'ansible-role-conjur.tar.gz', fingerprint: true
      }
    }

    stage('Run tests') {
      steps {
        sh 'cd tests; ./test.sh'

        junit 'tests/junit/*'
      }
    }
  }

  post {
    always {
      cleanupAndNotify(currentBuild.currentResult)
    }
  }
}
