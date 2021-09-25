# Airline Ticket Booking Network

Eagle Airlines develop a unique blockchain-based ticket management system.

## Project structure

```
airline-booking-repo
    |-block-explorer
    |-elasticsearch
    |-filebeat
    |-logstash
    |-metricbeat
    |-node1
    |-node2
    |-node3
    |-node4
```

## Services used

1. Hyperledger-Besu nodes (node1-node4)
2. Grafana/Prometheus
   ![Grafana dashboard](images/Grafanadashboard.png)
   ![Prometheus dashboard](images/Prometheusdashboard.png)
   ![Healthcheck dashboard](images/Prometheusdashboard.png)
3. ElasticSearch/Kibana
   ![Kibana dashboard](images/Kibanalogs.png)
4. Block Explorer
   ![Block explorer](images/Blockexplorer.png)
   ![Block explorer](images/Blockexplorer1.png)

## Installation instructions

### Local installation

Prerequisites : Git, Docker/docker-compose, node

Clone the repository

```
git clone https://github.com/Lrnd-Devops1/airline-booking-repo.git

```

Run docker compose to spin up the services in local

```
cd airline-booking-repo

docker-compose up -d
```

Verify the successful installation by navigating to grafana dashboard (http://localhost:3001) and see he data is display as the below screenshot

![Grafana dashboard](images/Grafanadashboard.png)

Once successful your network is ready to deploy contract.

### AWS Cloud installation

From AWS console choose EC2 nad create an instance as per the following configuration.

```
Note: Cloudformation template with ebs volume did't work as the AWS educate account has limited privileges
```

1. Select the "Amazon Linux 2 AMI"
   ![Select AMI](images/EC2-Instance-AMI.png)
2. Select t2.medium
   ![Select AMI](images/InstanceType-T2-Medium.png)
3. Add storage - 30GB
   ![Add storage](images/EC2-Add-Storage.png)
4. Configure security group
   SSH with 22, HTTP with 80, All TCP with 0-65535
   ![Add storage](images/EC2-SecurityGroup.png)
5. Launch the instance

Once the instance is up and running login to the instance from bash or putty and execute the following scripts to deploy the nodes

```bash
sudo yum update -y

sudo amazon-linux-extras install docker -y

sudo service docker start

sudo usermod -a -G docker ec2-user

sudo curl -L https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m) -o /usr/local/bin/docker-compose

sudo yum install git

mkdir app

cd app
git clone https://github.com/Lrnd-Devops1/airline-booking-repo.git

sudo chmod +x /usr/local/bin/docker-compose

sudo usermod -aG docker ec2-user

newgrp docker

docker-compose up -d

```

Once successful should show the result as below
![Docker containers](images/Docker-instances.png)

## Connect the deployed network to Remix

Network Url : http://<aws-ec2-ip>:8545
ChainId: 1337
