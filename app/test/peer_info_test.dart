import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:zerotier_magisk_app/models/peer_info.dart';

/// 真实 /peer 返回格式（字段来自 ZeroTierOne/service/OneService.cpp 的 _peerToJson）
const String sampleJson = '''
[
  {
    "address": "62f865ae71",
    "versionMajor": 1,
    "versionMinor": 14,
    "versionRev": 0,
    "version": "1.14.0",
    "latency": -1,
    "role": "PLANET",
    "isBonded": false,
    "tunneled": false,
    "paths": [
      {
        "address": "50.7.252.138/9993",
        "lastSend": 0,
        "lastReceive": 0,
        "trustedPathId": 0,
        "active": false,
        "expired": true,
        "preferred": false,
        "localSocket": -1,
        "localPort": 0
      }
    ]
  },
  {
    "address": "a1b2c3d4e5",
    "versionMajor": 1,
    "versionMinor": 14,
    "versionRev": 0,
    "version": "1.14.0",
    "latency": 23,
    "role": "LEAF",
    "isBonded": true,
    "tunneled": true,
    "paths": [
      {
        "address": "192.0.2.1/9993",
        "lastSend": 1700000000000,
        "lastReceive": 1700000000000,
        "trustedPathId": 0,
        "active": true,
        "expired": false,
        "preferred": true,
        "localSocket": 42,
        "localPort": 51234
      },
      {
        "address": "100.64.0.1/9993",
        "lastSend": 1700000000000,
        "lastReceive": 1700000000000,
        "trustedPathId": 7,
        "active": true,
        "expired": false,
        "preferred": false,
        "localSocket": 43,
        "localPort": 51235
      }
    ]
  }
]
''';

void main() {
  group('PeerInfo 解析', () {
    final raw = jsonDecode(sampleJson) as List<dynamic>;
    final peers = raw
        .map((e) => PeerInfo.fromJson(e as Map<String, dynamic>))
        .toList();

    test('latency -1 解析为 null（未知）', () {
      expect(peers[0].latency, isNull);
      expect(peers[1].latency, 23);
    });

    test('PLANET / LEAF 角色识别', () {
      expect(peers[0].isPlanet, isTrue);
      expect(peers[0].isMoon, isFalse);
      expect(peers[1].isPlanet, isFalse);
    });

    test('路径数量与活跃路径数量', () {
      expect(peers[0].pathCount, 1);
      expect(peers[0].activePathCount, 0);
      expect(peers[1].pathCount, 2);
      expect(peers[1].activePathCount, 2);
    });

    test('localPort / lastSend / lastReceive / trustedPathId 解析', () {
      final p = peers[1].paths[0];
      expect(p.localPort, 51234);
      expect(p.lastSend, 1700000000000);
      expect(p.lastReceive, 1700000000000);
      expect(p.preferred, isTrue);
      expect(peers[1].paths[1].localPort, 51235);
      expect(peers[1].paths[1].trustedPathId, 7);
    });

    test('isBonded / tunneled 解析', () {
      expect(peers[0].isBonded, isFalse);
      expect(peers[1].isBonded, isTrue);
      expect(peers[1].tunneled, isTrue);
      expect(peers[0].tunneled, isFalse);
    });

    test('首选路径选取', () {
      expect(peers[1].preferredPath, '192.0.2.1/9993');
    });

    test('排序：PLANET 优先 → 直连优先 → 延迟升序', () {
      final sorted = List<PeerInfo>.from(peers)..sort();
      expect(sorted.first.isPlanet, isTrue, reason: 'PLANET 应排最前');

      // 两个 LEAF：中继(23ms) 应排在有延迟的直连后面
      final leafDirect = PeerInfo.fromJson({
        'address': 'ffffffff01',
        'latency': 100,
        'role': 'LEAF',
        'isBonded': false,
        'tunneled': false,
        'paths': [],
      });
      final leafRelayed = PeerInfo.fromJson({
        'address': 'ffffffff02',
        'latency': 5,
        'role': 'LEAF',
        'isBonded': false,
        'tunneled': true,
        'paths': [],
      });
      final mixed = [leafRelayed, leafDirect]..sort();
      expect(mixed.first.address, 'ffffffff01', reason: '直连优先于中继');
    });
  });
}
