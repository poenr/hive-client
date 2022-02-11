#!/bin/bash

source /etc/profile

echo JAVA_HOME=$JAVA_HOME
echo SCALA_HOME=$SCALA_HOME
echo HADOOP_HOME=$HADOOP_HOME
echo HIVE_HOME=$HIVE_HOME
echo SPARK_HOME=$SPARK_HOME
echo FLINK_HOME=$FLINK_HOME

# test hdfs
hadoop fs -ls  /
hadoop fs -ls  hdfs://namenode:8020/

# test hive
hive -e 'show databases;'
hive -e 'select * from default.pokes;'

# test spark

#命令行执行执行sql
spark-sql -e "show databases;"
spark-sql -e "select * from default.pokes;"

#spark on local
spark-submit --master local --class org.apache.spark.examples.SparkPi /opt/spark/spark-2.4.4-bin-hadoop2.7/examples/jars/spark-examples_2.11-2.4.4.jar 100
#spark on yarn
spark-submit --master yarn --class org.apache.spark.examples.SparkPi /opt/spark/spark-2.4.4-bin-hadoop2.7/examples/jars/spark-examples_2.11-2.4.4.jar 100

# test flink

#Flink Per-Job-Cluster
flink run -m yarn-cluster $FLINK_HOME/examples/batch/WordCount.jar

flink run -m yarn-cluster $FLINK_HOME/examples/streaming/TopSpeedWindowing.jar

# test flinkx

# flinx 以Yarn Perjob模式运行任务
/opt/flinkx/flinkx-1.10.4/flinkx/bin/flinkx \
-mode yarnPer \
-job /opt/flinkx/flinkx-1.10.4/flinkx/docs/example/stream_stream.json \
-flinkconf $FLINK_HOME/conf \
-yarnconf $HADOOP_HOME/etc/hadoop \
-flinkLibJar $FLINK_HOME/lib \
-confProp "{\"flink.checkpoint.interval\":60000}" \
-queue default




