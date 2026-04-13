#!/bin/bash
exec > /var/log/k3s-userdata.log 2>&1
set -ex

export HOME=/root
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

# --- Wait for network readiness ---
echo "Waiting for network..."
until curl -sf --connect-timeout 3 https://get.k3s.io > /dev/null 2>&1; do
  echo "Network not ready, retrying..."
  sleep 3
done
echo "Network is ready"

# --- Public IP (from Terraform EIP) and Account ID ---
PUBLIC_IP=${public_ip}
TOKEN=$(curl -sX PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
ACCOUNT_ID=$(curl -sH "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/dynamic/instance-identity/document | grep accountId | awk -F'"' '{print $4}')

echo "PUBLIC_IP=$${PUBLIC_IP}, ACCOUNT_ID=$${ACCOUNT_ID}"

# --- ECR credential provider for K3s ---
mkdir -p /var/lib/rancher/k3s/agent/etc/containerd
mkdir -p /etc/rancher/k3s

cat > /etc/rancher/k3s/registries.yaml <<YAML
mirrors:
  "$${ACCOUNT_ID}.dkr.ecr.${region}.amazonaws.com":
    endpoint:
      - "https://$${ACCOUNT_ID}.dkr.ecr.${region}.amazonaws.com"
YAML

# --- Install K3s (two-step to avoid pipe issues) ---
curl -sfL --connect-timeout 10 --retry 5 --retry-delay 5 https://get.k3s.io -o /tmp/k3s-install.sh
chmod +x /tmp/k3s-install.sh
INSTALL_K3S_EXEC="server --tls-san ${public_ip} --write-kubeconfig-mode 644" \
  K3S_TOKEN="${k3s_token}" \
  /tmp/k3s-install.sh

# Wait for K3s to be ready
until /usr/local/bin/kubectl get nodes; do sleep 5; done
echo "K3s is ready"

# --- Store kubeconfig in SSM ---
KUBECONFIG_CONTENT=$(cat /etc/rancher/k3s/k3s.yaml | sed "s/127.0.0.1/${public_ip}/g")
aws ssm put-parameter \
  --name "/${project}/k3s/kubeconfig" \
  --value "$${KUBECONFIG_CONTENT}" \
  --type SecureString \
  --overwrite \
  --region ${region}
echo "kubeconfig stored in SSM"

# --- Install cert-manager ---
/usr/local/bin/kubectl apply -f https://github.com/cert-manager/cert-manager/releases/latest/download/cert-manager.yaml
/usr/local/bin/kubectl wait --for=condition=Available deployment/cert-manager -n cert-manager --timeout=120s
/usr/local/bin/kubectl wait --for=condition=Available deployment/cert-manager-webhook -n cert-manager --timeout=120s
echo "cert-manager ready"

# --- Install ArgoCD (server-side apply for large CRDs) ---
/usr/local/bin/kubectl create namespace argocd
/usr/local/bin/kubectl apply -n argocd --server-side -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
/usr/local/bin/kubectl wait --for=condition=Available deployment/argocd-server -n argocd --timeout=300s
echo "ArgoCD ready"

# --- Set ArgoCD to insecure mode (TLS handled by Traefik) ---
/usr/local/bin/kubectl -n argocd patch configmap argocd-cmd-params-cm \
  --type merge \
  -p '{"data":{"server.insecure":"true"}}'
/usr/local/bin/kubectl -n argocd rollout restart deployment argocd-server
echo "ArgoCD insecure mode set"

# --- Setup ECR image pull cron ---
cat > /usr/local/bin/ecr-login.sh <<'SCRIPT'
#!/bin/bash
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
TOKEN=$(curl -sX PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
ACCOUNT_ID=$(curl -sH "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/dynamic/instance-identity/document | grep accountId | awk -F'"' '{print $4}')
REGION=$(curl -sH "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/dynamic/instance-identity/document | grep region | awk -F'"' '{print $4}')
PASSWORD=$(aws ecr get-login-password --region $REGION)
/usr/local/bin/kubectl delete secret ecr-cred -n chat --ignore-not-found
/usr/local/bin/kubectl create secret docker-registry ecr-cred \
  -n chat \
  --docker-server="$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com" \
  --docker-username=AWS \
  --docker-password="$PASSWORD"
SCRIPT
chmod +x /usr/local/bin/ecr-login.sh

# Create chat namespace and initial ECR secret
/usr/local/bin/kubectl create namespace chat --dry-run=client -o yaml | /usr/local/bin/kubectl apply -f -
/usr/local/bin/ecr-login.sh

# Setup cron for ECR token refresh (every 6 hours)
echo "0 */6 * * * root /usr/local/bin/ecr-login.sh >> /var/log/ecr-login.log 2>&1" | tee /etc/crontab -a
echo "Setup complete!"
