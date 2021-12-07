# hadoop\Hive\Spark\Flink客户端
本项目用于安装hadoop\Hive\Spark\Flink基础环境并作为客户端连接指定的集群

本分支适配于docker环境的hadoop-hive服务端，其中hive元数据使用mysql

java 1.8.0_261
scala 2.11.8
hadoop 2.7.4
hive 2.3.9
spark 2.4.4
flink 1.10.1
flinkx 1.10.4

其中flinkx下载地址为https://download.fastgit.org/DTStack/flinkx/releases/download/1.10.4/flinkx.7z

## 安装JDK8，具体操作如下
```
wget -c --no-check-certificate https://pan.software.dc/f/da0ea4be51ff4b5d8715/?dl=1 -O jdk-8u261-linux-x64.tar.gz

tar -xvf jdk-8u261-linux-x64.tar.gz
mkdir -p /usr/java
mv jdk1.8.0_261/ /usr/java/

sudo cat <<'EOF'>> /etc/profile

JAVA_HOME=/usr/java/jdk1.8.0_261
JRE_HOME=/usr/java/jdk1.8.0_261/jre
CLASS_PATH=.:$JAVA_HOME/lib/dt.jar:$JAVA_HOME/lib/tools.jar:$JRE_HOME/lib
PATH=$PATH:$JAVA_HOME/bin:$JRE_HOME/bin
export JAVA_HOME JRE_HOME CLASS_PATH PATH
EOF
source /etc/profile
java -version
```

## 安装过程

```
git clone http://gitlab.software.dc/mp-data/dss/hive-client.git
cd hive-client
git checkout master
sh install.sh
source /etc/profile
hadoop version
#如果要连接到其他服务器上的hadoop环境，执行sh install.sh 172.18.8.174
hive -e "show databases"

```

# 以下为详细说明

## 安装hadoop\Hive\Spark\Flink基础环境
```
#参考 install.sh
rm -rf /opt/{flink,hadoop,spark,hive}
mkdir /opt/{flink,hadoop,spark,hive}

cd ./download

tar xvf flink-1.10.1-bin-hadoop27-scala_2.11.tgz -C /opt/flink/ && \
    tar xvf scala-2.11.8.tgz -C /usr/local/ && \
    tar xvf hadoop-2.7.4.tar.gz -C /opt/hadoop/ && \
    tar xvf spark-2.4.4-bin-hadoop2.7.tgz -C /opt/spark/ && \
    tar xvf apache-hive-2.3.9-bin.tar.gz -C /opt/hive/ 

```

## 修复hive命令行spark-assembly-*.jar找不到的bug
spark升级到spark2以后，原有lib目录下的大JAR包被分散成多个小JAR包，原来的spark-assembly-*.jar已经不存在，所以hive没有办法找到这个JAR包。

```
#参考 install.sh

sed -i '116s#lib#jars#' /opt/hive/apache-hive-2.3.9-bin/bin/hive
sed -i '116s#spark-assembly-*#*#' /opt/hive/apache-hive-2.3.9-bin/bin/hive

```


## 配置环境变量

```
cat <<'EOF'>> /etc/profile

export SPARK_HOME=/opt/spark/spark-2.4.4-bin-hadoop2.7
export SPARK_CONF_DIR=$SPARK_HOME/conf
export PYSPARK_ALLOW_INSECURE_GATEWAY=1
export HIVE_HOME=/opt/hive/apache-hive-2.3.9-bin
export FLINK_HOME=/opt/flink/flink-1.10.1
export HIVE_CONF_DIR=$HIVE_HOME/conf
export SCALA_HOME=/usr/local/scala-2.11.8
export HADOOP_HOME=/opt/hadoop/hadoop-2.7.4
export HADOOP_CONF_PATH=$HADOOP_HOME/etc/hadoop
export HADOOP_CONF_DIR=$HADOOP_HOME/etc/hadoop
export HADOOP_CLASSPATH=`${HADOOP_HOME}/bin/hadoop classpath`
export CLASSPATH=$JAVA_HOME/lib/dt.jar:$JAVA_HOME/lib/tools.jar
export PATH=${JAVA_HOME}/bin/:${SPARK_HOME}/bin:${HIVE_HOME}/bin:${SCALA_HOME}/bin:${FLINK_HOME}/bin:${HADOOP_HOME}/sbin:${HADOOP_HOME}/bin:$PATH

EOF

source /etc/profile
```


## 配置/etc/hosts
将容器化的hadoop节点及hive元数据及数据库服务的节点配置到hosts文件中

#如果访问容器内的Hadoop及hive环境，需要配置hosts文件

#默认执行instal.sh选择安装在本地主机的容器化Hadoop环境

#如果要连接到其他服务器上的hadoop环境，需要进一步完善此脚本
```
local_ipaddr=$(ip addr | awk '/^[0-9]+: / {}; /inet.*global/ {print gensub(/(.*)\/(.*)/, "\\1", "g", $2)}' | awk 'NR==1')

cat <<'EOF'>> /etc/hosts
$local_ipaddr  namenode
$local_ipaddr  datanode
$local_ipaddr   resourcemanager
$local_ipaddr   nodemanager
$local_ipaddr   historyserver
$local_ipaddr   hive-server
$local_ipaddr   hive-metastore
$local_ipaddr   hive-metastore-postgresql
$local_ipaddr   hive-metastore-mysql
EOF
```

## 修改hadoop及hive配置文件

```
#hadoop涉及如下配置文件
yarn-site.xml
mapred-site.xml
hdfs-site.xml
hadoop-env.sh
core-site.xml

#hive涉及如下配置文件
hive-site.xml

cp -r -f conf/hadoop/hadoop-2.7.4/etc/hadoop/* /opt/hadoop/hadoop-2.7.4/etc/hadoop/

cp -r -f conf/hive/apache-hive-2.3.9-bin/conf/hive-site.xml /opt/hive/apache-hive-2.3.9-bin/conf/


```

## 测试hadoop及hive客户端
```
测试hadoop客户端
hadoop fs -ls  /
hadoop fs -ls  hdfs://namenode:8020/

#查看datanode节点信息
hdfs dfsadmin -report

测试hive客户端
hive
show databases;
select * from default.pokes; 

hive -e 'select * from default.pokes;'

#如有异常可打开hive详细日志
hive --hiveconf hive.root.logger=DEBUG,console -e "select * from default.pokes;"

```

## spark客户端配置

```
cat <<'EOF'>> /opt/spark/spark-2.4.4-bin-hadoop2.7/conf/spark-env.sh
export SPARK_DIST_CLASSPATH=$(/opt/hadoop/hadoop-2.7.4/bin/hadoop classpath)
EOF

cp conf/hadoop/hadoop-2.7.4/etc/hadoop/hdfs-site.xml /opt/spark/spark-2.4.4-bin-hadoop2.7/conf/
cp conf/hadoop/hadoop-2.7.4/etc/hadoop/core-site.xml /opt/spark/spark-2.4.4-bin-hadoop2.7/conf/
cp conf/hive/apache-hive-2.3.9-bin/conf/hive-site.xml /opt/spark/spark-2.4.4-bin-hadoop2.7/conf/

```

## 测试spark客户端

```
#终端下
spark-sql

show databases;
select * from default.pokes;

#命令行执行执行
spark-sql -e "select * from default.pokes;"

#spark on local
spark-submit --master local --class org.apache.spark.examples.SparkPi /opt/spark/spark-2.4.4-bin-hadoop2.7/examples/jars/spark-examples_2.11-2.4.4.jar 1000
#spark on yarn
spark-submit --master yarn --class org.apache.spark.examples.SparkPi /opt/spark/spark-2.4.4-bin-hadoop2.7/examples/jars/spark-examples_2.11-2.4.4.jar 1000

```

## 测试flink客户端

#复制yarn模式所需jar包到hive安装目录下
```
cp /opt/hadoop/hadoop-2.7.4/share/hadoop/yarn/lib/jersey-core-1.9.jar /opt/flink/flink-1.10.1/lib/
cp /opt/hadoop/hadoop-2.7.4/share/hadoop/yarn/lib/jersey-client-1.9.jar /opt/flink/flink-1.10.1/lib/

#flink on yarn

#Flink yarn-session
yarn-session.sh -n 3 -s 3 -jm 1024 -tm 1024 -d -nm FlinkOnYarnSession -id
flink run -c org.apache.flink.examples.java.wordcount.WordCount /opt/flink/flink-1.10.1/examples/batch/WordCount.jar

yarn application -kill application_1576832892572_000

#Flink Per-Job-Cluster
flink run -m yarn-cluster -yn 2 -yjm 1024 -ytm 1024  /opt/flink/flink-1.10.1/examples/batch/WordCount.jar
```

```
yarn-session.sh 后面支持多个参数。下面针对一些常见的参数进行讲解
-n、–container 表示分配容器的数量（也就是 TaskManager 的数量）。
-D、 动态属性。
-d、–detached 在后台独立运行。
-jm、–jobManagerMemory ：设置 JobManager 的内存，单位是 MB。
-nm、–name：在 YARN 上为一个自定义的应用设置一个名字。
-q、–query：显示 YARN 中可用的资源（内存、cpu 核数）。
-qu、–queue ：指定 YARN 队列。
-s、–slots ：每个 TaskManager 使用的 Slot 数量。
-tm、–taskManagerMemory ：每个 TaskManager 的内存，单位是 MB。
-z、–zookeeperNamespace ：针对 HA 模式在 ZooKeeper 上创建 NameSpace。
-id、–applicationId ：指定 YARN 集群上的任务 ID，附着到一个后台独 立运行的 yarn session 中。
```


## 测试flinkx

```
mkdir -p /opt/flinkx
yum install -y p7zip
cd download
if [ ! -f "flinkx.7z" ]; then
wget -c https://download.fastgit.org/DTStack/flinkx/releases/download/1.10.4/flinkx.7z
fi
rm -rf /opt/flinkx/flinkx-1.10.4/
7za x flinkx.7z -r -o/opt/flinkx/flinkx-1.10.4/ -Y

/opt/flinkx/flinkx-1.10.4/flinkx/bin/flinkx \
-mode yarnPer \
-job /opt/flinkx/flinkx-1.10.4/flinkx/docs/example/stream_stream.json \
-flinkconf $FLINK_HOME/conf \
-yarnconf $HADOOP_HOME/etc/hadoop \
-flinkLibJar $FLINK_HOME/lib \
-confProp "{\"flink.checkpoint.interval\":60000}" \
-queue default



```