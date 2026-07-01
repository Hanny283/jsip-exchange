window.BENCHMARK_DATA = {
  "lastUpdate": 1782910004426,
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
          "id": "9826978949165eea9e5bdda6849934e22460d7f3",
          "message": "fixed price.ml",
          "timestamp": "2026-06-17T20:05:12Z",
          "tree_id": "f122b95988c68a6f7d8aa0e349a46505f9d7db8a",
          "url": "https://github.com/Hanny283/jsip-exchange/commit/9826978949165eea9e5bdda6849934e22460d7f3"
        },
        "date": 1781726999864,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "find_match (n=10)",
            "value": 234.27813200000327,
            "unit": "ns"
          },
          {
            "name": "find_match (n=50)",
            "value": 1074.867613800628,
            "unit": "ns"
          },
          {
            "name": "find_match (n=100)",
            "value": 2052.4110438505127,
            "unit": "ns"
          },
          {
            "name": "find_match (n=500)",
            "value": 10392.807801033012,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=10)",
            "value": 216.04627399152955,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=50)",
            "value": 1061.2660817380647,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=100)",
            "value": 2091.239538659018,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=500)",
            "value": 10075.860708926592,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=10)",
            "value": 254.86565355564193,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=50)",
            "value": 1192.5432967302233,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=100)",
            "value": 2338.5527974177126,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=500)",
            "value": 11643.722192179182,
            "unit": "ns"
          },
          {
            "name": "add+remove (n=100)",
            "value": 1607.4317276117515,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=10)",
            "value": 1751.6442733113013,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=50)",
            "value": 7516.97534696003,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=100)",
            "value": 15035.502070099614,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=500)",
            "value": 71215.1510859782,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=10)",
            "value": 843.7519006133859,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=50)",
            "value": 3751.893225708174,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=100)",
            "value": 7393.873826624577,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=500)",
            "value": 36724.54762745325,
            "unit": "ns"
          },
          {
            "name": "submit_sweep_10_levels",
            "value": 7149.105499354002,
            "unit": "ns"
          },
          {
            "name": "submit_sweep_50_levels",
            "value": 122045.65566477718,
            "unit": "ns"
          },
          {
            "name": "submit_sweep_100_levels",
            "value": 464536.85553789744,
            "unit": "ns"
          },
          {
            "name": "find_match_alloc (n=100)",
            "value": 2338.3577291725833,
            "unit": "ns"
          }
        ]
      },
      {
        "commit": {
          "author": {
            "email": "hec66@cornell.edu",
            "name": "Hansel Carmona",
            "username": "Hanny283"
          },
          "committer": {
            "email": "hec66@cornell.edu",
            "name": "Hansel Carmona",
            "username": "Hanny283"
          },
          "distinct": true,
          "id": "1caaf2bfcdd321d491bc2d130b6e9a1ffa509ed2",
          "message": "fixed logic bugs in find_match and snapshot_side and updated tests accordingly",
          "timestamp": "2026-06-17T19:14:45-04:00",
          "tree_id": "9d21187434f46e9a84c8c847bff9b36b159bd223",
          "url": "https://github.com/Hanny283/jsip-exchange/commit/1caaf2bfcdd321d491bc2d130b6e9a1ffa509ed2"
        },
        "date": 1781738459085,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "find_match (n=10)",
            "value": 160.5481495390403,
            "unit": "ns"
          },
          {
            "name": "find_match (n=50)",
            "value": 703.6319039622226,
            "unit": "ns"
          },
          {
            "name": "find_match (n=100)",
            "value": 1373.2265537284072,
            "unit": "ns"
          },
          {
            "name": "find_match (n=500)",
            "value": 6811.91000862415,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=10)",
            "value": 161.053838588271,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=50)",
            "value": 692.4967493243513,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=100)",
            "value": 1372.465706051223,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=500)",
            "value": 6812.9238508685385,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=10)",
            "value": 187.042434011829,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=50)",
            "value": 939.3925082164595,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=100)",
            "value": 1806.5450174580826,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=500)",
            "value": 8883.403013574678,
            "unit": "ns"
          },
          {
            "name": "add+remove (n=100)",
            "value": 1902.4681484203802,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=10)",
            "value": 1242.1269174676804,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=50)",
            "value": 5652.22048003421,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=100)",
            "value": 10847.535201006582,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=500)",
            "value": 52662.26066560908,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=10)",
            "value": 590.6663974836299,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=50)",
            "value": 2809.79254480124,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=100)",
            "value": 5233.713951430623,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=500)",
            "value": 25340.647829878155,
            "unit": "ns"
          },
          {
            "name": "submit_sweep_10_levels",
            "value": 5289.991687565565,
            "unit": "ns"
          },
          {
            "name": "submit_sweep_50_levels",
            "value": 95919.76034881356,
            "unit": "ns"
          },
          {
            "name": "submit_sweep_100_levels",
            "value": 362666.3829434985,
            "unit": "ns"
          },
          {
            "name": "find_match_alloc (n=100)",
            "value": 1373.7959802605153,
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
          "id": "9aa5fee1b081788ebd7b8515d82368644ec1ba26",
          "message": "created exchange command files",
          "timestamp": "2026-06-18T18:08:10Z",
          "tree_id": "bf30e725f69da8159f530b8315d233effaa0be21",
          "url": "https://github.com/Hanny283/jsip-exchange/commit/9aa5fee1b081788ebd7b8515d82368644ec1ba26"
        },
        "date": 1781806335907,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "find_match (n=10)",
            "value": 206.99793289347065,
            "unit": "ns"
          },
          {
            "name": "find_match (n=50)",
            "value": 1035.0623127749157,
            "unit": "ns"
          },
          {
            "name": "find_match (n=100)",
            "value": 2064.132710410444,
            "unit": "ns"
          },
          {
            "name": "find_match (n=500)",
            "value": 10105.80350351123,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=10)",
            "value": 199.4090904069506,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=50)",
            "value": 1032.934915435449,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=100)",
            "value": 2030.5239699203908,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=500)",
            "value": 10278.484300473045,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=10)",
            "value": 239.97250822383478,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=50)",
            "value": 1107.8674987131087,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=100)",
            "value": 2201.27664629321,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=500)",
            "value": 10861.622054274872,
            "unit": "ns"
          },
          {
            "name": "add+remove (n=100)",
            "value": 1360.5138044668513,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=10)",
            "value": 1547.9188693524648,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=50)",
            "value": 6729.716572120084,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=100)",
            "value": 12948.819621129283,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=500)",
            "value": 63199.9393884155,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=10)",
            "value": 770.9433976679873,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=50)",
            "value": 3490.4296174247934,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=100)",
            "value": 6881.156325027221,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=500)",
            "value": 33964.36682245476,
            "unit": "ns"
          },
          {
            "name": "submit_sweep_10_levels",
            "value": 6482.927808562678,
            "unit": "ns"
          },
          {
            "name": "submit_sweep_50_levels",
            "value": 113383.6040596723,
            "unit": "ns"
          },
          {
            "name": "submit_sweep_100_levels",
            "value": 427895.1949602681,
            "unit": "ns"
          },
          {
            "name": "find_match_alloc (n=100)",
            "value": 1951.3485207329495,
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
          "id": "f366d0b8f2a23bfdf45100bd558a6a226b247f5e",
          "message": "completed 8a",
          "timestamp": "2026-06-18T21:10:22Z",
          "tree_id": "956b38b17e9ed4adca691618ead7efb52a52c541",
          "url": "https://github.com/Hanny283/jsip-exchange/commit/f366d0b8f2a23bfdf45100bd558a6a226b247f5e"
        },
        "date": 1781817268486,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "find_match (n=10)",
            "value": 210.49675202085183,
            "unit": "ns"
          },
          {
            "name": "find_match (n=50)",
            "value": 1049.496792061275,
            "unit": "ns"
          },
          {
            "name": "find_match (n=100)",
            "value": 1944.2616711883345,
            "unit": "ns"
          },
          {
            "name": "find_match (n=500)",
            "value": 9360.771014982452,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=10)",
            "value": 191.72596073190005,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=50)",
            "value": 949.070838960277,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=100)",
            "value": 1887.1053007419332,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=500)",
            "value": 9490.4383225377,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=10)",
            "value": 224.2665195860292,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=50)",
            "value": 1077.9306307316547,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=100)",
            "value": 2079.459318590844,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=500)",
            "value": 10281.242809639743,
            "unit": "ns"
          },
          {
            "name": "add+remove (n=100)",
            "value": 1259.7737754714626,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=10)",
            "value": 1467.8241926015157,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=50)",
            "value": 6279.952634268228,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=100)",
            "value": 12304.059913547408,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=500)",
            "value": 62668.39401302605,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=10)",
            "value": 773.2679471970728,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=50)",
            "value": 3518.9593291308456,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=100)",
            "value": 6778.745118815205,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=500)",
            "value": 30904.28971534848,
            "unit": "ns"
          },
          {
            "name": "submit_sweep_10_levels",
            "value": 6228.1978704394205,
            "unit": "ns"
          },
          {
            "name": "submit_sweep_50_levels",
            "value": 105759.20892750476,
            "unit": "ns"
          },
          {
            "name": "submit_sweep_100_levels",
            "value": 398846.6858016845,
            "unit": "ns"
          },
          {
            "name": "find_match_alloc (n=100)",
            "value": 1885.9337340078903,
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
          "id": "896f3b5a7eeaf23593de13385ddaa043d8e521c3",
          "message": "finished 2a and 2b",
          "timestamp": "2026-06-29T19:28:39Z",
          "tree_id": "79934e7cb9ec9e85d2eea3f8d35eb8f4fcd0366f",
          "url": "https://github.com/Hanny283/jsip-exchange/commit/896f3b5a7eeaf23593de13385ddaa043d8e521c3"
        },
        "date": 1782761602150,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "find_match (n=10)",
            "value": 11.58658463449627,
            "unit": "ns"
          },
          {
            "name": "find_match (n=50)",
            "value": 11.583552093873198,
            "unit": "ns"
          },
          {
            "name": "find_match (n=100)",
            "value": 11.732351067203675,
            "unit": "ns"
          },
          {
            "name": "find_match (n=500)",
            "value": 11.484362234437114,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=10)",
            "value": 12.361491410984772,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=50)",
            "value": 12.362029709877069,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=100)",
            "value": 12.093183434161558,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=500)",
            "value": 12.098601137650036,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=10)",
            "value": 13.479928060131822,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=50)",
            "value": 13.490364294876283,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=100)",
            "value": 13.883500239966914,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=500)",
            "value": 13.736483274418061,
            "unit": "ns"
          },
          {
            "name": "add+remove (n=100)",
            "value": 296.9956549654688,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=10)",
            "value": 104.16140993822594,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=50)",
            "value": 108.12724167873124,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=100)",
            "value": 108.54535992961407,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=500)",
            "value": 108.17238482156813,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=10)",
            "value": 52.12632778744715,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=50)",
            "value": 51.642764837447174,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=100)",
            "value": 52.50891124926676,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=500)",
            "value": 53.83740950979979,
            "unit": "ns"
          },
          {
            "name": "submit_sweep_10_levels",
            "value": 2647.136684314501,
            "unit": "ns"
          },
          {
            "name": "submit_sweep_50_levels",
            "value": 14520.281703673325,
            "unit": "ns"
          },
          {
            "name": "submit_sweep_100_levels",
            "value": 31739.097061886874,
            "unit": "ns"
          },
          {
            "name": "find_match_alloc (n=100)",
            "value": 12.384981933477206,
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
          "id": "091fe8854f6dc44d28c0bf1c5e0ef0cae1a8e9e0",
          "message": "end of day 10",
          "timestamp": "2026-06-29T21:02:41Z",
          "tree_id": "1f0699bab7d37e6be6ef351c612a5fb21e35f4a5",
          "url": "https://github.com/Hanny283/jsip-exchange/commit/091fe8854f6dc44d28c0bf1c5e0ef0cae1a8e9e0"
        },
        "date": 1782767247630,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "find_match (n=10)",
            "value": 14.37123411724949,
            "unit": "ns"
          },
          {
            "name": "find_match (n=50)",
            "value": 14.521951915333375,
            "unit": "ns"
          },
          {
            "name": "find_match (n=100)",
            "value": 14.384203369452706,
            "unit": "ns"
          },
          {
            "name": "find_match (n=500)",
            "value": 14.377256088380866,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=10)",
            "value": 14.403536390661444,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=50)",
            "value": 14.568741751257438,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=100)",
            "value": 15.312996402944368,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=500)",
            "value": 15.020830661606276,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=10)",
            "value": 16.29624310736246,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=50)",
            "value": 16.370052763492367,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=100)",
            "value": 15.399828230808927,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=500)",
            "value": 15.433000854928414,
            "unit": "ns"
          },
          {
            "name": "add+remove (n=100)",
            "value": 359.7676959671477,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=10)",
            "value": 131.1112005370594,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=50)",
            "value": 142.83323023908815,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=100)",
            "value": 143.32841955462916,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=500)",
            "value": 142.8920259184998,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=10)",
            "value": 66.31491694102213,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=50)",
            "value": 66.83162707454173,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=100)",
            "value": 67.11729504586812,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=500)",
            "value": 66.696835908383,
            "unit": "ns"
          },
          {
            "name": "submit_sweep_10_levels",
            "value": 3337.6963748004223,
            "unit": "ns"
          },
          {
            "name": "submit_sweep_50_levels",
            "value": 18936.175180672253,
            "unit": "ns"
          },
          {
            "name": "submit_sweep_100_levels",
            "value": 41615.55823934937,
            "unit": "ns"
          },
          {
            "name": "find_match_alloc (n=100)",
            "value": 14.36193433588641,
            "unit": "ns"
          }
        ]
      },
      {
        "commit": {
          "author": {
            "email": "hec66@cornell.edu",
            "name": "Hansel Carmona",
            "username": "Hanny283"
          },
          "committer": {
            "email": "hec66@cornell.edu",
            "name": "Hansel Carmona",
            "username": "Hanny283"
          },
          "distinct": true,
          "id": "14b570b6e8306a66bd77737c22a9ec957e4c4be9",
          "message": "day 10 reviews",
          "timestamp": "2026-06-30T08:16:07-04:00",
          "tree_id": "58a96085dabae099c30043c3d8bc1936d85da3ac",
          "url": "https://github.com/Hanny283/jsip-exchange/commit/14b570b6e8306a66bd77737c22a9ec957e4c4be9"
        },
        "date": 1782822009678,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "find_match (n=10)",
            "value": 43.69187103492864,
            "unit": "ns"
          },
          {
            "name": "find_match (n=50)",
            "value": 46.40655154192384,
            "unit": "ns"
          },
          {
            "name": "find_match (n=100)",
            "value": 50.802246273495186,
            "unit": "ns"
          },
          {
            "name": "find_match (n=500)",
            "value": 65.59707251267837,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=10)",
            "value": 37.61608519877944,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=50)",
            "value": 46.05149072719414,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=100)",
            "value": 49.59569492942205,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=500)",
            "value": 75.10341693972894,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=10)",
            "value": 37.63895130313455,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=50)",
            "value": 47.09864087878806,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=100)",
            "value": 46.82085105611636,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=500)",
            "value": 61.01319731059421,
            "unit": "ns"
          },
          {
            "name": "add+remove (n=100)",
            "value": 507.36806063660714,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=10)",
            "value": 151.72672899322902,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=50)",
            "value": 157.30838565610168,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=100)",
            "value": 157.0780610305667,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=500)",
            "value": 159.09447634291567,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=10)",
            "value": 68.79230749268979,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=50)",
            "value": 69.48362824122574,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=100)",
            "value": 69.5826204944462,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=500)",
            "value": 68.88828123809986,
            "unit": "ns"
          },
          {
            "name": "submit_sweep_10_levels",
            "value": 6217.4530825947595,
            "unit": "ns"
          },
          {
            "name": "submit_sweep_50_levels",
            "value": 38241.46409641841,
            "unit": "ns"
          },
          {
            "name": "submit_sweep_100_levels",
            "value": 84465.92274615014,
            "unit": "ns"
          },
          {
            "name": "find_match_alloc (n=100)",
            "value": 60.486008515340345,
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
          "id": "544f786ae6d3185ce161d829667d8b2ffdcf598f",
          "message": "end of day 11",
          "timestamp": "2026-06-30T21:03:27Z",
          "tree_id": "0a024835a7b17c7c8c6fd0ab2dfb8df8be95723b",
          "url": "https://github.com/Hanny283/jsip-exchange/commit/544f786ae6d3185ce161d829667d8b2ffdcf598f"
        },
        "date": 1782853607404,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "find_match (n=10)",
            "value": 28.97212104084026,
            "unit": "ns"
          },
          {
            "name": "find_match (n=50)",
            "value": 34.651694473557946,
            "unit": "ns"
          },
          {
            "name": "find_match (n=100)",
            "value": 37.682318907388066,
            "unit": "ns"
          },
          {
            "name": "find_match (n=500)",
            "value": 47.32566090331056,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=10)",
            "value": 28.79957695735878,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=50)",
            "value": 34.490903041295404,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=100)",
            "value": 37.49889853115609,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=500)",
            "value": 48.53341041127044,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=10)",
            "value": 24.849988840393856,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=50)",
            "value": 32.67105741744168,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=100)",
            "value": 37.16940808653132,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=500)",
            "value": 47.39081323414425,
            "unit": "ns"
          },
          {
            "name": "add+remove (n=100)",
            "value": 455.3382367821047,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=10)",
            "value": 109.36602932783168,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=50)",
            "value": 115.0456198187755,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=100)",
            "value": 115.50861742743197,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=500)",
            "value": 115.58571848045038,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=10)",
            "value": 53.837408134673204,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=50)",
            "value": 54.957731097633555,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=100)",
            "value": 53.930084912591234,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=500)",
            "value": 53.84646918785081,
            "unit": "ns"
          },
          {
            "name": "submit_sweep_10_levels",
            "value": 5288.785460082238,
            "unit": "ns"
          },
          {
            "name": "submit_sweep_50_levels",
            "value": 31240.533642456598,
            "unit": "ns"
          },
          {
            "name": "submit_sweep_100_levels",
            "value": 68410.30122636212,
            "unit": "ns"
          },
          {
            "name": "find_match_alloc (n=100)",
            "value": 37.56005107431868,
            "unit": "ns"
          }
        ]
      },
      {
        "commit": {
          "author": {
            "email": "hec66@cornell.edu",
            "name": "Hansel Carmona",
            "username": "Hanny283"
          },
          "committer": {
            "email": "hec66@cornell.edu",
            "name": "Hansel Carmona",
            "username": "Hanny283"
          },
          "distinct": true,
          "id": "d63126d648113596089bba1361e65b53af8836f1",
          "message": "order_book errors fixed",
          "timestamp": "2026-07-01T08:26:21-04:00",
          "tree_id": "e42ad8b866d037f41cbb723760e24b11373ebef4",
          "url": "https://github.com/Hanny283/jsip-exchange/commit/d63126d648113596089bba1361e65b53af8836f1"
        },
        "date": 1782909030443,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "find_match (n=10)",
            "value": 38.561291196655475,
            "unit": "ns"
          },
          {
            "name": "find_match (n=50)",
            "value": 46.77166661871704,
            "unit": "ns"
          },
          {
            "name": "find_match (n=100)",
            "value": 50.289354223568694,
            "unit": "ns"
          },
          {
            "name": "find_match (n=500)",
            "value": 65.39354150507513,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=10)",
            "value": 37.52976227171053,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=50)",
            "value": 46.01885159485055,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=100)",
            "value": 50.014805969130315,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=500)",
            "value": 64.60108972885234,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=10)",
            "value": 44.07398866206511,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=50)",
            "value": 52.741187554542094,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=100)",
            "value": 63.66482400122868,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=500)",
            "value": 82.01131859794302,
            "unit": "ns"
          },
          {
            "name": "add+remove (n=100)",
            "value": 570.9624794532803,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=10)",
            "value": 138.95800449128114,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=50)",
            "value": 137.0564148054431,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=100)",
            "value": 138.86533089767602,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=500)",
            "value": 142.26671769645768,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=10)",
            "value": 69.92755960503105,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=50)",
            "value": 69.88146136296544,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=100)",
            "value": 71.4011408481063,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=500)",
            "value": 72.49121153604474,
            "unit": "ns"
          },
          {
            "name": "submit_sweep_10_levels",
            "value": 6347.948783558051,
            "unit": "ns"
          },
          {
            "name": "submit_sweep_50_levels",
            "value": 36602.86148944001,
            "unit": "ns"
          },
          {
            "name": "submit_sweep_100_levels",
            "value": 83535.27072334636,
            "unit": "ns"
          },
          {
            "name": "find_match_alloc (n=100)",
            "value": 58.68677024299388,
            "unit": "ns"
          }
        ]
      },
      {
        "commit": {
          "author": {
            "email": "hec66@cornell.edu",
            "name": "Hansel Carmona",
            "username": "Hanny283"
          },
          "committer": {
            "email": "hec66@cornell.edu",
            "name": "Hansel Carmona",
            "username": "Hanny283"
          },
          "distinct": true,
          "id": "78340257d17a0786165b74021db089c3ae51e494",
          "message": "deleted market_maker",
          "timestamp": "2026-07-01T08:42:03-04:00",
          "tree_id": "df9d66e4beae9a4d9bf8106cbf2a93a86c60aaaf",
          "url": "https://github.com/Hanny283/jsip-exchange/commit/78340257d17a0786165b74021db089c3ae51e494"
        },
        "date": 1782910003588,
        "tool": "customSmallerIsBetter",
        "benches": [
          {
            "name": "find_match (n=10)",
            "value": 35.0920587711533,
            "unit": "ns"
          },
          {
            "name": "find_match (n=50)",
            "value": 42.55251671185439,
            "unit": "ns"
          },
          {
            "name": "find_match (n=100)",
            "value": 52.24604222002313,
            "unit": "ns"
          },
          {
            "name": "find_match (n=500)",
            "value": 68.37800847034167,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=10)",
            "value": 38.16348807785999,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=50)",
            "value": 47.508806158112186,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=100)",
            "value": 52.20542206069821,
            "unit": "ns"
          },
          {
            "name": "find_match_miss (n=500)",
            "value": 68.55047143640161,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=10)",
            "value": 43.54292613452846,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=50)",
            "value": 47.95704066490011,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=100)",
            "value": 52.07219063367598,
            "unit": "ns"
          },
          {
            "name": "best_bid_offer (n=500)",
            "value": 66.23488188739803,
            "unit": "ns"
          },
          {
            "name": "add+remove (n=100)",
            "value": 497.0000323295996,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=10)",
            "value": 133.37362715263592,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=50)",
            "value": 140.77060951823148,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=100)",
            "value": 141.4023439562983,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_cross (n=500)",
            "value": 139.84729764703442,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=10)",
            "value": 66.93885918982942,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=50)",
            "value": 66.16320465981906,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=100)",
            "value": 66.51962313441199,
            "unit": "ns"
          },
          {
            "name": "submit_ioc_miss (n=500)",
            "value": 66.49735939916087,
            "unit": "ns"
          },
          {
            "name": "submit_sweep_10_levels",
            "value": 6247.460758317111,
            "unit": "ns"
          },
          {
            "name": "submit_sweep_50_levels",
            "value": 38225.11116814631,
            "unit": "ns"
          },
          {
            "name": "submit_sweep_100_levels",
            "value": 84099.46469235522,
            "unit": "ns"
          },
          {
            "name": "find_match_alloc (n=100)",
            "value": 52.283102219854115,
            "unit": "ns"
          }
        ]
      }
    ]
  }
}