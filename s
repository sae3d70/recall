import requests
import pandas as pd
import ta
import time

# تنظیمات Agent
AGENT_URL = 'https://agent.recall.network/api'
AGENT_TOKEN = 'YOUR_AGENT_TOKEN'
PAIR = 'ETH-USDC'
INTERVAL = '1h'
LIMIT = 100

HEADERS = {
    'Authorization': f'Bearer {AGENT_TOKEN}',
    'Content-Type': 'application/json'
}

def fetch_data():
    url = f"{AGENT_URL}/marketdata/ohlcv?pair={PAIR}&interval={INTERVAL}&limit={LIMIT}"
    response = requests.get(url, headers=HEADERS)
    data = response.json()
    df = pd.DataFrame(data['candles'])
    df.columns = ['timestamp', 'open', 'high', 'low', 'close', 'volume']
    df['timestamp'] = pd.to_datetime(df['timestamp'], unit='ms')
    return df

def apply_indicators(df):
    df['obv'] = ta.volume.OnBalanceVolumeIndicator(close=df['close'], volume=df['volume']).on_balance_volume()
    df['mfi'] = ta.volume.MFIIndicator(high=df['high'], low=df['low'], close=df['close'], volume=df['volume']).money_flow_index()
    df['vwap'] = ta.volume.VolumeWeightedAveragePrice(high=df['high'], low=df['low'], close=df['close'], volume=df['volume']).volume_weighted_average_price()
    return df

def signal_generator(df):
    latest = df.iloc[-1]
    if latest['mfi'] < 25 and latest['volume'] > df['volume'].rolling(10).mean().iloc[-1]:
        return 'buy'
    elif latest['mfi'] > 75 and latest['volume'] > df['volume'].rolling(10).mean().iloc[-1]:
        return 'sell'
    else:
        return 'hold'

def execute_trade(signal):
    if signal in ['buy', 'sell']:
        payload = {
            "pair": PAIR,
            "side": signal,
            "amount": 1  # مقدار قابل تنظیم
        }
        response = requests.post(f"{AGENT_URL}/trade", headers=HEADERS, json=payload)
        print(f"✅ {signal.upper()} order sent. Response: {response.status_code}")
    else:
        print("⏸ No trade executed.")

while True:
    try:
        df = fetch_data()
        df = apply_indicators(df)
        signal = signal_generator(df)
        execute_trade(signal)
        time.sleep(3600)
    except Exception as e:
        print(f"⚠️ Error: {e}")
        time.sleep(60)
