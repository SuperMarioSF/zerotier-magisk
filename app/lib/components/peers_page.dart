import 'package:flutter/material.dart';
import '../services/zerotier_service.dart';
import '../l10n/app_localizations.dart'; // Import localizations
import '../models/peer_info.dart'; // Import the model

class PeersPage extends StatefulWidget {
  final ZerotierService zerotierService;

  const PeersPage({
    super.key,
    required this.zerotierService,
  });

  @override
  State<PeersPage> createState() => _PeersPageState();
}

class _PeersPageState extends State<PeersPage> {
  bool _isLoading = false;
  // Use the PeerInfo model for the list
  List<PeerInfo> _peers = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchPeers(); // Call fetch method on init
  }

  // Helper to manage loading state
  void _setLoading(bool loading) {
    if (!mounted) return;
    setState(() {
      _isLoading = loading;
      if (loading) {
        _error = null; // Clear error when starting load
      }
    });
  }

  Future<void> _fetchPeers() async {
    _setLoading(true);

    try {
      final peers = await widget.zerotierService.loadPeers();
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        setState(() {
          if (peers == null) {
            // ZeroTier服务不可用
            _error = l10n.serviceNotRunning;
            _peers = [];
          } else {
            _peers = List.from(peers);
            _error = null;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        // 存储原始错误信息，不使用 l10n
        final rawError = e.toString();
        setState(() {
          _error = rawError; // 存储原始错误，显示时再格式化
          _peers = [];
        });

        // 在确认 mounted 后使用 l10n 和 context
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.loadPeersErrorText(rawError)),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        _setLoading(false);
      }
    }
  }

  /// 把小标签做成一枚紧凑的 Chip
  Widget _buildChip(IconData icon, String label, Color color) {
    return Chip(
      avatar: Icon(icon, size: 14, color: color),
      label: Text(label, style: TextStyle(fontSize: 12, color: color)),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      backgroundColor: color.withOpacity(0.1),
      side: BorderSide.none,
    );
  }

  /// 路径状态小标记（首选 / 已过期）
  Widget _buildPathTag(String label, Color color) {
    return Container(
      margin: const EdgeInsets.only(left: 6),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label, style: TextStyle(fontSize: 10, color: color)),
    );
  }

  /// 把毫秒时间戳格式化成“多久之前”
  String _formatAge(int msTimestamp, AppLocalizations l10n) {
    if (msTimestamp <= 0) return l10n.peerTimeNever;
    final diff = DateTime.now().millisecondsSinceEpoch - msTimestamp;
    if (diff < 5000) return l10n.peerTimeJustNow;

    final seconds = diff ~/ 1000;
    if (seconds < 60) return l10n.peerTimeSecondsAgo(seconds);

    final minutes = seconds ~/ 60;
    if (minutes < 60) return l10n.peerTimeMinutesAgo(minutes);

    final hours = minutes ~/ 60;
    if (hours < 24) return l10n.peerTimeHoursAgo(hours);

    return l10n.peerTimeDaysAgo(hours ~/ 24);
  }

  /// 单条路径详情
  Widget _buildPathTile(PeerPath path, AppLocalizations l10n) {
    final theme = Theme.of(context);
    final stateColor = path.active && !path.expired
        ? Colors.green.shade600
        : theme.disabledColor;

    final detailStyle = TextStyle(
      fontSize: 11,
      color: theme.disabledColor,
      fontFamily: 'monospace',
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                path.active && !path.expired ? Icons.link : Icons.link_off,
                size: 16,
                color: stateColor,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  path.address,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (path.preferred)
                _buildPathTag(l10n.peerPathPreferred, Colors.blue.shade600),
              if (path.expired)
                _buildPathTag(l10n.peerPathExpired, Colors.red.shade600),
            ],
          ),
          const SizedBox(height: 2),
          Padding(
            padding: const EdgeInsets.only(left: 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 上游 ZeroTier 只在 bonding 启用时填 localPort，非 bonded peer 恒为 0
                // （Bond.cpp:343/1376），故为 0 时不显示，避免误导
                if (path.localPort > 0 || path.trustedPathId > 0)
                  Text(
                    [
                      if (path.localPort > 0)
                        '${l10n.peerLocalPort}: ${path.localPort}',
                      if (path.trustedPathId > 0)
                        '${l10n.peerTrustedPathId}: ${path.trustedPathId}',
                    ].join('    '),
                    style: detailStyle,
                  ),
                Text(
                  '${l10n.peerLastReceive}: ${_formatAge(path.lastReceive, l10n)}'
                  '    ${l10n.peerLastSend}: ${_formatAge(path.lastSend, l10n)}',
                  style: detailStyle,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Helper to build list item display
  Widget _buildPeerTile(PeerInfo peer, AppLocalizations l10n) {
    final theme = Theme.of(context);

    final IconData roleIcon = peer.isPlanet
        ? Icons.cloud_outlined
        : (peer.isMoon ? Icons.brightness_2_outlined : Icons.computer_outlined);
    final Color roleColor =
        peer.isPlanet ? Colors.blueGrey : theme.colorScheme.secondary;

    // 设置tunneled状态显示
    final tunnelIcon = peer.tunneled ? Icons.settings_ethernet : Icons.wifi;
    final tunnelColor =
        peer.tunneled ? Colors.orange.shade700 : Colors.green.shade600;
    final tunnelText = peer.tunneled ? l10n.peerTunneled : l10n.peerDirect;

    // 首选路径（用于快速判断该 peer 是否还活着）
    PeerPath? primaryPath;
    for (final p in peer.paths) {
      if (p.preferred && p.active && !p.expired) {
        primaryPath = p;
        break;
      }
    }
    primaryPath ??= peer.paths.isNotEmpty ? peer.paths.first : null;

    return Card(
      elevation: 1.5,
      margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 8),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
        childrenPadding: EdgeInsets.zero,
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        leading: CircleAvatar(
          backgroundColor: roleColor.withOpacity(0.1),
          child: Icon(roleIcon, size: 20, color: roleColor),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                peer.address,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // 对于非PLANET节点显示版本
            if (!peer.isPlanet && peer.version != null) ...[
              const SizedBox(width: 8),
              Text(
                peer.version!,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.normal,
                ),
              ),
            ],
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 6,
                runSpacing: 2,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _buildChip(roleIcon, peer.role, roleColor),
                  _buildChip(tunnelIcon, tunnelText, tunnelColor),
                  if (peer.isBonded)
                    _buildChip(
                        Icons.hub_outlined, l10n.peerBonded, Colors.purple.shade400),
                  if (peer.latency != null)
                    _buildChip(Icons.timer_outlined, '${peer.latency} ms',
                        Colors.orange.shade700)
                  else
                    _buildChip(Icons.timer_off_outlined,
                        l10n.peerLatencyUnknown, theme.disabledColor),
                  _buildChip(Icons.alt_route,
                      l10n.peerPathsChip(peer.pathCount, peer.activePathCount),
                      theme.colorScheme.tertiary),
                ],
              ),
              if (primaryPath != null) ...[
                const SizedBox(height: 4),
                Text(
                  '${primaryPath.address}    ${l10n.peerLastReceive}: ${_formatAge(primaryPath.lastReceive, l10n)}',
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.disabledColor,
                    fontFamily: 'monospace',
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
        children: peer.paths.isEmpty
            ? [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Text(
                    l10n.peerNoPaths,
                    style: TextStyle(fontSize: 12, color: theme.disabledColor),
                  ),
                ),
              ]
            : peer.paths.map((p) => _buildPathTile(p, l10n)).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    Widget bodyContent;

    if (_isLoading && _peers.isEmpty) {
      bodyContent = const Center(child: CircularProgressIndicator.adaptive());
    } else if (_error != null) {
      bodyContent = Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                l10n.loadPeersErrorText(_error!),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                icon: const Icon(Icons.refresh),
                label: Text(l10n.refreshButtonLabel),
                onPressed: _isLoading ? null : _fetchPeers,
              )
            ],
          ),
        ),
      );
    } else if (!_isLoading && _peers.isEmpty) {
      // Show "No peers found" centered, allowing pull-to-refresh
      bodyContent = LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Container(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            alignment: Alignment.center,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                l10n.noPeersFound,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: Theme.of(context).disabledColor),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      );
    } else {
      // Display the list using ListView.builder
      bodyContent = ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(), // Ensure scrollable even when few items
        itemCount: _peers.length,
        itemBuilder: (context, index) {
          return _buildPeerTile(_peers[index], l10n);
        },
      );
    }

    // Wrap the main content with RefreshIndicator
    return RefreshIndicator(
      onRefresh: _fetchPeers,
      child: bodyContent,
    );
  }
}
