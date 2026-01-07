import json
import random
from datetime import datetime

def lambda_handler(event, context):
    print(f"DevOpsAgent Test Lambda - {datetime.now()}")
    error_scenarios = [
        "Simulated database connection timeout",
        "Test API rate limit exceeded", 
        "Intentional validation error for AWS DevOpsAgent testing"
    ]
    error_message = random.choice(error_scenarios)
    raise Exception(f"DevOpsAgent Test Error: {error_message}")