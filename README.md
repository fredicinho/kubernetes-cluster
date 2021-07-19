# Kubernetes Cluster
This is a small Guide which shows how to create a Kubernetes Cluster.

## Install Kubernetes on Hetzner Cloud with Terraform and KubeOne
Install Kubeone
````
curl -sfL get.kubeone.io | sh
````
Install Terraform
```
brew install terraform
```
Export HCloud Token
```
export HCLOUD_TOKEN="MY_TOKEN"
```
Initialize Terraform project
```
cd hetzner/cluster && terraform init
```
Apply Terraform project
```
terraform apply -auto-approve
```
Create kubeone.yaml-File to create Cluster with KubeOne
````yaml
apiVersion: kubeone.io/v1beta1
kind: KubeOneCluster

versions:
  kubernetes: '1.19.3'

cloudProvider:
  hetzner: {}
  external: true
````
Export output of terraform to json
```
terraform output -json > output.json
```
Apply KubeOne-Configs to Terraform-Configuration and install the Cluster
```
kubeone apply --manifest kubeone.yaml --tfjson output.json
```
Move the created kubeconfig-File into your local .kube-Folder!


Tip: Create folder ".kube/configs" and put all config-files there. Export the following KUBECONFIG to handle all Kubernetes-Clusters at once:
````
KUBECONFIG="$(find ~/.kube/configs/ -type f -exec printf '%s:' '{}' +)"
````

## Install Kubernetes on a VM / Bare Metal manually (using Ubuntu)
### Server on Hetzner
I prepared a terraform-Template to create an Ubuntu Server on Hetzner, but you can also use an own Server.
````shell
cd hetzner/server && terraform init && terraform plan && terraform apply -auto-approve
````
### Install Docker
````shell
mkdir /etc/docker
````
```shell
cat > /etc/docker/daemon.json <<EOF
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  },
  "storage-driver": "overlay2"
}
EOF
```
```shell
apt-get update
```
````shell
apt-get install -y apt-transport-https ca-certificates curl gnupg2
````

````shell
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
````

````shell
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
````

````shell
sudo apt update && sudo apt install docker-ce -y
````

### Install Kubernetes components
```shell
sudo apt-get update && sudo apt-get install -y apt-transport-https && curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
```
```shell
echo "deb http://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee -a /etc/apt/sources.list.d/kubernetes.list && sudo apt-get update
```
```shell
sudo apt install -y kubeadm  kubelet kubernetes-cni
```

### Turn off Swap
```shell
sudo swapoff -a
```
```shell
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
```
* Check following Issue to understand why: https://github.com/kubernetes/kubernetes/issues/53533

### Create Kubernetes Cluster
```shell
sudo kubeadm init --pod-network-cidr=10.17.0.0/16 --service-cidr=10.18.0.0/24 --ignore-preflight-errors=NumCPU
```
* https://kubernetes.io/docs/reference/setup-tools/kubeadm/kubeadm-init/

Follow the instructions to configure the conf-File:
```shell
mkdir $HOME/.k8s
```
```shell
sudo cp /etc/kubernetes/admin.conf $HOME/.k8s/
```

```shell
sudo chown $(id -u):$(id -g) $HOME/.k8s/admin.conf
```

```shell
export KUBECONFIG=$HOME/.k8s/admin.conf
```

```shell
echo "export KUBECONFIG=$HOME/.k8s/admin.conf" | tee -a ~/.bashrc
```

Save the kubeconf-File locally:
````shell
scp root@YOUR_SERVER_IP:~/.k8s/admin.conf ~/.kube/configs
````
* I'm using following Export (in .zshrc or .bashrc) to merge all my kubeconfig-Files in the .kube/configs Folder:
````shell
export KUBECONFIG="$(find ~/.kube/configs/ -type f -exec printf '%s:' '{}' +)"
````

Check if your configfile is available:
````shell
kubectl config view
````
Change the context
````shell
kubectl config 
````

### Apply Networking
```shell
kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml
```
```shell
kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/k8s-manifests/kube-flannel-rbac.yml
```
* Check documentation for networking in Kubernetes: https://kubernetes.io/docs/concepts/cluster-administration/networking/
* I use flannel here: https://github.com/flannel-io/flannel

### Make Master Node as Worker (Optional)
````shell
kubectl taint nodes --all node-role.kubernetes.io/master-
````
* Just make this, if you want to use Kubernetes on a single server. Else you have to add worker nodes to run Pods!

### Add Worker Node to Cluster (Optional)
Get Token of your Master Node
````shell
kubeadm token list
````
If it is empty, create a new one
````shell
kubeadm token create --print-join-command
````
Get Discovery Token CA cert Hash of your Master Node
````shell
openssl x509 -pubkey -in /etc/kubernetes/pki/ca.crt | openssl rsa -pubin -outform der 2>/dev/null | openssl dgst -sha256 -hex | sed 's/^.* //'
````
Get your API Server Endpoint:
````shell
kubectl cluster-info
````
Connect to your new worker node, install Docker, Kubernetes Components and turn off Swap.
Use Kubeadm join command to join your worker to the cluster
````shell
kubeadm join IP_OF_API:PORT_OF_API --token YOUR_TOKEN --discovery-token-ca-cert-hash YOUR_CERT_HASH
````

## NGINX Ingress Controller
Check this blog to understand its Architecture/Purpose:
* https://docs-1-12--nginx-kubernetes-ingress.netlify.app/nginx-ingress-controller/intro/how-nginx-ingress-controller-works/
### Install manually

### Install with Terraform and Helm Chart

## Cert-Manager and Wildcard Certificate
This tutorial explains how you install and configure the CertManager with the usage of a Wildcard-Certificate. I use Cloudflare as my DNS-Registrar. Therefore, I work with its API-Token. I assume that you already have a Domainname registered over Cloudflare.
To get more information about the Cert-Manager: 
* https://banzaicloud.com/blog/cert-management-on-kubernetes/


### Install manually
Apply following yaml-File. It includes all resources (CustomResourceDefinitions, cert-manager, namespace and webhook component).
````shell
kubectl apply -f https://github.com/jetstack/cert-manager/releases/download/v1.4.0/cert-manager.yaml
````
Check your installation (cert-manager, cainjector and webhook should be available)
````shell
kubectl get pods --namespace cert-manager
````
Create a Secret with your CloudFlare-API key.
````shell
kubectl apply -f cert-manager/manifests/cloudflare-api-key.yaml
````
Create a ClusterIssuer
````shell
kubectl apply -f cert-manager/manifests/ClusterIssuer.yaml
````
* Check dock for its purpose: https://cert-manager.io/docs/concepts/issuer/

Now you can create a wildcard-certificate
```shell
kubectl apply -f kubernetes-cluster/cert-manager/manifests/wildcard-certificate.yaml
```

Check if your certificate was issued successfully
````shell
kubectl describe certificate -n cert-manager
````

This certificate is now just available in the namespace "cert-manager". We have to share it through all namespaces so that other applications can use it. We are going to use "Kubernetes Replicator".
Create roles and service Accounts
````shell
kubectl apply -f https://raw.githubusercontent.com/mittwald/kubernetes-replicator/master/deploy/rbac.yaml
````
Create deployment
````shell
kubectl apply -f https://raw.githubusercontent.com/mittwald/kubernetes-replicator/master/deploy/deployment.yaml
````

Now you have to extend your wildcard-certificate with following annotation:
````yaml
metadata:
  annotations:
    replicator.v1.mittwald.de/replicate-to: "gitlab, keycloak"
````
The Replicator replicates this certificate now to the mentioned namespaces "gitlab" and "keycloak", which we will create and work with later!

### Install with Terraform and Helm Chart

## Keycloak

## GitLab

## OAuth2 Proxy

