#!/bin/bash
#
# bootstrap script: настроивает raid1 для двух девайсов, создает и монтирует volume, создает script.service и добавляет его в автозагрузку запускает script.service, настраивает reverse proxy
#
set -euo pipefail

apt update && apt install -y mdadm lvm2 docker.io nginx openssl
usermod -aG docker $USER && newgrp docker


echo $GH_TOKEN | docker login ghcr.io -u fawkesguyd --password-stdin
docker build -t ghcr.io/fawkesguyd/script:latest .
docker push ghcr.io/fawkesguyd/script:latest


mkdir -p /mnt/raid-lab && cd /mnt/raid-lab
dd if=/dev/zero of=disk1.img bs=1M count=512
dd if=/dev/zero of=disk2.img bs=1M count=512
dd if=/dev/zero of=disk3.img bs=1M count=512
loop1=$(losetup -fP --show disk1.img)
loop2=$(losetup -fP --show disk2.img)
loop3=$(losetup -fP --show disk3.img)


yes | mdadm --create /dev/md0 --level=1 --raid-devices=2 "${loop1}" "${loop2}"
mkfs.ext4 /dev/md0
mkdir -p /mnt/raid && mount /dev/md0 /mnt/raid


yes | pvcreate "${loop3}"
yes | vgcreate vg_data "${loop3}"
yes | lvcreate -L 200M -n lv_logs vg_data
mkfs.ext4 /dev/vg_data/lv_logs
mkdir -p /mnt/logs && mount /dev/vg_data/lv_logs /mnt/logs


openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /etc/ssl/private/script.key \
  -out /etc/ssl/certs/script.crt \
  -subj "/CN=script.local"
cat <<'EOF' > "/etc/nginx/sites-available/script"
server {
    listen 80;
    server_name _;
    return 301 https://$host$request_uri;
}
 
server {
    listen 443 ssl;
    server_name _;
 
    ssl_certificate     /etc/ssl/certs/script.crt;
    ssl_certificate_key /etc/ssl/private/script.key;
 
    location / {
        proxy_pass http://127.0.0.1:8080;
    }
}
EOF
ln -sfn /etc/nginx/sites-available/script /etc/nginx/sites-enabled/
# Отключает файл по уполчанию, для использования кастомного
rm -f /etc/nginx/sites-enabled/default
nginx -t
nginx -s reload


cat <<'EOF' > "/etc/systemd/system/script.service"
[Unit]
Description=script service
After=docker.service
Requires=docker.service
 
[Service]
Restart=on-failure
ExecStart=docker run --rm --name script \
    -p 8080:8080 \
    -v /var/www:/var/www \
    ghcr.io/fawkesguyd/script:latest \
    -u root -s
ExecStop=docker stop -t 10 script
 
[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable --now script.service 