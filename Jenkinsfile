pipeline {
	agent any

	environment {
		AWS_DEFAULT_REGION="us-east-1"
		AWS_BIN = '/bin/aws'
		FILE='build.tar.bz2'                 //## Generated TAR file#
	}
    options {
      ansiColor colorMapName: 'XTerm'
    }

	stages {
		stage('Setup') {
			steps {
		  	    script {
                    /* Check the GIT_BRANCH to compute build version and target environment */
                    if (env.GIT_BRANCH ==~ 'origin/dev') {
                      env.Target = 'dev'
                    } else if (env.GIT_BRANCH ==~ 'origin/qa') {
                      env.Target = 'qa'
                    } else if (env.GIT_BRANCH ==~ 'origin/uat') {
                      env.Target = 'uat'
										} else if (env.GIT_BRANCH == 'origin/master') {
												env.Target = 'production'
                    } else {
                      error "Unknown branch type: ${env.GIT_BRANCH}"
                    }
							// Temporary Stub, find version of package
		  	    	env.PACKAGE_VERSION = sh(
			    		script: """
			    			echo "1"
			    		""",
			    		returnStdout: true
			    		).trim()

		  	    	/* create version with jenkins build number */

		  	    	if ( env.Target == 'dev' || env.Target == 'qa' ) {
		  	    	  env.VERSION     = 'v' + env.PACKAGE_VERSION + '-' + env.BUILD_NUMBER
		  	    	} else if ( env.Target == 'uat' || env.Target == 'production' ) {
		  	    	  env.VERSION     = 'v' + env.PACKAGE_VERSION + '-' + env.BUILD_NUMBER + '-rc'
		  	    	} else {
		  	    	  error "Unknown Target: ${env.Target}"
		  	    	}
		        }
			}
		}
		stage('Checkout') {
		  steps {
		    deleteDir()
				checkout scm
		    }
		  }

		stage('Build Artifact') {
		    steps {
					sh '''
					  tar cvjf "${FILE}" *
					'''
					archiveArtifacts artifacts: '*.tar.bz2', fingerprint: true
		    }
	  }

		stage('Deploy to Dev') {
			steps {
				timeout(time: 15, unit: 'MINUTES') {
				  sh './scrpts/dev_deploy.sh'
				}
			}
		}

		stage('Create Snapshot of Dev') {
			steps {
		    withCredentials([[
            $class: 'AmazonWebServicesCredentialsBinding',
            credentialsId: 'aws-creds',
            accessKeyVariable: 'AWS_ACCESS_KEY_ID',
            secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
        ]]) {
            sh '''
		    		  export AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID} ; export AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY} ; export AWS_DEFAULT_REGION="${AWS_DEFAULT_REGION}"
		    			${AWS_BIN} ec2 describe-instances'
              sleep 1m
		    			${AWS_BIN} iam get-user
            '''
        }
			}
		}
	}
}
