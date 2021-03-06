#!/bin/bash

source /etc/profile

echo JAVA_HOME=$JAVA_HOME
echo SCALA_HOME=$SCALA_HOME
echo HADOOP_HOME=$HADOOP_HOME
echo HIVE_HOME=$HIVE_HOME
echo SPARK_HOME=$SPARK_HOME

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




