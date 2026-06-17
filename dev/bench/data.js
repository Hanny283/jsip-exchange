window.BENCHMARK_DATA = {
  "lastUpdate": 1781722545819,
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
      },
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
          "id": "d8fd0ee6a26c99db7ab39b10713253645399e402",
          "message": "implemented best_price",
          "timestamp": "2026-06-17T15:46:15Z",
          "tree_id": "3cd1890a471d610764c3156fa561353025cbe501",
          "url": "https://github.com/Hanny283/jsip-exchange/commit/d8fd0ee6a26c99db7ab39b10713253645399e402"
        },
        "date": 1781711466969,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "find_match (n=10)",
            "value": 21.60410463216105,
            "unit": "ns"
          },
          {
            "name": "find_match (n=50)",
            "value": 21.511528180388602,
            "unit": "ns"
          },
          {
            "name": "find_match (n=100)",
            "value": 21.545076890118644,
            "unit": "ns"
          },
          {
            "name": "find_match (n=500)",
            "value": 21.579716777650734,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=10)",
            "value": 110.00595106349678,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=50)",
            "value": 503.3646457174774,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=100)",
            "value": 984.8180381497777,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=500)",
            "value": 4854.524171722796,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=10)",
            "value": 223.69548031027458,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=50)",
            "value": 1015.5706405674546,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=100)",
            "value": 2081.826291862446,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=500)",
            "value": 10307.166899880538,
            "unit": "ns"
          },
          {
            "name": "add+remove (n=100)",
            "value": 1482.121849856673,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=10)",
            "value": 1236.550446978426,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=50)",
            "value": 5419.952358040997,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=100)",
            "value": 10081.06793371482,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=500)",
            "value": 49136.3217156277,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=10)",
            "value": 632.4923383958138,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=50)",
            "value": 2781.2577978190325,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=100)",
            "value": 5103.923932179738,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=500)",
            "value": 25451.28373761207,
            "unit": "ns"
          },
          {
            "name": "submit_sweep_10_levels",
            "value": 5202.820533935134,
            "unit": "ns"
          },
          {
            "name": "submit_sweep_50_levels",
            "value": 82802.01453591163,
            "unit": "ns"
          },
          {
            "name": "submit_sweep_100_levels",
            "value": 310649.4003997082,
            "unit": "ns"
          },
          {
            "name": "find_match_alloc (n=100)",
            "value": 21.9015224016333,
            "unit": "ns"
          }
        ]
      },
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
          "id": "428d34595a87f19afcc8cc797053772b99d8595f",
          "message": "implemented naive find_match and wrote tests for is_more_aggressive and is_marketable",
          "timestamp": "2026-06-17T16:31:44Z",
          "tree_id": "0fa3d52eaa26da4f391b3ad320181f14b4ec5881",
          "url": "https://github.com/Hanny283/jsip-exchange/commit/428d34595a87f19afcc8cc797053772b99d8595f"
        },
        "date": 1781714159040,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "find_match (n=10)",
            "value": 20.4770110754444,
            "unit": "ns"
          },
          {
            "name": "find_match (n=50)",
            "value": 20.587326982345825,
            "unit": "ns"
          },
          {
            "name": "find_match (n=100)",
            "value": 20.436934530985425,
            "unit": "ns"
          },
          {
            "name": "find_match (n=500)",
            "value": 20.443336667089042,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=10)",
            "value": 104.1191384028526,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=50)",
            "value": 485.71327794215034,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=100)",
            "value": 954.2619052304445,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=500)",
            "value": 4661.879373191249,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=10)",
            "value": 241.48555513290702,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=50)",
            "value": 1088.79998988902,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=100)",
            "value": 2146.1693077162595,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=500)",
            "value": 10143.56686820829,
            "unit": "ns"
          },
          {
            "name": "add+remove (n=100)",
            "value": 1172.6475954948282,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=10)",
            "value": 1275.0075570528907,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=50)",
            "value": 5484.894263505209,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=100)",
            "value": 10663.209821117483,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=500)",
            "value": 51589.62080079168,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=10)",
            "value": 689.8016846122997,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=50)",
            "value": 3065.650161637793,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=100)",
            "value": 5938.803701269719,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=500)",
            "value": 28344.126226439326,
            "unit": "ns"
          },
          {
            "name": "submit_sweep_10_levels",
            "value": 5430.829452688502,
            "unit": "ns"
          },
          {
            "name": "submit_sweep_50_levels",
            "value": 84777.91382942816,
            "unit": "ns"
          },
          {
            "name": "submit_sweep_100_levels",
            "value": 319136.3144100296,
            "unit": "ns"
          },
          {
            "name": "find_match_alloc (n=100)",
            "value": 20.4254844612894,
            "unit": "ns"
          }
        ]
      },
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
          "id": "e48ebd05879e7ebb3b0d240728d1714378433086",
          "message": "implemented find_match and snapshot_side",
          "timestamp": "2026-06-17T18:51:30Z",
          "tree_id": "900223e59b7b90980d42a88303c9f82d367a3c7b",
          "url": "https://github.com/Hanny283/jsip-exchange/commit/e48ebd05879e7ebb3b0d240728d1714378433086"
        },
        "date": 1781722544896,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "find_match (n=10)",
            "value": 347.0091260664499,
            "unit": "ns"
          },
          {
            "name": "find_match (n=50)",
            "value": 1643.2225632009497,
            "unit": "ns"
          },
          {
            "name": "find_match (n=100)",
            "value": 3239.808465907193,
            "unit": "ns"
          },
          {
            "name": "find_match (n=500)",
            "value": 16444.00022650952,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=10)",
            "value": 125.24239462019202,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=50)",
            "value": 530.7901089241625,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=100)",
            "value": 1177.0646473050845,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=500)",
            "value": 5835.198974447355,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=10)",
            "value": 256.22949772982497,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=50)",
            "value": 1198.3590481637568,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=100)",
            "value": 2464.0926779532138,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=500)",
            "value": 12272.56763546166,
            "unit": "ns"
          },
          {
            "name": "add+remove (n=100)",
            "value": 1625.2660736684468,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=10)",
            "value": 1824.3168574410945,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=50)",
            "value": 7583.314318398536,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=100)",
            "value": 14660.428451995527,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=500)",
            "value": 67879.0418455814,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=10)",
            "value": 711.6341287518582,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=50)",
            "value": 2974.6558559960645,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=100)",
            "value": 5878.4261148534515,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=500)",
            "value": 27363.32378944009,
            "unit": "ns"
          },
          {
            "name": "submit_sweep_10_levels",
            "value": 7563.788202936729,
            "unit": "ns"
          },
          {
            "name": "submit_sweep_50_levels",
            "value": 133472.7413284745,
            "unit": "ns"
          },
          {
            "name": "submit_sweep_100_levels",
            "value": 507228.9454062309,
            "unit": "ns"
          },
          {
            "name": "find_match_alloc (n=100)",
            "value": 3465.7290544791454,
            "unit": "ns"
          }
        ]
      }
    ]
  }
}