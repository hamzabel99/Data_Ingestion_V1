import sys
from pyspark.context import SparkContext
from awsglue.context import GlueContext
from awsglue.job import Job
from awsglue.utils import getResolvedOptions
from pyspark.sql.functions import col, to_timestamp
import os

# Arguments passés par la Step Function via Lambda
args = getResolvedOptions(sys.argv, ['JOB_NAME', 'input_bucket', 's3_key'])
sc = SparkContext()
glueContext = GlueContext(sc)
spark = glueContext.spark_session
job = Job(glueContext)
job.init(args['JOB_NAME'], args)


# ---- 1. Lecture dynamique depuis le bucket + clé ----
input_path = f"s3://{args['input_bucket']}/{args['s3_key']}"
df = spark.read.option("header", True).csv(input_path)


# ---- 2. Transformation classique ----
df_transformed = (
    df.withColumnRenamed("Open", "open_price")
      .withColumnRenamed("Close", "close_price")
      .withColumnRenamed("High", "high_price")
      .withColumnRenamed("Low", "low_price")
      .withColumnRenamed("Volume", "volume")
      .withColumn("timestamp", to_timestamp(col("Date"), "yyyy-MM-dd HH:mm:ss"))
      .withColumn("price_change", col("close_price").cast("double") - col("open_price").cast("double"))
      .drop("Date")  # Supprime la colonne d'origine
)


# ---- 3. Écriture en Parquet dans un bucket de sortie fixe ----
# Tu peux définir ce bucket dans une variable d'environnement Glue
output_bucket = os.environ.get("OUTPUT_BUCKET", "postworkflow-ingestion-bucket")
# On génère un chemin Parquet basé sur le nom du fichier original
s3_key_basename = os.path.splitext(os.path.basename(args['s3_key']))[0]
output_path = f"s3://{output_bucket}/{s3_key_basename}/"


df_transformed.write.mode("overwrite").parquet(output_path)


job.commit()
