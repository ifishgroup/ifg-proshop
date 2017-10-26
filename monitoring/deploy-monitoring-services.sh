#!/usr/bin/env bash

echo "Deploying node-exporter service"
docker service create \
     --name node-exporter \
     --mode global \
     --network monitoring \
     --mount "type=bind,source=/proc,target=/host/proc" \
     --mount "type=bind,source=/sys,target=/host/sys" \
     --mount "type=bind,source=/,target=/rootfs" \
     --mount "type=bind,source=/etc/hostname,target=/etc/host_hostname" \
     -e HOST_HOSTNAME=/etc/host_hostname \
     basi/node-exporter:v0.1.1 \
     -collector.procfs /host/proc \
     -collector.sysfs /host/sys \
     -collector.filesystem.ignored-mount-points "^/(sys|proc|dev|host|etc)($|/)" \
     -collector.textfile.directory /etc/node-exporter/ \
     -collectors.enabled="conntrack,diskstats,entropy,filefd,filesystem,loadavg,mdadm,meminfo,netdev,netstat,stat,textfile,time,vmstat,ipvs"

echo "Deploying cAdvisor service"
docker service create \
    --name cadvisor \
    -p 8080:8080 \
    --mode global \
    --network monitoring \
    --mount "type=bind,source=/,target=/rootfs" \
    --mount "type=bind,source=/var/run,target=/var/run" \
    --mount "type=bind,source=/sys,target=/sys" \
    --mount "type=bind,source=/var/lib/docker,target=/var/lib/docker" \
    google/cadvisor:v0.24.1


echo "Deploying Prometheus service"
docker service create \
    --name prometheus \
    --constraint "node.hostname == $1" \
    --network monitoring \
    -p 9090:9090 \
    --mount "type=bind,source=/tmp/monitoring/conf/prometheus.yml,target=/etc/prometheus/prometheus.yml" \
    --mount "type=bind,source=/tmp/monitoring/data/prometheus,target=/prometheus" \
    prom/prometheus:v1.2.1


echo "Deploying Grafana service"
docker service create \
    --name grafana \
    --network monitoring \
    -p 3000:3000 \
    grafana/grafana:3.1.1

echo "Deploying ElasticSearch service"
docker service create \
    --name elasticsearch \
    --network monitoring \
    --reserve-memory 300m \
    -p 9200:9200 \
    elasticsearch:2.4

echo "Deploying Logstash service"
docker service create \
    --name logstash \
    --mount "type=bind,source=$PWD/conf,target=/conf" \
    --network monitoring \
    -e LOGSPOUT=ignore \
    logstash:2.4 \
    logstash -f /conf/logstash.conf

echo "Deploying Logspout service"
docker service create \
    --name logspout \
    --network monitoring \
    --mode global \
    --mount "type=bind,source=/var/run/docker.sock,target=/var/run/docker.sock" \
    -e SYSLOG_FORMAT=rfc3164 \
    gliderlabs/logspout \
    syslog://logstash:51415
