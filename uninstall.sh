#!/bin/bash
systemctl stop xray
echo "xray 已停止运行"
rm -rf /usr/bin/xray
rm -rf /etc/xray/config.json
systemctl disable xray
rm -rf /etc/systemd/system/xray.service
echo "xray 已卸载"