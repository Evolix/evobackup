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
                archiveArtifacts allowEmptyArchive: true, artifacts: '*.gz,*.bz2,*.xz,*.deb,*.dsc,*.changes,*.buildinfo,lintian.txt'
            }
        }

        stage('Upload Debian package') {
            when {
                branch 'debian'
            }
            steps {
                script {
                    sh 'echo Dummy line to remove once something actually happens.'
                 /* No crendentials yet.
                    sh 'rsync -avP bkctld* droneci@pub.evolix.net:/home/droneci/bkctld/'
                  */
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
