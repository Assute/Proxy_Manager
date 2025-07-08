# proxy_switcher
每天自动切换代理

安装目录位于 /opt

# 安装脚本

```shell script
wget -N  /opt https://github.com/Assute/proxy_switcher/blob/main/proxy_switcher.sh ; chmod +x proxy_switcher.sh
```
进入opt目录
```shell script
cd /opt
```
应用代理
```shell script
./proxy_switcher.sh apply
```
设置每日0点自动切换代理
```shell script
./proxy_switcher.sh cron
```
查看当前代理
```shell script
./proxy_switcher.sh show
```
