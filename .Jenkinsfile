pipeline {
    agent { label 'docker' }
    stages {
        stage('Build Debian package') {
            agent {
                docker {
                    image 'evolix/gbp:bullseye'
                    args '-u root --privileged -v /tmp:/tmp'
                }
            }
            when {
                branch 'debian'
            }
            steps {
                script {
                    sh 'mk-build-deps --install --remove debian/control'
                    sh 'rm -rf source'
                    sh "gbp clone --debian-branch=$GIT_BRANCH $GIT_URL source"
                    sh 'cd source && git checkout $GIT_BRANCH && gbp buildpackage -us -uc'
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
                 /* No crendentials yet
                    sh 'rsync -avP /tmp/bkctld/ droneci@pub.evolix.net:/home/droneci/bkctld/'
                  */
                }
            }
        }
    }
    post {
        // Clean after build
        always {
            cleanWs(cleanWhenNotBuilt: false,
                    deleteDirs: true,
                    disableDeferredWipeout: true,
                    notFailBuild: true,
                    patterns: [[pattern: '.gitignore', type: 'INCLUDE'],
                               [pattern: '.propsfile', type: 'EXCLUDE']])
        }
    }
}
