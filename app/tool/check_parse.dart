// 纯 Dart 校验脚本：不依赖 flutter_test / flutter_tester
// 用法：~/flutter/bin/dart run tool/check_parse.dart
import 'dart:convert';

import 'package:zerotier_magisk_app/models/peer_info.dart';

/// 真实 /peer 返回格式（字段来自 ZeroTierOne/service/OneService.cpp 的 _peerToJson）
const String sampleJson = '''
[
  {
    "address": "62f865ae71",
    "versionMajor": 1, "versionMinor": 14, "versionRev": 0,
    "version": "1.14.0",
    "latency": -1,
    "role": "PLANET",
    "isBonded": false,
    "tunneled": false,
    "paths": [
      {"address": "50.7.252.138/9993", "lastSend": 0, "lastReceive": 0,
       "trustedPathId": 0, "active": false, "expired": true, "preferred": false,
       "localSocket": -1, "localPort": 0}
    ]
  },
  {
    "address": "a1b2c3d4e5",
    "versionMajor": 1, "versionMinor": 14, "versionRev": 0,
    "version": "1.14.0",
    "latency": 23,
    "role": "LEAF",
    "isBonded": true,
    "tunneled": true,
    "paths": [
      {"address": "192.0.2.1/9993", "lastSend": 1700000000000,
       "lastReceive": 1700000000000, "trustedPathId": 0, "active": true,
       "expired": false, "preferred": true, "localSocket": 42, "localPort": 51234},
      {"address": "100.64.0.1/9993", "lastSend": 1700000000000,
       "lastReceive": 1700000000000, "trustedPathId": 7, "active": true,
       "expired": false, "preferred": false, "localSocket": 43, "localPort": 51235}
    ]
  }
]
''';

int failures = 0;

void check(String name, Object? actual, Object? expected) {
  final ok = actual == expected;
  if (!ok) failures++;
  print('${ok ? "PASS" : "FAIL"}  $name: actual=$actual expected=$expected');
}

void main() {
  final raw = jsonDecode(sampleJson) as List<dynamic>;
  final peers =
      raw.map((e) => PeerInfo.fromJson(e as Map<String, dynamic>)).toList();

  check('latency -1 → null', peers[0].latency, null);
  check('latency 23', peers[1].latency, 23);
  check('PLANET 识别', peers[0].isPlanet, true);
  check('LEAF 非 PLANET', peers[1].isPlanet, false);
  check('PLANET 路径数', peers[0].pathCount, 1);
  check('PLANET 活跃路径数', peers[0].activePathCount, 0);
  check('LEAF 路径数', peers[1].pathCount, 2);
  check('LEAF 活跃路径数', peers[1].activePathCount, 2);
  check('localPort[0]', peers[1].paths[0].localPort, 51234);
  check('localPort[1]', peers[1].paths[1].localPort, 51235);
  check('lastSend', peers[1].paths[0].lastSend, 1700000000000);
  check('lastReceive', peers[1].paths[0].lastReceive, 1700000000000);
  check('trustedPathId[1]', peers[1].paths[1].trustedPathId, 7);
  check('preferred 标记', peers[1].paths[0].preferred, true);
  check('isBonded', peers[1].isBonded, true);
  check('tunneled', peers[1].tunneled, true);
  check('首选路径', peers[1].preferredPath, '192.0.2.1/9993');

  final sorted = List<PeerInfo>.from(peers)..sort();
  check('排序：PLANET 最前', sorted.first.isPlanet, true);

  final leafDirect = PeerInfo.fromJson({
    'address': 'ffffffff01', 'latency': 100, 'role': 'LEAF',
    'isBonded': false, 'tunneled': false, 'paths': [],
  });
  final leafRelayed = PeerInfo.fromJson({
    'address': 'ffffffff02', 'latency': 5, 'role': 'LEAF',
    'isBonded': false, 'tunneled': true, 'paths': [],
  });
  final mixed = [leafRelayed, leafDirect]..sort();
  check('排序：直连优先于中继', mixed.first.address, 'ffffffff01');

  // 容错：字段缺失不应抛异常
  final minimal = PeerInfo.fromJson({'address': 'x'});
  check('缺字段容错 role', minimal.role, 'UNKNOWN');
  check('缺字段容错 latency', minimal.latency, null);
  check('缺字段容错 paths', minimal.pathCount, 0);

  print(failures == 0 ? '\n全部通过 ✅' : '\n$failures 项失败 ❌');
}
