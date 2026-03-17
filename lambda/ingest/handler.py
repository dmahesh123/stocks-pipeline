import json
import os
import boto3
import urllib.request
import urllib.error
from datetime import datetime, timezone
from decimal import Decimal

WATCHLIST = ["AAPL", "MSFT", "GOOGL", "AMZN", "TESLA", "NVDA"]
MASSIVE_BASE = "https://api.massive.com/v2/aggs/ticker"
ANTHROPIC_URL = "https://api.anthropic.com/v1/messages"
ANTHROPIC_MODEL = "claude-3-5-haiku-20241022"

dynamodb = boto3.resource("dynamodb", region_name=os.environ["AWS_REGION_NAME"])
table = dynamodb.Table(os.environ["DYNAMODB_TABLE"])

# get the stock data
def get_stock_data(ticker, date_str, api_key):

    url = f"{MASSIVE_BASE}/{ticker}/range/1/day/{date_str}/{date_str}?apiKey={api_key}"

    req = urllib.request.Request(url)
    with urllib.request.urlopen(req, timeout=10) as response:
        data = json.loads(response.read().decode())
    
    # handle exception when market is closed
    if data.get("status") != "OK" or not data.get("results"):
        return None

    result = data["results"][0]
    return float(result["o"]), float(result["c"])


def calculate_stock_percent_change(open_price, close_price):
    #((Close - Open) / Open) * 100

    return ((close_price - open_price)/open_price) * 100


def lambda_handler(event, context):
    # aws calls
    massive_key = os.environ["MASSIVE_API_KEY"]
    anthropic_key = os.environ["ANTHROPIC_API_KEY"]

    today = datetime.now(timezone.utc).strftime("%Y-%m-%d")
    print(f"[INFO] Running ingest for date: {today}")

    results = {}

    # get stock data
    for ticker in WATCHLIST:
        try:
            prices = get_stock_data(ticker, today, massive_key)

            if prices is None:
                print("[INFO] {ticker}: No data, likely due to market being closed.")
                continue
            open_price, close_price = prices
            percent_change = calculate_stock_percent_change(open_price, close_price)
            results[ticker] = {"percent_change": percent_change, "close": close_price}
            print(f"[INFO] {ticker}: open={open_price}, close={close_price}, change={round(percent_change, 2)}%")

        except urllib.error.HTTPError as e:
            print(f"[Error] HTTP error fetching {ticker}: {e.code} {e.reason}")
        except urllib.error.URLError as e:
            print(f"[Error] Network error fetching {ticker}: {e.reason}")
        except Exception as e:
            print(f"[Error] Unexpected error fetching {ticker}: {str(e)}")

    if not results:
        print("[INFO] No stock data received, likely due to market being closed. Exiting")
        return {"statusCode": 200, "body": "Market closed, nothing to record."}
    
    top_ticker = max(results, key=lambda t: abs(results[t]["percent_change"]))
    top_percent = results[top_ticker]["percent_change"]
    top_close = results[top_ticker]["close"]

    print(f"[Info] Top Mover: {top_ticker} at {round(top_percent, 2)}%")

    # ai summary
    try:
        table.put_items(Item={
            "date": today,
            "ticker": top_ticker,
            "percent_change": Decimal(str(round(top_percent, 4))),
            "close_price": Decimal(str(round(close_price, 4))),
            # "ai_summary": ai_summary
        })
        print(f"[INFO] Successfully Saved to DynamoDB.")
    except Exception as e:
        print(f"[Error] DynamoDB write failed: {str(e)}")
        raise

    return {
        "statusCode": 200,
        "body": json.dumps({
            "date": today,
            "top_mover": top_ticker,
            "percent_change": round(top_percent, 4),
            close_price: round(top_close, 4)
            # "ai_summary": ai_summary
        })
    }

            
    


# def get_ai_summary(ticker, percent_change, close_price, all_results, anthrophic_key):
    
#     # work on later, need prompt
