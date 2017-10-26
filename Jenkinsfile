#!groovy

def version        = "1.0.0"
def proshopVersion = "1.0.0"
def catalogVersion = "1.0.0"
def accountVersion = "1.0.0"
def awsRegion      = "us-west-2"

try {
    node('docker') {

        // notifySlack('STARTED')

        withEnv([
                "COMPOSE_FILE=common-services.yml"
        ]) {

            stage('checkout') {
                checkout scm
            }

            stage('build AMIs') {
                sh "cd ${env.WORKSPACE}/deploy/docker-swarm/packer && docker run --rm hashicorp/packer:light build -var 'aws_region=${awsRegion}' -var 'ami_name=docker-swarm' -only=amazon-ebs -force packer.json"
            }

            stage('validate AWS configuration') {
                sh "docker run --rm hashicorp/terraform:light validate ${env.WORKSPACE}/deploy/docker-swarm/terraform/aws"
            }

            if (env.BRANCH_NAME =~ /(?i)^pr-/ || env.BRANCH_NAME == "master") {
                stage('plan staged deployment') {
                    sh "docker run --rm hashicorp/terraform:light plan -out -var 'environment=staging' staging-${version} ${env.WORKSPACE}/deploy/docker-swarm/terraform/aws"
                }

                try {
                    stage('provision staging') {
                        echo """
                            provision aws environment
                            deploy container
                        """
                    }

                    stage('production readiness checks') {
                        echo "run checks"
                    }

                    stage('security checkpoint') {
                        echo "security"
                    }

                    stage('UAT') {
                        def userInput = input(
                                id: 'userInput',
                                message: "Did staged build 'pass' or 'fail'?",
                                parameters: [choice(name: 'result', choices: 'pass\nfail', description: '')]
                        )

                        if (userInput == "fail") {
                            error("Staged build failed user acceptance testing")
                        }
                    }

                } catch (Exception e) {
                    throw e
                } finally {
                    stage('staging teardown') {
                        echo "teardown staged environment"
                        // notifyGithub("Staged build @ $ip was removed")
                        // slackSend(color: 'good', message: "Staged build @ $ip was removed")
                    }
                }
            }

            if (env.BRANCH_NAME == "master") {
                stage('plan blue/green deployment') {
                    sh "docker run --rm hashicorp/terraform:light plan -out production-${version} -var 'environment=production' ${env.WORKSPACE}/deploy/docker-swarm/terraform/aws"
                }

                stage('deploy to production') {
                    sh "docker run --rm hashicorp/terraform:light apply production-${version}"
                }

                stage('run production readiness tests') {
                    echo "prod tests"
                }
            }
        }
    }

    currentBuild.result = "SUCCESS"

} catch (Exception e) {
    error "Failed: ${e}"
    currentBuild.result = "FAILED"
} finally {
    // notifySlack(currentBuild.result)
}

def publishStagedInfo(String ip) {
    notifyGithub("${env.JOB_NAME}, build [#${env.BUILD_NUMBER}](${env.BUILD_URL}) - Staged deployment can be viewed at: [https://$ip](https://$ip). Staged builds require UAT, click on Jenkins link when finished with UAT to mark the build as 'pass' or 'failed'")
    slackSend(color: 'good',
            message: "${env.JOB_NAME}, build #${env.BUILD_NUMBER} ${env.BUILD_URL} - Staged deployment can be viewed at: https://$ip. Staged builds require UAT, click on Jenkins link when finished with testing to mark the build as 'pass' or 'failed'")
}

def notifyGithub(String comment) {
    def pr  = env.BRANCH_NAME.split("-")[1].trim()
    def pat = readFile('/root/.pat').trim()
    sh "curl -H \"Content-Type: application/json\" -u ifg-bot:$pat -X POST -d '{\"body\": \"$comment\"}' https://api.github.com/repos/ifishgroup/ifg-proshop/issues/$pr/comments"
}

def convertBranchName(String name) {
    return name.replaceAll('/', '_')
}

def notifySlack(String buildStatus) {
    if (env.BRANCH_NAME =~ /(?i)^pr-/ || env.BRANCH_NAME == "master") {
        echo "currentBuild.result=$buildStatus"

        if (buildStatus == null || buildStatus == "") {
            buildStatus = 'FAILED'
        }

        def subject = "${buildStatus}: Job '${env.JOB_NAME}, build #${env.BUILD_NUMBER}'"
        def summary = "${subject} (${env.BUILD_URL})"

        if (buildStatus == 'STARTED') {
            color = 'warning'
        } else if (buildStatus == 'SUCCESS') {
            color = 'good'
        } else {
            color = 'danger'
        }

        slackSend(color: color, message: summary)
    }
}
