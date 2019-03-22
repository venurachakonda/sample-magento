pipeline {
	agent any

	environment {
		AWS_DEFAULT_REGION="us-west-2"
		AWS_BIN = '/usr/bin/aws'
		FILE='vuse-mage2-build.tar.bz2'
		JOB_NAME="${env.JOB_NAME}"
		BUILD_NUMBER="${env.BUILD_NUMBER}"
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
					  tar cvjf  "${FILE}" * --exclude=raybon-template
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
				sh "sed -i 's#DIR_NAME#${Target}#' raybon-template/01-packer/vars.yml"
				sh "sed -i 's#VERSION#${BUILD_NUMBER}#' raybon-template/01-packer/vars.yml"
		    withCredentials([[
            $class: 'AmazonWebServicesCredentialsBinding',
            credentialsId: 'aws-creds',
            accessKeyVariable: 'AWS_ACCESS_KEY_ID',
            secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
        ]]) {
            sh '''
		    		  export AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID} ; export AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY} ; export AWS_DEFAULT_REGION=${AWS_DEFAULT_REGION}
							source ${HOME}/.bashrc
							cd raybon-template/01-packer
							packer validate -var-file=vars-packer.json -var revision=${BUILD_NUMBER} packer.json
							packer build -var-file=vars-packer.json -var revision=${BUILD_NUMBER} packer.json
            '''
        }
			}

			post {
				failure {
					sh 'echo Failed'
					deleteDir()
				}
			}
		}

/*
		stage('Create AMI') {
			steps {
		    withCredentials([[
            $class: 'AmazonWebServicesCredentialsBinding',
            credentialsId: 'aws-creds',
            accessKeyVariable: 'AWS_ACCESS_KEY_ID',
            secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
        ]]) {
            sh '''
		    		  export AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID} ; export AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY} ; export AWS_DEFAULT_REGION=${AWS_DEFAULT_REGION}
							source ./scripts/functions.sh
							create_image > image_id.txt
							check_image_status
							tag_image
            '''
						script {
							env.IMAGE_ID = readFile('image_id.txt').trim()
						}
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
							source ./scripts/functions.sh
							capture_old_launch_config
							create_new_launch_configuration
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
							source ./scripts/functions.sh
							update_asg_launch_configuration
						'''
        }
			}
		}
*/
	}
}
