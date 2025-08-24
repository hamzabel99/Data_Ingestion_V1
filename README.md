## Data Ingestion Pipeline : CSV → Parquet with AWS - VERSION 1

#### NOTE : THIS README WAS WRITTEN MANUALLY WITHOUT THE USE OF ANY GEN AI TOOL. PLEASE TAKE THE TIME TO READ IT, AS I PUT EFFORT INTO WRITING IT RATHER THAN JUST TELLING CHATGPT TO DO IT FOR ME 🙂 .


## Context :

This project implements a **data ingestion pipeline** on AWS.  
The goal is to create a multi-workflow pipeline that ingest (probably more than just ingesting in the future) different data type through different workflow orchestrated by different Step Functions definitions.

## Architecture Diagram

![Pipeline Architecture](Ingestion%20mvp.png)


---

##  Architecture

### Main Steps

1. **CSV Upload**
   - A file is uploaded to the **`pre-workflow-ingestion-bucket`** under a specific prefix.

2. **S3 Event → SQS**
   - The file upload triggers an **S3 event**, which is sent to an **SQS queue**.
   - **WHY THE SQS QUEUE ?** : It allows us to be sure that no event will be lost. If we have a lot of files coming at the same time and directly triggering the Lambda function, it can happen that the Lambda be throttled and miss some event. With the SQS this is no longer an issue as the events stay in the queue as long as the Lambda didn't process successfully the event.

3. **Orchestrator Lambda**
   - The Lambda consumes messages from the SQS and performs 3 actions:
     
     1.  **Metadata check** in a **DynamoDB table (For each prefix or data we have a separate step function allowing us to ingest different use cases)**  
        - `prefix`: file prefix  
        - `step_function`: ARN of the Step Function to trigger
        - **NOTE :** The "Workflow_metadata" DynamoDB table is a table that contains the "Businnes" metadata about our worflows. Which means that data contained in it is completly done by hand.
     
     2.  **Triggering the Step Function** based on the prefix
        
     3.  **Workflow tracking** in a second **DynamoDB table (`workflow_status`)**  
        - `file_id`: combination of `prefix + filename`  
        - `start_time`: timestamp when the workflow started  
        - `status`: `"started"`
        - **Why do we need the Workflow_status  DynamoDB table ?** This DynamoDB table help us keep track of the pipelines and the duration of the workflows for each file or batch of files. In the future, we can easily use this information to add some monitoring that keep tracks of the data.

4. **Step Function**
   - Orchestrates the tasks:
     1. **Glue Job (Spark/Python)** : For this project the spark Job is very basic and running on the smallest possible instance as I'm more focusing on architecture rather than the data and the transformations :
        - Lightweight data cleaning (renaming columns, creating computed columns)  
        - **CSV → Parquet conversion**  
        - Stores the Parquet file in the **`post-workflow-ingestion-bucket`**
          
     3. **Final Lambda**
        - Updates the **`workflow_status`** table in DynamoDB. 
          - `status = "done"`  
          - Adds a new column `finish_time`

---
