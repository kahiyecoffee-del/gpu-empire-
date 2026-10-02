"""Generates assets/config/economy.json from a few tuning knobs.

The JSON stays the single source of truth that the game reads; this script
only makes retuning reproducible. Edit the knobs below, run

    python3 tool/economy/generate.py && dart run tool/simulate.dart

and check the pacing report.
"""
import json
import pathlib

OUT = pathlib.Path(__file__).resolve().parents[2] / 'assets/config/economy.json'

# Base line archetypes (the Garage numbers). Later locations scale them.
BASE_LINES = [
    # cost, growth, cycle, income
    (4, 1.07, 1, 1),
    (60, 1.15, 3, 60),
    (720, 1.14, 6, 540),
    (25920, 1.13, 12, 4320),
    (622080, 1.12, 24, 51840),
    (6220800, 1.11, 96, 622080),
]
ROLES = [
    # role, bonus type, bonus value, cost as a multiple of the line's base cost
    ('intern', 'lineIncome', 1.25, None),
    ('sysadmin', 'infraDiscount', 0.2, None),
    ('network_engineer', 'lineIncome', 1.5, 40),
    ('ml_engineer', 'allIncome', 1.15, 40),
    ('chief_engineer', 'infraDiscount', 0.25, 40),
    ('quantum_physicist', 'lineIncome', 2, 40),
]
GARAGE_MANAGER_COSTS = {'intern': 1000, 'sysadmin': 15000}

LOCATIONS = [
    {
        'id': 'garage', 'prefix': '',
        'lines': ['legacy_gpu', 'gaming_cluster', 'datacenter_gpu', 'tpu_pod',
                  'supercomputer', 'quantum'],
        # Earn this much here to move on.
        'goal': 2e10,
        'cost_scale': 1, 'speed': 1, 'growth_add': 0,
    },
    {
        'id': 'warehouse', 'prefix': 'wh_',
        'lines': ['wh_rack_row', 'wh_inference_farm', 'wh_training_cluster',
                  'wh_tpu_superpod', 'wh_exascale', 'wh_quantum_array'],
        'goal': 5e11,
        'cost_scale': 1, 'speed': 3, 'growth_add': 0.005,
    },
    {
        'id': 'campus', 'prefix': 'cp_',
        'lines': ['cp_chip_fab', 'cp_model_foundry', 'cp_hyperscale_hall',
                  'cp_optical_compute', 'cp_neuromorphic', 'cp_quantum_lab'],
        'goal': None,
        'cost_scale': 1, 'speed': 9, 'growth_add': 0.01,
    },
]

UPGRADE_FIRST, UPGRADE_RATIO, UPGRADE_COUNT = 15000, 7, 24
UPGRADE_ORDER = [0, 1, 2, 'all', 3, 4, 0, 1, 'all', 2, 3, 5, 4, 'all']


def sig(x):
    """Rounds to 2 significant digits so the JSON stays readable."""
    return float(f'{x:.2g}')


def location(loc):
    scale, speed = loc['cost_scale'], loc['speed']
    lines = []
    for i, (cost, growth, cycle, income) in enumerate(BASE_LINES):
        base_cost = cost * scale
        line = {
            'id': loc['lines'][i],
            'baseCost': base_cost,
            'costGrowth': round(growth + loc['growth_add'], 4),
            'cycleSeconds': cycle,
            'baseIncome': income * scale * speed,
            'power': round(0.25 * base_cost, 3),
            'cooling': round(0.2 * base_cost, 3),
        }
        if i == 0:
            line['startLevel'] = 1
        lines.append(line)
    managers = []
    for i, (role, bonus, value, mult) in enumerate(ROLES):
        if loc['id'] == 'garage' and role in GARAGE_MANAGER_COSTS:
            mid, cost = role, GARAGE_MANAGER_COSTS[role]
        else:
            mid = f"{loc['id']}_{role}"
            base = GARAGE_MANAGER_COSTS.get(role)
            cost = (base * scale) if mult is None else sig(BASE_LINES[i][0] * mult * scale)
        managers.append({
            'id': mid, 'role': role, 'lineId': loc['lines'][i], 'cost': cost,
            'bonus': {'type': bonus, 'value': value},
        })
    upgrades = []
    cost = UPGRADE_FIRST * scale
    for n in range(UPGRADE_COUNT):
        target = UPGRADE_ORDER[n % len(UPGRADE_ORDER)]
        upgrades.append({
            'id': f"{loc['prefix']}upg_{n + 1:02d}",
            'lineId': 'all' if target == 'all' else loc['lines'][target],
            'multiplier': 3,
            'cost': sig(cost),
        })
        cost *= UPGRADE_RATIO
    infra = {'baseCapacity': 10 * scale, 'capacityGrowth': 1.5,
             'baseCost': 40 * scale, 'costGrowth': 1.5}
    out = {'id': loc['id']}
    if loc['goal'] is not None:
        out['goal'] = loc['goal']
    out.update({'lines': lines, 'managers': managers, 'upgrades': upgrades,
                'infrastructure': {'power': dict(infra), 'cooling': dict(infra)}})
    return out


CONFIG = {
    'schemaVersion': 2,
    'startingCash': 0,
    'milestones': [{'level': l, 'multiplier': 2}
                   for l in (25, 50, 75, 100, 150, 200, 250, 300, 400, 500)],
    'offline': {'maxSeconds': 7200, 'minReportSeconds': 60},
    'prestige': {'k': 1, 'divisor': 1e9, 'exponent': 0.5, 'bonusPerShare': 0.02},
    'contracts': {'rewardFraction': 0.03, 'levelStep': 10},
    'events': {
        'minInterval': 180, 'maxInterval': 300, 'lifetime': 25,
        'list': [
            {'id': 'viral_product', 'kind': 'boost', 'value': 5, 'seconds': 20, 'weight': 3},
            {'id': 'investor_visit', 'kind': 'cash', 'value': 45, 'weight': 3},
            {'id': 'chip_deal', 'kind': 'boost', 'value': 2, 'seconds': 120, 'weight': 2},
            {'id': 'hackathon', 'kind': 'cash', 'value': 90, 'weight': 1},
        ],
    },
    'skills': [
        {'id': 'seed_round', 'branch': 'income', 'cost': 5, 'effect': 'incomeMultiplier', 'value': 1.25},
        {'id': 'series_a', 'branch': 'income', 'cost': 25, 'effect': 'incomeMultiplier', 'value': 1.5, 'requires': 'seed_round'},
        {'id': 'unicorn', 'branch': 'income', 'cost': 150, 'effect': 'incomeMultiplier', 'value': 2, 'requires': 'series_a'},
        {'id': 'bulk_power', 'branch': 'infra', 'cost': 10, 'effect': 'infraDiscount', 'value': 0.2},
        {'id': 'liquid_cooling', 'branch': 'infra', 'cost': 40, 'effect': 'infraCapacity', 'value': 1.5, 'requires': 'bulk_power'},
        {'id': 'fusion_contract', 'branch': 'infra', 'cost': 200, 'effect': 'infraDiscount', 'value': 0.4, 'requires': 'liquid_cooling'},
        {'id': 'head_start', 'branch': 'automation', 'cost': 5, 'effect': 'startCash', 'value': 5000},
        {'id': 'night_shift', 'branch': 'automation', 'cost': 20, 'effect': 'offlineHours', 'value': 4, 'requires': 'head_start'},
        {'id': 'auto_hire', 'branch': 'automation', 'cost': 60, 'effect': 'startManagers', 'value': 2, 'requires': 'night_shift'},
        {'id': 'dreamer', 'branch': 'automation', 'cost': 250, 'effect': 'offlineHours', 'value': 8, 'requires': 'auto_hire'},
    ],
    'locations': [location(l) for l in LOCATIONS],
    'monetization': {
        'ads': {
            'overclockMultiplier': 2, 'overclockSecondsPerAd': 4 * 3600,
            'overclockMaxSeconds': 12 * 3600,
            'turboMultiplier': 5, 'turboSeconds': 120,
            'offlineAdMultiplier': 3, 'eventAdMultiplier': 2,
            'questAdMultiplier': 2, 'nearUpgradeMaxMissing': 0.25,
            'interstitialGraceSeconds': 600, 'interstitialMinGapSeconds': 240,
        },
        'timeWarps': [
            {'id': 'warp_1h', 'hours': 1, 'tokens': 20},
            {'id': 'warp_4h', 'hours': 4, 'tokens': 60},
        ],
        'products': [
            {'id': 'remove_ads', 'kind': 'nonConsumable', 'fallbackPrice': '$3.99', 'removesAds': True},
            {'id': 'starter_pack', 'kind': 'nonConsumable', 'fallbackPrice': '$1.99', 'tokens': 100, 'incomeMultiplier': 2},
            {'id': 'tokens_100', 'kind': 'consumable', 'fallbackPrice': '$0.99', 'tokens': 100},
            {'id': 'tokens_600', 'kind': 'consumable', 'fallbackPrice': '$4.99', 'tokens': 600},
            {'id': 'tokens_1400', 'kind': 'consumable', 'fallbackPrice': '$9.99', 'tokens': 1400},
        ],
        'wheel': {
            'freeEverySeconds': 4 * 3600, 'adSpinsPerDay': 3,
            # Cash prizes are seconds of income; boosts carry their duration.
            'prizes': [
                {'id': 'cash_small', 'kind': 'cash', 'value': 600, 'weight': 4},
                {'id': 'boost_3x', 'kind': 'boost', 'value': 3, 'seconds': 60, 'weight': 3},
                {'id': 'tokens_5', 'kind': 'tokens', 'value': 5, 'weight': 2},
                {'id': 'cash_big', 'kind': 'cash', 'value': 1800, 'weight': 2},
                {'id': 'overclock_1h', 'kind': 'overclock', 'value': 3600, 'weight': 2},
                {'id': 'boost_2x', 'kind': 'boost', 'value': 2, 'seconds': 300, 'weight': 3},
                {'id': 'cash_huge', 'kind': 'cash', 'value': 3600, 'weight': 1},
                {'id': 'tokens_20', 'kind': 'tokens', 'value': 20, 'weight': 1},
            ],
        },
    },
}


def num(v):
    if isinstance(v, float) and v.is_integer() and abs(v) < 1e15:
        return str(int(v))
    if isinstance(v, float) and abs(v) >= 1e15:
        return f'{v:.3g}'.replace('+', '')
    return json.dumps(v)


def inline(d):
    parts = []
    for k, v in d.items():
        val = inline(v) if isinstance(v, dict) else (json.dumps(v) if isinstance(v, (str, bool)) else num(v))
        parts.append(f'"{k}": {val}')
    return '{ ' + ', '.join(parts) + ' }'


def dump(cfg):
    out = ['{']
    for key in ('schemaVersion', 'startingCash'):
        out.append(f'  "{key}": {num(cfg[key])},')
    for key in ('offline', 'prestige', 'contracts'):
        out.append(f'  "{key}": {inline(cfg[key])},')
    out.append('  "milestones": [')
    out.append(',\n'.join('    ' + inline(m) for m in cfg['milestones']))
    out.append('  ],')
    ev = cfg['events']
    out.append('  "events": {')
    out.append(f'    "minInterval": {num(ev["minInterval"])}, "maxInterval": {num(ev["maxInterval"])}, "lifetime": {num(ev["lifetime"])},')
    out.append('    "list": [')
    out.append(',\n'.join('      ' + inline(e) for e in ev['list']))
    out.append('    ]')
    out.append('  },')
    out.append('  "skills": [')
    out.append(',\n'.join('    ' + inline(s) for s in cfg['skills']))
    out.append('  ],')
    mon = cfg['monetization']
    out.append('  "monetization": {')
    out.append(f'    "ads": {inline(mon["ads"])},')
    for key in ('timeWarps', 'products'):
        out.append(f'    "{key}": [')
        out.append(',\n'.join('      ' + inline(x) for x in mon[key]))
        out.append('    ],')
    wheel = mon['wheel']
    out.append('    "wheel": {')
    out.append(f'      "freeEverySeconds": {num(wheel["freeEverySeconds"])}, "adSpinsPerDay": {num(wheel["adSpinsPerDay"])},')
    out.append('      "prizes": [')
    out.append(',\n'.join('        ' + inline(x) for x in wheel['prizes']))
    out.append('      ]')
    out.append('    }')
    out.append('  },')
    out.append('  "locations": [')
    locs = []
    for loc in cfg['locations']:
        lines = ['    {', f'      "id": "{loc["id"]}",']
        if 'goal' in loc:
            lines.append(f'      "goal": {num(loc["goal"])},')
        for key in ('lines', 'managers', 'upgrades'):
            lines.append(f'      "{key}": [')
            lines.append(',\n'.join('        ' + inline(x) for x in loc[key]))
            lines.append('      ],')
        inf = loc['infrastructure']
        lines.append('      "infrastructure": {')
        lines.append(f'        "power": {inline(inf["power"])},')
        lines.append(f'        "cooling": {inline(inf["cooling"])}')
        lines.append('      }')
        lines.append('    }')
        locs.append('\n'.join(lines))
    out.append(',\n'.join(locs))
    out.append('  ]')
    out.append('}')
    return '\n'.join(out) + '\n'


if __name__ == '__main__':
    text = dump(CONFIG)
    json.loads(text)
    OUT.write_text(text)
    print(f'wrote {OUT}')
