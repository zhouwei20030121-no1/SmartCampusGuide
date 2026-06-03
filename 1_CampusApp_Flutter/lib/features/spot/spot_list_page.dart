// lib/features/spot/spot_list_page.dart
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/theme/app_theme.dart';
import '../../core/network/network_client.dart';
import 'spot_model.dart';

class SpotListPage extends StatefulWidget {
  const SpotListPage({super.key});

  @override
  State<SpotListPage> createState() => _SpotListPageState();
}

class _SpotListPageState extends State<SpotListPage> {
  final TextEditingController _searchController = TextEditingController();
  List<SpotModel> _spotList = [];
  bool _isLoading = true;
  String _keyword = '';

  @override
  void initState() {
    super.initState();
    _fetchSpots();
  }

  Future<void> _fetchSpots() async {
    setState(() => _isLoading = true);
    try {
      final response = await NetworkClient.dio.get(
        '/spot/list',
        queryParameters: {'keyword': _keyword, 'page': 1, 'size': 50},
      );
      if (response.data['code'] == 200) {
        final List<dynamic> records = response.data['data']['records'] ?? [];
        if (mounted) {
          setState(() {
            _spotList = records.map((e) => SpotModel.fromJson(e)).toList();
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('全部景点'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '搜索校园景点...',
                prefixIcon: const Icon(Icons.search, color: AppTheme.textSub),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear, size: 20),
                  onPressed: () {
                    _searchController.clear();
                    _keyword = '';
                    _fetchSpots();
                  },
                ),
              ),
              onSubmitted: (value) {
                _keyword = value.trim();
                _fetchSpots();
              },
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : _spotList.isEmpty
          ? const Center(child: Text('暂无相关景点', style: TextStyle(color: AppTheme.textSub)))
          : ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _spotList.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final spot = _spotList[index];
          return _buildSpotCard(context, spot);
        },
      ),
    );
  }

  Widget _buildSpotCard(BuildContext context, SpotModel spot) {
    String displayImageUrl = spot.coverImage.isNotEmpty ? spot.coverImage : (spot.images.isNotEmpty ? spot.images.first : '');
    if (displayImageUrl.isNotEmpty && !displayImageUrl.startsWith('http')) {
      displayImageUrl = '${NetworkClient.baseUrl}$displayImageUrl';
    }

    return InkWell(
      onTap: () => Navigator.pushNamed(context, '/spot/detail', arguments: {'spotId': spot.id}),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 100,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
              child: displayImageUrl.isNotEmpty
                  ? CachedNetworkImage(imageUrl: displayImageUrl, width: 100, height: 100, fit: BoxFit.cover, errorWidget: (_, __, ___) => _buildPlaceholder())
                  : _buildPlaceholder(),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(spot.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textMain), maxLines: 1, overflow: TextOverflow.ellipsis),
                    const Spacer(),
                    Text(spot.description, style: const TextStyle(fontSize: 12, color: AppTheme.textSub), maxLines: 2, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.black26),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(width: 100, height: 100, color: AppTheme.lightBlue.withValues(alpha: 0.2), child: const Icon(Icons.account_balance, color: AppTheme.primary, size: 32));
  }
}