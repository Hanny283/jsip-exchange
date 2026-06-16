window.BENCHMARK_DATA = {
  "lastUpdate": 1781624670757,
  "repoUrl": "https://github.com/Hanny283/jsip-exchange",
  "entries": {
    "Order book benchmark": [
      {
        "commit": {
          "author": {
            "email": "hanselcarmona5@gmail.com",
            "name": "Hansel",
            "username": "Hanny283"
          },
          "committer": {
            "email": "hanselcarmona5@gmail.com",
            "name": "Hansel",
            "username": "Hanny283"
          },
          "distinct": true,
          "id": "5708473e9d27e7942fa90823b530269d70f996ea",
          "message": "implemented is_more_aggressive and is_marketable",
          "timestamp": "2026-06-16T15:38:42Z",
          "tree_id": "bd18e66fb454b10819041a5219f6033acd92edd7",
          "url": "https://github.com/Hanny283/jsip-exchange/commit/5708473e9d27e7942fa90823b530269d70f996ea"
        },
        "date": 1781624670095,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "find_match (n=10)",
            "value": 28.07268397079967,
            "unit": "ns"
          },
          {
            "name": "find_match (n=50)",
            "value": 28.078782028137844,
            "unit": "ns"
          },
          {
            "name": "find_match (n=100)",
            "value": 28.081912159554072,
            "unit": "ns"
          },
          {
            "name": "find_match (n=500)",
            "value": 27.762493392512663,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=10)",
            "value": 125.93456638840433,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=50)",
            "value": 631.9351188486249,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=100)",
            "value": 1359.5947914470082,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=500)",
            "value": 6714.1830715946535,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=10)",
            "value": 261.37233155939,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=50)",
            "value": 1214.0631118141152,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=100)",
            "value": 2274.153135489585,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=500)",
            "value": 11114.717841364269,
            "unit": "ns"
          },
          {
            "name": "add+remove (n=100)",
            "value": 1746.3050823914352,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=10)",
            "value": 1330.0885939972402,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=50)",
            "value": 5592.640107672721,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=100)",
            "value": 11211.171139621107,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=500)",
            "value": 53149.870694675126,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=10)",
            "value": 688.5391902175443,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=50)",
            "value": 2994.93663694691,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=100)",
            "value": 6088.990447696266,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=500)",
            "value": 28833.42776734881,
            "unit": "ns"
          },
          {
            "name": "submit_sweep_10_levels",
            "value": 5668.571783580111,
            "unit": "ns"
          },
          {
            "name": "submit_sweep_50_levels",
            "value": 87911.88118775084,
            "unit": "ns"
          },
          {
            "name": "submit_sweep_100_levels",
            "value": 326768.7309849888,
            "unit": "ns"
          },
          {
            "name": "find_match_alloc (n=100)",
            "value": 25.69501691887991,
            "unit": "ns"
          }
        ]
      }
    ]
  }
}