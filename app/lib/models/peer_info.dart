// ZeroTier peer 数据模型
//
// 数据来源：本地 HTTP API `GET http://localhost:9993/peer`
// 字段定义见 ZeroTierOne/service/OneService.cpp 的 `_peerToJson()`

/// 单条网络路径（本机与某个 peer 之间的一个可用地址）
class PeerPath {
  /// 远端地址（IP:端口）
  final String address;

  /// 最近一次发包（Unix 毫秒时间戳，0 = 从未）
  final int lastSend;

  /// 最近一次收包（Unix 毫秒时间戳，0 = 从未）
  final int lastReceive;

  /// 路径是否仍然有效（未过期）
  final bool active;

  /// 路径是否已过期
  final bool expired;

  /// 是否为当前首选路径
  final bool preferred;

  /// 本机侧源端口
  final int localPort;

  /// 受信路径 ID（0 = 未设置）
  final int trustedPathId;

  PeerPath({
    required this.address,
    required this.lastSend,
    required this.lastReceive,
    required this.active,
    required this.expired,
    required this.preferred,
    required this.localPort,
    required this.trustedPathId,
  });

  factory PeerPath.fromJson(Map<String, dynamic> json) {
    return PeerPath(
      address: json['address'] as String? ?? '?',
      lastSend: _asInt(json['lastSend']),
      lastReceive: _asInt(json['lastReceive']),
      active: json['active'] as bool? ?? false,
      expired: json['expired'] as bool? ?? false,
      preferred: json['preferred'] as bool? ?? false,
      localPort: _asInt(json['localPort']),
      trustedPathId: _asInt(json['trustedPathId']),
    );
  }
}

int _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return 0;
}

class PeerInfo implements Comparable<PeerInfo> {
  final String address;

  /// 延迟（毫秒）；null 表示未知（上游返回 -1 或字段缺失）
  final int? latency;
  final String? version;
  final String role;
  final String? preferredPath;
  final bool isPlanet;
  final bool isMoon;

  /// 是否通过中继（true = 中继，false = 直连）
  final bool tunneled;

  /// 是否启用多链路绑定（bonding）
  final bool isBonded;

  /// 全部路径
  final List<PeerPath> paths;

  PeerInfo({
    required this.address,
    required this.latency,
    this.version,
    required this.role,
    this.preferredPath,
    required this.tunneled,
    required this.isBonded,
    required this.paths,
  })  : isPlanet = (role == 'PLANET'),
        isMoon = (role == 'MOON');

  /// 路径总数
  int get pathCount => paths.length;

  /// 仍然有效的路径数
  int get activePathCount => paths.where((p) => p.active && !p.expired).length;

  factory PeerInfo.fromJson(Map<String, dynamic> json) {
    final rawPaths = json['paths'] as List<dynamic>? ?? const [];
    final paths = rawPaths
        .whereType<Map<String, dynamic>>()
        .map(PeerPath.fromJson)
        .toList();

    // 优先选首选且有效的路径，否则取第一条有效路径
    String? bestPath;
    for (final p in paths) {
      if (p.preferred && p.active && !p.expired) {
        bestPath = p.address;
        break;
      }
    }
    if (bestPath == null) {
      for (final p in paths) {
        if (p.active && !p.expired) {
          bestPath = p.address;
          break;
        }
      }
    }

    final rawLatency = json['latency'];
    final latency =
        (rawLatency is num && rawLatency >= 0) ? rawLatency.toInt() : null;

    return PeerInfo(
      address: json['address'] as String? ?? 'Unknown',
      latency: latency,
      version: json['version'] as String?,
      role: json['role'] as String? ?? 'UNKNOWN',
      preferredPath: bestPath,
      tunneled: json['tunneled'] as bool? ?? false,
      isBonded: json['isBonded'] as bool? ?? false,
      paths: paths,
    );
  }

  /// 排序：PLANET 优先 → 直连优先 → 延迟升序（未知排最后）→ 地址
  @override
  int compareTo(PeerInfo other) {
    if (isPlanet != other.isPlanet) {
      return isPlanet ? -1 : 1;
    }

    if (tunneled != other.tunneled) {
      return tunneled ? 1 : -1;
    }

    if (latency != null && other.latency != null) {
      final cmp = latency!.compareTo(other.latency!);
      if (cmp != 0) return cmp;
    } else if (latency != null) {
      return -1;
    } else if (other.latency != null) {
      return 1;
    }

    return address.compareTo(other.address);
  }
}
