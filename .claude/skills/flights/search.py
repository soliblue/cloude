#!/usr/bin/env python3
import sys
import json
import requests
from fast_flights import FlightData, Passengers
from fast_flights.filter import TFSData
from fast_flights.core import parse_response


class FakeRes:
    def __init__(self, text):
        self.text = text
        self.text_markdown = text[:1000]


def get_session():
    session = requests.Session()
    session.headers.update({
        "User-Agent": "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36",
        "Accept-Language": "en-US,en;q=0.9",
    })
    session.get("https://www.google.com/")
    session.post("https://consent.google.com/save", data={
        "continue": "https://www.google.com/",
        "gl": "DE", "m": "0", "pc": "flt", "x": "6", "src": "1", "hl": "en",
        "bl": "boq_identityfrontenduiserver_20230829.07_p1", "set_eom": "true",
    }, allow_redirects=True)
    return session


def search_flights(session, legs, trip_type, currency="EUR"):
    flight_data = [
        FlightData(date=leg["date"], from_airport=leg["from"], to_airport=leg["to"])
        for leg in legs
    ]

    tfs = TFSData.from_interface(
        flight_data=flight_data,
        trip=trip_type,
        passengers=Passengers(adults=1),
        seat="economy",
    )

    res = session.get("https://www.google.com/travel/flights", params={
        "tfs": tfs.as_b64().decode("utf-8"),
        "hl": "en",
        "tfu": "EgQIABABIgA",
        "curr": currency,
    })

    if "IWWDBc" not in res.text and "YdtKid" not in res.text:
        return []

    result = parse_response(FakeRes(res.text))
    return [
        {
            "name": f.name,
            "departure": f.departure,
            "arrival": f.arrival,
            "duration": f.duration,
            "price": f.price,
            "stops": f.stops,
            "is_best": f.is_best,
        }
        for f in result.flights
    ]


def main():
    if len(sys.argv) < 2:
        print("Usage: search.py '<json>'")
        print('Example: search.py \'{"searches": [{"label": "BER to HRG", "legs": [{"date": "2026-04-28", "from": "BER", "to": "HRG"}], "trip": "one-way"}]}\'')
        sys.exit(1)

    data = json.loads(sys.argv[1])
    currency = data.get("currency", "EUR")
    session = get_session()
    results = {}

    for search in data["searches"]:
        label = search["label"]
        flights = search_flights(session, search["legs"], search["trip"], currency)
        results[label] = flights

    print(json.dumps(results, indent=2))


if __name__ == "__main__":
    main()
