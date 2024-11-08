# 💬 Live Chat

Welcome to the Live Chat! This app allows users to chat privately, one-on-one, in real time. Built with privacy and scalability in mind, the app ensures end-to-end encryption, highly available infrastructure, and an effortless deployment process. This project leverages modern cloud technologies like Kubernetes, Terraform, and AWS to create a secure and scalable chat platform.

Please keep in mind that this project is intended as a personal project, primarily for learning and experimentation. While it includes robust features like encryption, autoscaling, and high availability, not all aspects are designed to be production-ready.

## ⚙️ Features

- **1-on-1 Private Chat**: Engage in private conversations with other users.
- **Real-Time Communication**: Uses WebSocket connections to enable live, real-time chat.
- **Secure by Default**: All communication is over HTTPS, ensuring privacy.
- **Strong Encryption**: All messages are encrypted with AES symmetric encryption, and the AES keys themselves are secured with RSA encryption.
- **High Availability**: The app runs on an AWS EKS cluster spread across multiple availability zones, ensuring continuous operation even if some components fail or availability zones go down.
- **Scalable Architecture**: Designed to handle increasing loads with ease.
  - **Modular Architecture**: The backend (handling WebSocket traffic and user state) is separate from the UI module (serving web pages), enabling granular scalability.
  - **Autoscaling**: Both cluster and horizontal pod autoscaling are implemented to accommodate virtually unlimited users, scaling up and down dynamically depending on demand.
- **Redis User State Management**: User state is managed by a Redis Cluster with Sharding and Replication, supporting high traffic, and providing high availability and failover capabilities.
- **RabbitMQ Message Brokering**: Message routing across backend pods is powered by a RabbitMQ Cluster with Mirrored Queues, ensuring resilient, reliable communication and maintaining high availability through robust failover mechanisms.

## 🛠️ Built With

- **Backend**: Python, Flask, Flask-SocketIO
- **Frontend**: JavaScript, HTML, CSS
- **Infrastructure**: AWS Elastic Kubernetes Service (EKS), Helm for Kubernetes deployment, Terraform for resource provisioning
- **In-memory Database for User State Management**: Redis Cluster
- **Message Broker**: RabbitMQ Cluster

## 📝 Requirements

Before you can deploy the application, make sure you have the following available on your local machine:

- **Operating System**: MacOS or Linux
- **AWS Account**: An active AWS account to create and manage resources.
- **AWS Credentials**: Set up as environment variables (`AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY`).
- **Tools**
  - **AWS CLI**
  - **Terraform** (>= 1.3.2.)
  - **Docker**
  - **Helm**
  - **Kubectl** (the kubectl version should be within one minor version of the Kubernetes version used by EKS, i.e., either one version higher or lower. By default, the app is configured to use Kubernetes 1.31.)
  - **OpenSSL**

## 🚀 Getting Started

To deploy the chat application, follow these steps:

1. **Review Configuration**: 
   - Open `config.yaml` to customize settings as needed.
   
2. **Set Secrets**:
   - Make sure to export the necessary secrets for the application (you can set any values you like!):
     ```bash
     export FLASK_SECRET_KEY=<your-secret-key>
     export REDIS_PASSWORD=<your-password>
     export RABBIT_ERLANG_COOKIE=<your-erlang-cookie>
     export RABBIT_USERNAME=<your-username>
     export RABBIT_PASSWORD=<your-password>
     ```

3. **Build Resources**:
   - Run the `build.sh` script. This will:
     - Generate a self-signed SSL certificate and store it in the `./cert` directory.
     - Provision AWS resources using Terraform.
     - Build and push Docker images to AWS Elastic Container Registry (ECR).
     - Deploy the app on Kubernetes using Helm.
     - Configure `kubectl` to interact with your newly created EKS cluster from your machine.

4. **Access the App**:
   - After running `build.sh`, you'll be given a DNS address from the Application Load Balancer. You and other users can access the app by visiting that URL.
   - Log in by entering a username, then click on another user's name in the lobby to start a private chat.

5. **Destroy Resources**:
   - To clean up after you're done, run `destroy.sh`. This will remove all the AWS resources created during the setup process, including Terraform-managed infrastructure and Kubernetes deployments.

## 🔒 SSL Certificate Note

This project uses a self-signed SSL certificate, which is generated during the build process with `build.sh`. While this works for testing and development, note that browsers will warn users when accessing the app since the certificate is not from a recognized Certificate Authority (CA). For production, you should use a CA-signed certificate, which can be configured with AWS and Terraform. (This would require purchasing a domain for a year at minumum, and thus isn't suitable here considering the scope and nature of this project).

## 🔧 Development Notes

- The `build.sh` script is designed to be idempotent. You can run it multiple times without causing issues, which makes updating the app or reconfiguring resources a smooth experience. If you need to make changes to the app, simply update the code and run `build.sh` again.
- You can access the cluster using kubectl commands from the IP address used during resource provisioning. However, to prevent inconsistencies in the Terraform state, it's recommended to avoid manual modifications to the cluster.
- For testing purposes, the self-signed SSL certificate should be sufficient. However, in a production environment, consider using a trusted Certificate Authority for the SSL certificate to avoid browser warnings.

## 📜 License

This project is licensed under the [MIT License](https://opensource.org/licenses/MIT). You are free to use, modify, and distribute the software as long as you include the original copyright and license notice. For more details, please refer to the full text of the license.
