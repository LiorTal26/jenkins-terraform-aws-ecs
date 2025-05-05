pipeline {
    agent any

    stages {
        stage('Hello World') {
            steps {
                echo 'Hello, World!'
            }
        }

        stage('Check Terraform Version') {
            steps {
                sh 'terraform --version'
            }
        }

        stage('Check Docker Version') {
            steps {
                sh 'docker --version'
            }
        }
    }
}