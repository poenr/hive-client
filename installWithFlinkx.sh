#!/bin/bash

# jdk8安装环境略过

rm -rf /opt/{flink,hadoop,spark,hive,flinkx}
mkdir /opt/{flink,hadoop,spark,hive,flinkx}

cd ./download
# 此处从软开中心技术部内网NAS服务器下载
if [ ! -f "flink-1.12.2-bin-scala_2.11.tgz" ];then
wget -c http://dl.software.dc/dist/flink-1.12.2-bin-scala_2.11.tgz
fi
if [ ! -f "scala-2.11.8.tgz" ];then
wget -c http://dl.software.dc/dist/scala-2.11.8.tgz
fi
if [ ! -f "hadoop-2.7.4.tar.gz" ];then
wget -c http://dl.software.dc/dist/hadoop-2.7.4.tar.gz
fi
if [ ! -f "spark-2.4.4-bin-hadoop2.7.tgz" ];then
wget -c http://dl.software.dc/dist/spark-2.4.4-bin-hadoop2.7.tgz
fi
if [ ! -f "apache-hive-2.3.9-bin.tar.gz" ];then
wget -c http://dl.software.dc/dist/apache-hive-2.3.9-bin.tar.gz
fi
if [ ! -f "flinkx.7z" ];then
wget -c http://dl.software.dc/dist/flinkx.7z
fi

tar xvf flink-1.12.2-bin-scala_2.11.tgz -C /opt/flink/ && \
    tar xvf scala-2.11.8.tgz -C /usr/local/ && \
    tar xvf hadoop-2.7.4.tar.gz -C /opt/hadoop/ && \
    tar xvf spark-2.4.4-bin-hadoop2.7.tgz -C /opt/spark/ && \
    tar xvf apache-hive-2.3.9-bin.tar.gz -C /opt/hive/ 

yum install -y p7zip
7za x flinkx.7z -r -o/opt/flinkx/flinkx-1.10.4/ -Y

cd ../

#修复spark-assembly jar包找不到异常
sed -i '116s#lib#jars#' /opt/hive/apache-hive-2.3.9-bin/bin/hive
sed -i '116s#spark-assembly-*#*#' /opt/hive/apache-hive-2.3.9-bin/bin/hive


#hadoop及hive客户端所需配置文件
cp -r -f conf/hadoop/hadoop-2.7.4/etc/hadoop/* /opt/hadoop/hadoop-2.7.4/etc/hadoop/
cp -r -f conf/hive/apache-hive-2.3.9-bin/conf/hive-site.xml /opt/hive/apache-hive-2.3.9-bin/conf/

#mysql驱动
cp db/mysql-connector-java-5.1.49.jar /opt/hive/apache-hive-2.3.9-bin/lib/
cp db/mysql-connector-java-5.1.49.jar /opt/spark/spark-2.4.4-bin-hadoop2.7/jars/ 

#spark客户端所需配置文件
cat <<'EOF'>> /opt/spark/spark-2.4.4-bin-hadoop2.7/conf/spark-env.sh
export SPARK_DIST_CLASSPATH=$(/opt/hadoop/hadoop-2.7.4/bin/hadoop classpath)
EOF

#获取本机ip
local_ipaddr=$(ip addr | awk '/^[0-9]+: / {}; /inet.*global/ {print gensub(/(.*)\/(.*)/, "\\1", "g", $2)}' | awk 'NR==1')
echo local_ipaddr=$local_ipaddr

cat <<'EOF'>> /opt/spark/spark-2.4.4-bin-hadoop2.7/conf/spark-defaults.conf
spark.master=yarn-client
spark.driver.bindAddress=0.0.0.0
spark.driver.host=local_ipaddr
spark.driver.port=19999
spark.blockManager.port=20000
                                 
EOF

sed -i "s/local_ipaddr/$local_ipaddr/" /opt/spark/spark-2.4.4-bin-hadoop2.7/conf/spark-defaults.conf

cp conf/hadoop/hadoop-2.7.4/etc/hadoop/hdfs-site.xml /opt/spark/spark-2.4.4-bin-hadoop2.7/conf/
cp conf/hadoop/hadoop-2.7.4/etc/hadoop/core-site.xml /opt/spark/spark-2.4.4-bin-hadoop2.7/conf/
cp conf/hive/apache-hive-2.3.9-bin/conf/hive-site.xml /opt/spark/spark-2.4.4-bin-hadoop2.7/conf/

#spark log4j配置
cp /opt/spark/spark-2.4.4-bin-hadoop2.7/conf/log4j.properties.template /opt/spark/spark-2.4.4-bin-hadoop2.7/conf/log4j.properties
sed -i "s/log4j.rootCategory=INFO/log4j.rootCategory=ERROR/" /opt/spark/spark-2.4.4-bin-hadoop2.7/conf/log4j.properties

#flink客户端配置

#复制yarn模式所需jar包到hive安装目录下
cp /opt/hadoop/hadoop-2.7.4/share/hadoop/yarn/lib/jersey-core-1.9.jar /opt/flink/flink-1.12.2/lib/
cp /opt/hadoop/hadoop-2.7.4/share/hadoop/yarn/lib/jersey-client-1.9.jar /opt/flink/flink-1.12.2/lib/

# 新版flink不支持hadoop,需要下载hadoop依赖放入到FLINK_HOME/lib目录才可以连接到hdfs
cp ./lib/flink-shaded-hadoop-2-uber-2.8.3-10.0.jar /opt/flink/flink-1.12.2/lib/

cat <<'EOF'>> /opt/flink/flink-1.12.2/conf/flink-conf.yaml

#YarnSessionClusterEntrypoint bind Port
rest.bind-port: 50031-50040
                           
EOF

#flinkx客户端配置
rm -rf /opt/flinkx/flinkx-1.10.4/flinkx/flinkx-*


#JAVA_HOME环境变量单独配置
grep "SPARK_HOME" /etc/profile >/dev/null
if [ $? -eq 0 ];then
echo '/etc/profile has the config and do nothing'
else
cat <<'EOF'>> /etc/profile

export SPARK_HOME=/opt/spark/spark-2.4.4-bin-hadoop2.7
export SPARK_CONF_DIR=$SPARK_HOME/conf
export PYSPARK_ALLOW_INSECURE_GATEWAY=1
export HIVE_HOME=/opt/hive/apache-hive-2.3.9-bin
export FLINK_HOME=/opt/flink/flink-1.12.2
export HIVE_CONF_DIR=$HIVE_HOME/conf
export SCALA_HOME=/usr/local/scala-2.11.8
export HADOOP_HOME=/opt/hadoop/hadoop-2.7.4
export HADOOP_CONF_PATH=$HADOOP_HOME/etc/hadoop
export HADOOP_CONF_DIR=$HADOOP_HOME/etc/hadoop
export HADOOP_CLASSPATH=`${HADOOP_HOME}/bin/hadoop classpath`
export CLASSPATH=$JAVA_HOME/lib/dt.jar:$JAVA_HOME/lib/tools.jar
export PATH=${JAVA_HOME}/bin/:${SPARK_HOME}/bin:${HIVE_HOME}/bin:${SCALA_HOME}/bin:${FLINK_HOME}/bin:${HADOOP_HOME}/sbin:${HADOOP_HOME}/bin:$PATH

EOF

fi


source /etc/profile

#如果访问容器内的Hadoop及hive环境，需要配置hosts文件

#默认执行instal.sh选择安装在本地主机的容器化Hadoop环境

#如果要连接到其他服务器上的hadoop环境，需要进一步完善此脚本
if [ -n "$1" ] ;then
local_ipaddr=$1
fi

echo local_ipaddr=$local_ipaddr

grep "namenode" /etc/hosts >/dev/null
if [ $? -eq 0 ];then
cat /etc/hosts
else
cat <<'EOF'>> /etc/hosts
local_ipaddr   namenode
local_ipaddr   datanode
local_ipaddr   resourcemanager
local_ipaddr   nodemanager
local_ipaddr   historyserver
local_ipaddr   hive-server
local_ipaddr   hive-metastore
local_ipaddr   hive-metastore-postgresql
local_ipaddr   hive-metastore-mysql
EOF

fi

sed -i "s/local_ipaddr/$local_ipaddr/" /etc/hosts

#处理/appcom/config/软连接
if [ -d "/appcom/config/" ] ; then
rm -rf /appcom/config/hadoop-config
ln -s /opt/hadoop/hadoop-2.7.4/etc/hadoop /appcom/config/hadoop-config
rm -rf /appcom/config/hive-config
ln -s /opt/hive/apache-hive-2.3.9-bin/conf /appcom/config/hive-config
rm -rf /appcom/config/spark-config
ln -s /opt/spark/spark-2.4.4-bin-hadoop2.7/conf /appcom/config/spark-config
rm -rf /appcom/config/flink-config
ln -s /opt/flink/flink-1.12.2/conf /appcom/config/flink-config
fi


#flinkx下增加start.sh
cat <<'EOF'> /opt/flinkx/flinkx-1.10.4/flinkx/start.sh
#!/bin/bash
sh /opt/flinkx/flinkx-1.10.4/flinkx/bin/flinkx -mode yarnPer -job "$1" -flinkconf /opt/flink/flink-1.12.2/conf -jobid "$2"
echo "$1"
exit 0
EOF

chmod a+x  /opt/flinkx/flinkx-1.10.4/flinkx/start.sh

mkdir -p /opt/flinkx/flinkx-1.10.4/flinkx/job

#flinkx配置文件flink-conf.yaml
cat <<'EOF'>  /opt/flinkx/flinkx-1.10.4/flinkx/flinkconf/flink-conf.yaml
rest.bind-port: 8888
rest.address: namenode
#断点续传的环境准备
state.checkpoints.dir: hdfs://namenode:8020/checkpoints/metadata
state.checkpoints.num-retained: 10
EOF

#flink集成Prometheus
cp /opt/flink/flink-1.12.2/opt/flink-metrics-prometheus-1.12.2.jar /opt/flink/flink-1.12.2/lib/

cat <<'EOF'>> /opt/flink/flink-1.12.2/conf/flink-conf.yaml
##### 与 Prometheus 集成配置 #####
metrics.reporter.promgateway.class: org.apache.flink.metrics.prometheus.PrometheusPushGatewayReporter
# 这里写PushGateway的主机名与端口号
metrics.reporter.promgateway.host: pushgateway.software.dc
metrics.reporter.promgateway.port: 9091
# Flink metric在前端展示的标签（前缀）与随机后缀
metrics.reporter.promgateway.jobName: flink-metrics
metrics.reporter.promgateway.randomJobNameSuffix: true
metrics.reporter.promgateway.deleteOnShutdown: false
metrics.reporter.promgateway.interval: 30 SECONDS
                           
EOF

#权限设置
chown -R hadoop:hadoop /opt/flink
chown -R hadoop:hadoop /opt/flinkx

#如果pushgateway.software.dc域名未解析，需要在/etc/hosts文件中配置