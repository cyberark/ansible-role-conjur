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
        sh 'cd tests; ./test.sh'

        junit 'tests/junit/*'
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
      cleanupAndNotify(currentBuild.currentResult)
    }
  }
}
