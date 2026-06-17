window.BENCHMARK_DATA = {
  "lastUpdate": 1781724569309,
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
          "id": "45b08a047aa84b4f196809dec5ce4b84021f0f91",
          "message": "updated expected outputs of affected tests after changing find_match and snapshot_side",
          "timestamp": "2026-06-17T19:25:12Z",
          "tree_id": "e3d6fbec2d2f5d7eb6d4df34f6ad9b22f34f856e",
          "url": "https://github.com/Hanny283/jsip-exchange/commit/45b08a047aa84b4f196809dec5ce4b84021f0f91"
        },
        "date": 1781724530852,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "find_match (n=10)",
            "value": 297.7486722779394,
            "unit": "ns"
          },
          {
            "name": "find_match (n=50)",
            "value": 1470.3936400983937,
            "unit": "ns"
          },
          {
            "name": "find_match (n=100)",
            "value": 2944.605787004973,
            "unit": "ns"
          },
          {
            "name": "find_match (n=500)",
            "value": 15643.628716162604,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=10)",
            "value": 114.60086686691736,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=50)",
            "value": 530.3393795470625,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=100)",
            "value": 1045.6994613741804,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=500)",
            "value": 4974.096599168483,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=10)",
            "value": 222.28472078008062,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=50)",
            "value": 1096.188324622852,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=100)",
            "value": 2141.87784048854,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=500)",
            "value": 10288.690548145449,
            "unit": "ns"
          },
          {
            "name": "add+remove (n=100)",
            "value": 1422.028698146377,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=10)",
            "value": 1588.5276653194821,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=50)",
            "value": 6841.285717378028,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=100)",
            "value": 13320.643768191894,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=500)",
            "value": 64572.75136794429,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=10)",
            "value": 637.6170009531941,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=50)",
            "value": 2800.840634567894,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=100)",
            "value": 5511.200176591886,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=500)",
            "value": 25710.735328290135,
            "unit": "ns"
          },
          {
            "name": "submit_sweep_10_levels",
            "value": 6558.428041508288,
            "unit": "ns"
          },
          {
            "name": "submit_sweep_50_levels",
            "value": 118503.55798247876,
            "unit": "ns"
          },
          {
            "name": "submit_sweep_100_levels",
            "value": 443277.66135987866,
            "unit": "ns"
          },
          {
            "name": "find_match_alloc (n=100)",
            "value": 2921.1833482285856,
            "unit": "ns"
          }
        ]
      },
      {
        "commit": {
          "author": {
            "email": "64275957+Hanny283@users.noreply.github.com",
            "name": "Hansel Carmona",
            "username": "Hanny283"
          },
          "committer": {
            "email": "noreply@github.com",
            "name": "GitHub",
            "username": "web-flow"
          },
          "distinct": true,
          "id": "3de9aff16a357df6efd075b19d02c393254df3fe",
          "message": "Merge branch 'jane-street-immersion-program:main' into main",
          "timestamp": "2026-06-17T15:25:30-04:00",
          "tree_id": "f0f07622c1cffef76c45d8ed432a5178e7491bb5",
          "url": "https://github.com/Hanny283/jsip-exchange/commit/3de9aff16a357df6efd075b19d02c393254df3fe"
        },
        "date": 1781724567403,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "find_match (n=10)",
            "value": 287.4055510516468,
            "unit": "ns"
          },
          {
            "name": "find_match (n=50)",
            "value": 1487.634851379457,
            "unit": "ns"
          },
          {
            "name": "find_match (n=100)",
            "value": 2981.39881019094,
            "unit": "ns"
          },
          {
            "name": "find_match (n=500)",
            "value": 15023.444598198483,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=10)",
            "value": 120.14393264828455,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=50)",
            "value": 571.053221529005,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=100)",
            "value": 1080.6440165764773,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=500)",
            "value": 5353.261437961763,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=10)",
            "value": 216.4540773591878,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=50)",
            "value": 1010.8362119971588,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=100)",
            "value": 1989.8111053522348,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=500)",
            "value": 9752.619484090754,
            "unit": "ns"
          },
          {
            "name": "add+remove (n=100)",
            "value": 1465.835863693028,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=10)",
            "value": 1573.8442048463219,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=50)",
            "value": 6873.805197168795,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=100)",
            "value": 13161.794719617723,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=500)",
            "value": 64435.91693313578,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=10)",
            "value": 626.3624839756687,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=50)",
            "value": 2706.4116006303443,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=100)",
            "value": 5297.666995380204,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=500)",
            "value": 25303.612228973616,
            "unit": "ns"
          },
          {
            "name": "submit_sweep_10_levels",
            "value": 6629.999140193474,
            "unit": "ns"
          },
          {
            "name": "submit_sweep_50_levels",
            "value": 116973.27909250716,
            "unit": "ns"
          },
          {
            "name": "submit_sweep_100_levels",
            "value": 453898.5228283474,
            "unit": "ns"
          },
          {
            "name": "find_match_alloc (n=100)",
            "value": 3010.6297855646244,
            "unit": "ns"
          }
        ]
      }
    ]
  }
}