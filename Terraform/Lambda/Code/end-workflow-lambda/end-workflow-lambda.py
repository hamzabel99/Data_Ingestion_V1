import boto3
from datetime import datetime
import os

# Initialisation DynamoDB
dynamodb = boto3.resource('dynamodb')
table_name = os.environ.get("WORKFLOW_TABLE", "workflow_statut")
table = dynamodb.Table(table_name)

def lambda_handler(event, context):
    """
    event attendu :
    {
        "input_bucket": "my-bucket",
        "key": "data/file.csv"
    }
    """
    # Recomposer le s3_prefix
    s3_prefix = f"s3://{event['input_bucket']}/{event['s3_key']}"
    
    # Mettre à jour l'entrée DynamoDB
    table.update_item(
        Key={"s3_prefix": s3_prefix},
        UpdateExpression="SET end_time=:et, #st=:st",
        ExpressionAttributeValues={
            ":et": datetime.utcnow().isoformat(),
            ":st": "DONE"
        },
        ExpressionAttributeNames={
            "#st": "status"  # status est un mot réservé
        }
    )
    
    return {"message": "Workflow updated"}
