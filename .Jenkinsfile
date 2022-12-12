pipeline {
    agent { label 'sbuild' }
    stages {
        stage('Build Debian package') {
            when {
                branch 'debian'
            }
            steps {
                script {
                    sh 'gbp buildpackage'
                }
                archiveArtifacts allowEmptyArchive: true, artifacts: 'build-area/*.gz,build-area/*.bz2,build-area/*.xz,build-area/*.deb,build-area/*.dsc,build-area/*.changes,build-area/*.buildinfo,build-area/*.build,build-area/lintian.txt'
            }
        }

        stage('Upload Debian package') {
            when {
                branch 'debian'
            }
            steps {
                script {
                    sh 'rsync -avP build-area/bkctld* pub.evolix.org:/srv/upload/'
                }
            }
        }
    }
    post {
        // Clean after build
        always {
            cleanWs()
        }
    }
}
