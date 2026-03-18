import json
import os
import boto3
import urllib.request
import urllib.error
from datetime import datetime, timedelta, timezone
from decimal import Decimal

dynamodb = boto3.resource(
    "dynamodb", region_name=os.environ["AWS_REGION_NAME"])
table = dynamodb.Table(os.environ["DYNAMODB_TABLE"])


def get_last_seven_dates():
    today = datetime.now(timezone.utc)
    return [
        (today - timedelta(days=i)).strftime("%Y-%m-%d")
        for i in range(7)
    ]


def lambda_handler(event, context):
    headers = {
        "Content-Type": "application/json",
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Methods": "GET,OPTIONS",
        "Access-Control-Allow-Headers": "Content-Type",
    }

    if event.get("httpMethod") == "OPTIONS":
        return {"statusCode": 200, "headers": headers, "body": ""}

    try:
        dates = get_last_seven_dates()
        movers = []

        for date_str in dates:
            response = table.get_item(Key={"date": date_str})
            item = response.get("Item")
            if item:
                movers.append({
                    "date": item["date"],
                    "ticker": item["ticker"],
                    "percent_change": float(item["percent_change"]),
                    "close_price": float(item["close_price"]),
                    "ai_summary": item.get("ai_summary", "")
                })

            movers.sort(key=lambda x: x["date"], reverse=True)
            print(f"[INFO] Returning {len(movers)} records.")

            return {
                "statusCode": 200,
                "headers": headers,
                "body": json.dumps({
                    "count": len(movers),
                    "movers": movers
                }, default=decimal_to_float)

            }

    except Exception as e:
        print(f"[ERROR] Failed to retrieve movers: {str(e)}")
        return {
            "statusCode": 500,
            "headers": headers,
            "body": json.dumps({"error": "Internal server error. Please try again later."})
        }


def decimal_to_float(obj):
    if isinstance(obj, Decimal):
        return float(obj)
    raise TypeError(f"Object of type {type(obj)} is not JSON serializable")
