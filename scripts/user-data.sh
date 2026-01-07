#!/bin/bash
yum update -y
yum install -y htop amazon-ssm-agent

# Esperar a que el usuario ec2-user exista
while [ ! -d /home/ec2-user ]; do
    sleep 1
done

# Create CPU stress test script
cat > /home/ec2-user/cpu-stress-test.sh << 'EOF'
#!/bin/bash
echo "Starting Starscream DevOpsAgent CPU Stress Test"
echo "Time: $(date)"
echo "Instance ID: $(curl -s http://169.254.169.254/latest/meta-data/instance-id)"
echo "Instance IP: $(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)"
CORES=$(nproc)
echo "CPU Cores: $CORES"
echo "Starting stress test (5 minutes)..."
echo "This will generate >70% CPU usage to trigger CloudWatch alarm"
echo "Starting CPU load processes..."
rm -f /tmp/cpu_test_pids
for i in $(seq 1 $CORES); do
    (yes > /dev/null) &
    PID=$!
    echo $PID >> /tmp/cpu_test_pids
    echo "Started CPU load process $i (PID: $PID)"
done
echo "CPU load processes started for 5 minutes"
echo "Check CloudWatch for alarm trigger in 3-5 minutes"
sleep 300 && kill $(cat /tmp/cpu_test_pids) 2>/dev/null
echo "Stress test completed"
EOF

# Asegurar permisos correctos
chmod +x /home/ec2-user/cpu-stress-test.sh
chown ec2-user:ec2-user /home/ec2-user/cpu-stress-test.sh