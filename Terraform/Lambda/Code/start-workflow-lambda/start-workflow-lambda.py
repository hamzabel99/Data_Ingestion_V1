import json
import boto3
import os

# Clients AWS
dynamodb = boto3.resource("dynamodb")
sfn_client = boto3.client("stepfunctions")

# Nom de la table en variable d'environnement (bonne pratique)
WORKFLOW_METADATA_TABLE = os.environ.get("WORKFLOW_METADATA_TABLE", "workflow_metadata")
WORKFLOW_TRACK_TABLE = os.environ.get("WORKFLOW_TABLE", "workflow_statut")


def lambda_handler(event, context):
    """
    Lambda triggered by SQS, which contains an S3 event.
    Reads workflow_metadata DynamoDB table to find the right StepFunction ARN
    and starts the execution.
    """
    print("Received event:", json.dumps(event))

    metadata_table = dynamodb.Table(WORKFLOW_METADATA_TABLE)
    workflow_table = dynamodb.Table(WORKFLOW_TRACK_TABLE)


    for record in event["Records"]:
        # Le corps du message SQS est une string JSON
        sqs_body = json.loads(record["body"])
        
        # On récupère l’event S3 à l’intérieur
        s3_event = sqs_body["Records"][0]
        bucket = s3_event["s3"]["bucket"]["name"]
        object_key = s3_event["s3"]["object"]["key"]

        print(f"Processing object: s3://{bucket}/{object_key}")

        # Extraire le préfixe (par ex : "Belabbes_Hamza.pdf" -> "Belabbes_")
        # À adapter selon ta convention de préfixe
        s3_prefix = object_key.split("/")[0]

        # Récupérer la Step Function ARN depuis DynamoDB
        response = metadata_table.get_item(Key={"s3_prefix": s3_prefix})

        if "Item" not in response:
            print(f"No workflow found for prefix: {s3_prefix}")
            continue

        stepfn_arn = response["Item"]["step_function_arn"]

        # Lancer la Step Function
        input_payload = {
            "input_bucket": bucket,
            "key": object_key
        }

        print(f"Starting StepFunction {stepfn_arn} with input {input_payload}")

        sfn_client.start_execution(
            stateMachineArn=stepfn_arn,
            input=json.dumps(input_payload)
        )

        workflow_table.put_item(
        Item={
            "s3_prefix": s3_prefix,
            "start_time": datetime.utcnow().isoformat(),
            "status": "Started"
        }
    )

    return {"status": "done"}
