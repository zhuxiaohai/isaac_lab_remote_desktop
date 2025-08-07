# Remote Isaac Lab Docker 配置指南

本项目提供了在 Docker 容器中运行 Isaac Lab 的远程访问配置。

## 前置要求

- Docker 和 Docker Compose
- Ubuntu 系统
- 管理员权限

## SSL 证书配置

### 创建证书目录
```bash
sudo mkdir -p /opt/selkies-certs
cd /opt/selkies-certs
```

### 生成私钥和证书
> **注意**: 请将 `YOUR_SERVER_IP` 替换为您的实际服务器IP地址

```bash
sudo openssl req -x509 -newkey rsa:2048 -keyout selkies-key.pem -out selkies-cert.pem -days 365 -nodes -subj "/C=CN/ST=State/L=City/O=Organization/CN=YOUR_SERVER_IP"
```

### 设置证书权限
```bash
sudo chmod 644 /opt/selkies-certs/selkies-cert.pem
sudo chmod 600 /opt/selkies-certs/selkies-key.pem
```

## 网络端口配置

确保以下端口在防火墙中已开放：

- **8080/tcp** - Web界面访问端口
- **3478/udp** - TURN服务器 (UDP)
- **3478/tcp** - TURN服务器 (TCP)  
- **49152-49200/udp** - WebRTC数据传输端口范围 (UDP)
- **49152-49200/tcp** - WebRTC数据传输端口范围 (TCP)

### Ubuntu 防火墙配置示例
```bash
sudo ufw allow 8080/tcp
sudo ufw allow 3478/udp
sudo ufw allow 3478/tcp
sudo ufw allow 49152:49200/udp
sudo ufw allow 49152:49200/tcp
```

## 使用说明

1. 完成上述证书和网络配置
2. 启动 Docker 容器
3. 通过浏览器访问 `https://YOUR_SERVER_IP:8080`

## 故障排除

- 如果无法访问 Web 界面，请检查防火墙配置
- 确保证书文件权限正确设置
- 验证服务器 IP 地址是否正确配置