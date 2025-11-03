# Deploy PhoneGPT Webhook to Synology NAS

Complete guide to deploy the webhook server to your Synology NAS at `https://phonegpt-webhook.systemd.diskstation.me`

## Prerequisites

- Synology NAS with DSM 7.0 or later
- Docker package installed
- SSH access enabled
- Domain/DDNS configured (systemd.diskstation.me)
- Port 443 available for HTTPS

## Step 1: Enable Docker

1. Open **Package Center**
2. Search for **Docker**
3. Click **Install**
4. Wait for installation to complete

## Step 2: Upload Files to NAS

### Option A: Via File Station (GUI)

1. Open **File Station**
2. Navigate to **docker** folder (create if doesn't exist)
3. Create new folder: **phonegpt-webhook**
4. Upload these files:
   - `main.py`
   - `requirements.txt`
   - `Dockerfile`
   - `.env.example` (optional)

### Option B: Via SSH (Command Line)

```bash
# Connect to NAS
ssh your_username@systemd.diskstation.me

# Create directory
sudo mkdir -p /volume1/docker/phonegpt-webhook
cd /volume1/docker/phonegpt-webhook

# Upload files (from your local machine)
scp main.py requirements.txt Dockerfile your_username@systemd.diskstation.me:/volume1/docker/phonegpt-webhook/
```

## Step 3: Build Docker Image

### Via SSH:

```bash
# SSH into NAS
ssh your_username@systemd.diskstation.me

# Navigate to folder
cd /volume1/docker/phonegpt-webhook

# Build image
sudo docker build -t phonegpt-webhook .

# Verify image created
sudo docker images | grep phonegpt
```

### Via Docker GUI:

1. Open **Docker** app
2. Go to **Image** tab
3. Click **Add** → **Add from File**
4. Navigate to `/docker/phonegpt-webhook/Dockerfile`
5. Click **Build**
6. Name: `phonegpt-webhook`

## Step 4: Run Container

### Via SSH:

```bash
sudo docker run -d \
  --name phonegpt-webhook \
  -p 8000:8000 \
  --restart unless-stopped \
  phonegpt-webhook

# Verify running
sudo docker ps | grep phonegpt

# Check logs
sudo docker logs phonegpt-webhook
```

### Via Docker GUI:

1. Go to **Container** tab
2. Click **Create**
3. Select **phonegpt-webhook** image
4. Configure:
   - Container Name: `phonegpt-webhook`
   - Port Settings:
     - Local Port: 8000
     - Container Port: 8000
     - Type: TCP
   - Auto-restart: Enable
5. Click **Apply** → **Next** → **Done**

## Step 5: Configure Reverse Proxy

1. Open **Control Panel** → **Login Portal** → **Advanced** tab
2. Click **Reverse Proxy**
3. Click **Create**

Configure as follows:

**General:**
- Description: `PhoneGPT Webhook`

**Source:**
- Protocol: `HTTPS`
- Hostname: `phonegpt-webhook.systemd.diskstation.me`
- Port: `443`
- Enable HSTS: ✅
- Enable HTTP/2: ✅

**Destination:**
- Protocol: `HTTP`
- Hostname: `localhost`
- Port: `8000`

**Custom Header (Click on Custom Header tab):**
Add these headers:
```
WebSocket: true
```

4. Click **Save**

## Step 6: Configure SSL Certificate

### Option A: Let's Encrypt (Recommended)

1. **Control Panel** → **Security** → **Certificate**
2. Click **Add**
3. Select **Add a new certificate**
4. Choose **Get a certificate from Let's Encrypt**
5. Fill in:
   - Domain name: `phonegpt-webhook.systemd.diskstation.me`
   - Email: your_email@example.com
   - Subject Alternative Name: (leave empty)
6. Click **Apply**

### Option B: Use Existing Wildcard Certificate

1. **Control Panel** → **Security** → **Certificate**
2. Click **Configure**
3. Find `phonegpt-webhook.systemd.diskstation.me`
4. Select your wildcard certificate
5. Click **OK**

## Step 7: Configure Firewall (if enabled)

1. **Control Panel** → **Security** → **Firewall**
2. Edit your firewall profile
3. Create rule:
   - Ports: `All` or `443`
   - Source IP: `All`
   - Action: `Allow`

## Step 8: Configure DDNS Subdomain

### If using Synology DDNS:

1. **Control Panel** → **External Access** → **DDNS**
2. Click **Add**
3. Configure:
   - Service provider: `Synology`
   - Hostname: `phonegpt-webhook.systemd.diskstation.me`
   - Username/Password: (your Synology account)
   - External address: (auto-detected)

### If using custom domain:

Add DNS A record:
```
phonegpt-webhook.systemd.diskstation.me → [Your NAS Public IP]
```

## Step 9: Test Deployment

### Test from local network:

```bash
# Health check
curl http://localhost:8000/health

# Should return:
# {"status":"healthy","events_count":0,...}
```

### Test from internet:

```bash
# Health check
curl https://phonegpt-webhook.systemd.diskstation.me/health

# Test webhook
curl -X POST https://phonegpt-webhook.systemd.diskstation.me/webhook \
  -H "Content-Type: application/json" \
  -d '{
    "type": "voice_input",
    "data": {"transcript": "Test message"},
    "device_id": "test_device"
  }'

# Check events
curl https://phonegpt-webhook.systemd.diskstation.me/events?since=0
```

## Step 10: Update PhoneGPT iOS App

The iOS app is already configured to use:
```swift
private let webhookURL = "https://phonegpt-webhook.systemd.diskstation.me"
```

No changes needed!

## Troubleshooting

### Container won't start

```bash
# Check logs
sudo docker logs phonegpt-webhook

# Common issues:
# - Port 8000 already in use
# - Python dependencies failed to install

# Restart container
sudo docker restart phonegpt-webhook
```

### Cannot access via HTTPS

1. Check reverse proxy configuration
2. Verify SSL certificate is valid
3. Check firewall rules
4. Verify DDNS is resolving correctly:
   ```bash
   nslookup phonegpt-webhook.systemd.diskstation.me
   ```

### SSL Certificate Error

```bash
# Test SSL
openssl s_client -connect phonegpt-webhook.systemd.diskstation.me:443

# If invalid, regenerate certificate in Control Panel
```

### Events not appearing

1. Check webhook is receiving POST requests:
   ```bash
   sudo docker logs phonegpt-webhook | grep webhook
   ```

2. Test posting to webhook manually:
   ```bash
   curl -X POST http://localhost:8000/webhook \
     -H "Content-Type: application/json" \
     -d '{"type":"test","data":{}}'
   ```

3. Check stats:
   ```bash
   curl https://phonegpt-webhook.systemd.diskstation.me/stats
   ```

## Maintenance

### View Logs

```bash
# Real-time logs
sudo docker logs -f phonegpt-webhook

# Last 100 lines
sudo docker logs --tail 100 phonegpt-webhook
```

### Restart Service

```bash
sudo docker restart phonegpt-webhook
```

### Update Code

```bash
cd /volume1/docker/phonegpt-webhook

# Stop container
sudo docker stop phonegpt-webhook
sudo docker rm phonegpt-webhook

# Rebuild image
sudo docker build -t phonegpt-webhook .

# Start new container
sudo docker run -d \
  --name phonegpt-webhook \
  -p 8000:8000 \
  --restart unless-stopped \
  phonegpt-webhook
```

### Backup

```bash
# Backup Docker image
sudo docker save phonegpt-webhook > phonegpt-webhook-backup.tar

# Restore
sudo docker load < phonegpt-webhook-backup.tar
```

## Performance Optimization

### Add Redis for Better Event Queue

1. Install Redis container:
```bash
sudo docker run -d \
  --name redis \
  -p 6379:6379 \
  --restart unless-stopped \
  redis:alpine
```

2. Update main.py to use Redis (optional enhancement)

### Monitor Resource Usage

```bash
# Container stats
sudo docker stats phonegpt-webhook

# Should show:
# - CPU: < 5%
# - Memory: < 100MB
```

## Security Checklist

- ✅ HTTPS enabled with valid certificate
- ✅ Firewall configured
- ✅ Reverse proxy set up
- ✅ Auto-restart enabled
- ✅ No sensitive data in logs
- ⚠️ Consider adding authentication (optional)

## Next Steps

1. ✅ Deploy webhook server
2. ✅ Configure MentraOS to post to webhook
3. ✅ Test with PhoneGPT app
4. Submit MentraOS integration form with webhook URL

## Support

If issues persist:
1. Check Docker logs
2. Verify network connectivity
3. Test endpoints with curl
4. Review Synology system logs: **Control Panel** → **Log Center**
