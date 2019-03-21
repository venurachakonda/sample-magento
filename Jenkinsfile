pipeline {
	agent any

	environment {
		AWS_DEFAULT_REGION="us-east-1"
		AWS_BIN = '/usr/bin/aws'
		FILE='vuse-mage2-build.tar.bz2'
		JOB_NAME="${env.JOB_NAME}"
		BUILD_NUMBER="${env.BUILD_NUMBER}"
		APP_NAME="vr-sample"
		ASG_NAME="vr-asg1"
	}
  options {
    ansiColor colorMapName: 'XTerm'
  }

	stages {
		stage('Setup') {
			steps {
		  	   script {
                 /* Check the GIT_BRANCH to compute build version and target environment */
                 if (env.GIT_BRANCH ==~ 'origin/dev-new-pack') {
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
								env.DEV_VPC_ID = 'vpc-e5cf1c81'
								env.SUBNET_NAME = 'subnet-e4f4c3bd'
		  	   	} else if ( env.Target == 'qa' ) {
		  	   	  env.VERSION     = 'v' + env.PACKAGE_VERSION + '-' + env.BUILD_NUMBER + '-rc'
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
							 VPC_ID=$(aws ec2 describe-vpcs --filters Name=vpc-id,Values=${DEV_VPC_ID} --query "Vpcs[0].VpcId" --output text)
							 SUBNET_ID=$(aws ec2 describe-subnets --filter Name=vpc-id,Values=${DEV_VPC_ID} Name=subnet-id,Values=${SUBNET_NAME} --query 'Subnets[0].SubnetId' --output text)
							 sed -i "s@VPC_ID@\${VPC_ID}@" ami_vars.json
							 sed -i "s@SUBNET_ID@\${SUBNET_ID}@" ami_vars.json
						 '''
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

				post {
					success {
						archiveArtifacts(artifacts: '*.tar.bz2', fingerprint: true)
					}
				}
	  }

/*
		stage('Build AMI') {
			steps {
		    withCredentials([[
            $class: 'AmazonWebServicesCredentialsBinding',
            credentialsId: 'aws-creds',
            accessKeyVariable: 'AWS_ACCESS_KEY_ID',
            secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
        ]]) {
            sh '''
		    		  export AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID} ; export AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY} ; export AWS_DEFAULT_REGION=${AWS_DEFAULT_REGION}
							source ${HOME}/.bashrc
							vpc=$(aws ec2 describe-vpcs --filters Name=vpc-id,Values=vpc-e5cf1c81 --query "Vpcs[0].VpcId")
							subnet=subnet-e4f4c3bd
							security_groups="sg-0d0a1ec5f29912f2f"
							packer build -var vpc_id=${vpc} -var subnet_id=${subnet} -var security_group_ids=${security_groups} -var revision=${BUILD_NUMBER} -var 'vpc_region=us-east-1' -var ssh_username="centos" -var instance_type="t2.large" packer.json
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
*/
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
