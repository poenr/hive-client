#!/bin/bash

# jdk8安装环境略过

rm -rf /opt/{hadoop,spark,hive}
mkdir /opt/{hadoop,spark,hive}

cd ./download
# 此处从软开中心技术部内网NAS服务器下载

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

tar xvf scala-2.11.8.tgz -C /usr/local/ && \
    tar xvf hadoop-2.7.4.tar.gz -C /opt/hadoop/ && \
    tar xvf spark-2.4.4-bin-hadoop2.7.tgz -C /opt/spark/ && \
    tar xvf apache-hive-2.3.9-bin.tar.gz -C /opt/hive/ 

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

#复制yarn模式所需jar包到spark安装目录下
cp /opt/hadoop/hadoop-2.7.4/share/hadoop/yarn/lib/jersey-core-1.9.jar /opt/spark/spark-2.4.4-bin-hadoop2.7/jars/ 
cp /opt/hadoop/hadoop-2.7.4/share/hadoop/yarn/lib/jersey-client-1.9.jar /opt/spark/spark-2.4.4-bin-hadoop2.7/jars/ 

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
export HIVE_CONF_DIR=$HIVE_HOME/conf
export SCALA_HOME=/usr/local/scala-2.11.8
export HADOOP_HOME=/opt/hadoop/hadoop-2.7.4
export HADOOP_CONF_PATH=$HADOOP_HOME/etc/hadoop
export HADOOP_CONF_DIR=$HADOOP_HOME/etc/hadoop
export HADOOP_CLASSPATH=`${HADOOP_HOME}/bin/hadoop classpath`
export CLASSPATH=$JAVA_HOME/lib/dt.jar:$JAVA_HOME/lib/tools.jar
export PATH=${JAVA_HOME}/bin/:${SPARK_HOME}/bin:${HIVE_HOME}/bin:${SCALA_HOME}/bin:${HADOOP_HOME}/sbin:${HADOOP_HOME}/bin:$PATH

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
fi
