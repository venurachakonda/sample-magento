pipeline {
	agent any

	environment {
		AWS_DEFAULT_REGION="us-east-1"
		AWS_BIN = '/usr/bin/aws'
		FILE='vuse-mage2-build.tar.bz2'
		JOB_NAME="${env.JOB_NAME}"
		BUILD_NUMBER="${env.BUILD_NUMBER}"
		ASG_NAME="VR1D1MAG"
	}
  options {
    ansiColor colorMapName: 'XTerm'
  }

	stages {

		stage('Checkout') {
		  steps {
		    deleteDir()
				checkout scm
		    }
		  }

		stage('Setup') {
			steps {
				   dir('raybon-template') {
             // TODO: update/remove the branch name
             git branch: "master", credentialsId: 'automation', url: 'git@bitbucket.org:vrachakonda/raybon.git'
           }
		  	   script {
                 /* Check the GIT_BRANCH to compute build version and target environment */
                 if (env.GIT_BRANCH ==~ 'origin/dev-01') {
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

		  	   	/* Set Params */
		  	   	if ( env.Target == 'dev' ) {
								env.VPC_ID = sh( script: ''' cat raybon-template/02-data/env-data.json | jq -r ".${Target}.vpc_id" ''', returnStdout: true ).trim()
								env.SUBNET_ID = sh( script: ''' cat raybon-template/02-data/env-data.json | jq -r ".${Target}.subnet_id" ''', returnStdout: true ).trim()
								env.SECURITY_GROUP_IDS = sh( script: ''' cat raybon-template/02-data/env-data.json | jq -r ".${Target}.security_group_ids" ''', returnStdout: true ).trim()
								env.SOURCE_AMI = sh( script: ''' cat raybon-template/02-data/env-data.json | jq -r ".${Target}.source_ami" ''', returnStdout: true ).trim()
								env.APP_NAME = "${env.Target}-vuse-mage2"

		  	   	} else if ( env.Target == 'qa' ) {
							env.VPC_ID = sh( script: ''' cat raybon-template/02-data/env-data.json | jq -r ".${Target}.vpc_id" ''', returnStdout: true ).trim()
							env.SUBNET_ID = sh( script: ''' cat raybon-template/02-data/env-data.json | jq -r ".${Target}.subnet_id" ''', returnStdout: true ).trim()
							env.SECURITY_GROUP_IDS = sh( script: ''' cat raybon-template/02-data/env-data.json | jq -r ".${Target}.security_group_ids" ''', returnStdout: true ).trim()
							env.SOURCE_AMI = sh( script: ''' cat raybon-template/02-data/env-data.json | jq -r ".${Target}.source_ami" ''', returnStdout: true ).trim()

		  	   	} else if ( env.Target == 'uat' ) {
		  	   	  env.VERSION     = 'v' + env.PACKAGE_VERSION + '-' + env.BUILD_NUMBER + '-rc'
		  	   	} else if ( env.Target == 'production' ) {
		  	   	  env.VERSION     = 'v' + env.PACKAGE_VERSION + '-' + env.BUILD_NUMBER + '-rc'
		  	   	} else {
		  	   	  error "Unknown Target: ${env.Target}"
		  	   	}
		      }

					withCredentials([[
						 $class: 'AmazonWebServicesCredentialsBinding',
						 credentialsId: 'aws-creds',
						 accessKeyVariable: 'AWS_ACCESS_KEY_ID',
						 secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
					]]) {
						 sh '''
							 export AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID} ; export AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY} ; export AWS_DEFAULT_REGION=${AWS_DEFAULT_REGION}
							 template='{"aws_default_region": "%s", "vpc_id": "%s", "subnet_id": "%s", "security_group_ids": "%s", "instance_type": "t2.large", "ssh_username": "centos", "source_ami": "%s"}'
               json_string=$(printf "$template" "${AWS_DEFAULT_REGION}" "${VPC_ID}" "${SUBNET_ID}" "${SECURITY_GROUP_IDS}" "${SOURCE_AMI}")
							 echo $json_string | jq -r "." | tee -a raybon-template/01-packer/vars-packer.json
						 '''
					}
			}
		}

		stage('Build Artifact') {
		    steps {
					dir('raybon-template') {
						// TODO: update/remove the branch name
						git branch: "master", credentialsId: 'automation', url: 'git@bitbucket.org:vrachakonda/raybon.git'
					}
					sh '''
					  tar cvjf "${FILE}" * --exclude=raybon-template
					'''
					archiveArtifacts artifacts: '*.tar.bz2', fingerprint: true
		    }

				post {
					success {
						archiveArtifacts(artifacts: '*.tar.bz2', fingerprint: true)
					}
				}
	  }


		stage('Build AMI') {
			steps {
				dir('raybon-template') {
					// TODO: update/remove the branch name
					git branch: "master", credentialsId: 'automation', url: 'git@bitbucket.org:vrachakonda/raybon.git'
				}

				withCredentials([string(credentialsId: 'VAULT_PASS', variable: 'TOKEN')]) {
					 sh ''' echo "${TOKEN}" > raybon-template/01-packer/.tmpvault '''
				}
				sh "sed -i 's#DIR_NAME#${Target}#' raybon-template/01-packer/ansible/vars.yml"
				sh "sed -i 's#VERSION#${BUILD_NUMBER}#' raybon-template/01-packer/ansible/vars.yml"
				sh "sed -i 's#ENVIRONMENT#${Target}#' raybon-template/01-packer/ansible/vars.yml"

		    withCredentials([[
            $class: 'AmazonWebServicesCredentialsBinding',
            credentialsId: 'aws-creds',
            accessKeyVariable: 'AWS_ACCESS_KEY_ID',
            secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
        ]]) {
            sh '''
		    		  export AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID} ; export AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY} ; export AWS_DEFAULT_REGION=${AWS_DEFAULT_REGION}
							source ${HOME}/.bashrc
							cp *.tar.bz2 raybon-template/01-packer
							cd raybon-template/01-packer
							packer validate -var-file=vars-packer.json -var revision=${BUILD_NUMBER} packer.json
							packer build -var-file=vars-packer.json -var revision=${BUILD_NUMBER} packer.json
            '''
						script {
							env.IMAGE_ID = sh( script: ''' cat raybon-template/01-packer/manifest.json | jq -r '.builds[-1].artifact_id' |  cut -d':' -f2 ''', returnStdout: true ).trim()
							echo "Image ID: ${IMAGE_ID}"
						}

        }
			}

			post {
				failure {
					sh 'echo Failed'
					deleteDir()
				}
			}
		}

		stage('Create New Launch Configuration') {
			steps {
				environment name: 'IMAGE_ID', value: "${env.IMAGE_ID}"
		        withCredentials([[
                  $class: 'AmazonWebServicesCredentialsBinding',
                  credentialsId: 'aws-creds',
                  accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                  secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
                ]]) {
                  sh '''
		          export AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID} ; export AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY} ; export AWS_DEFAULT_REGION=${AWS_DEFAULT_REGION};
			        cd raybon-template/05-util-scripts && ASG_NAME="$ASG_NAME" make -e create-lc
                  '''
                }
			}
		}

		stage('Update ASG') {
			steps {
		        withCredentials([[
                  $class: 'AmazonWebServicesCredentialsBinding',
                  credentialsId: 'aws-creds',
                  accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                  secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
        	    ]]) {
                sh '''
		          export AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID} ; export AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY} ; export AWS_DEFAULT_REGION=${AWS_DEFAULT_REGION}
			      cd raybon-template/05-util-scripts && ASG_NAME="$ASG_NAME" make -e update-asg
			    '''
                }
			}
		}



		stage('Scale up ASG') {
			steps {
		        withCredentials([[
                $class: 'AmazonWebServicesCredentialsBinding',
                credentialsId: 'aws-creds',
                accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
        	    ]]) {
                  sh '''
		          export AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID} ; export AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY} ; export AWS_DEFAULT_REGION=${AWS_DEFAULT_REGION}
			      	cd raybon-template/05-util-scripts && ASG_NAME="$ASG_NAME" make -e scale-up
			      '''
          		}
			}
		}


		stage('Scale down ASG') {
			steps {
		        withCredentials([[
                $class: 'AmazonWebServicesCredentialsBinding',
                credentialsId: 'aws-creds',
                accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
        	    ]]) {
                  sh '''
		          export AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID} ; export AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY} ; export AWS_DEFAULT_REGION=${AWS_DEFAULT_REGION}
			      	cd raybon-template/05-util-scripts && ASG_NAME="$ASG_NAME" make -e scale-down
			      '''
          		}
			}
		}

		stage('setup cron') {
			steps {
		        withCredentials([[
                $class: 'AmazonWebServicesCredentialsBinding',
                credentialsId: 'aws-creds',
                accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
        	    ]]) {
								sh '''
						export AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID} ; export AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY} ; export AWS_DEFAULT_REGION=${AWS_DEFAULT_REGION}
						cd raybon-template/05-util-scripts && ASG_NAME="$ASG_NAME" make -e setup-cron
					'''
          		}
			}
		}

		stage('clean up') {
			steps {
		        withCredentials([[
                $class: 'AmazonWebServicesCredentialsBinding',
                credentialsId: 'aws-creds',
                accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
        	    ]]) {
                  sh 'cd raybon-template/05-util-scripts/utils && bash cleanup.sh'
          		}
			}
		}
	}
}
