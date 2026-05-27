import 'package:flutter/material.dart';
import 'package:amap_flutter_map/amap_flutter_map.dart';
import 'package:amap_flutter_base/amap_flutter_base.dart';
import '../../core/theme/app_theme.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  // 🌟 根据最新数据，重新计算西南大学中心点 (南区北区交界处附近)
  static const LatLng _swuCenter = LatLng(29.819000, 106.422000);

  AMapController? _mapController;
  final Map<String, Marker> _markers = {};

  // 🌟 记录当前视角，强制 tilt 为 0 保持绝对 2D 俯视
  CameraPosition _currentCameraPosition = const CameraPosition(
    target: _swuCenter,
    zoom: 15.0, // 初始缩放拉远一点，方便看到南北全貌
    tilt: 0.0,
    bearing: 0.0,
  );

  @override
  void initState() {
    super.initState();
    _initCampusMarkers();
  }

  // 1. 初始化西南大学海量建筑标记（高德地图 GCJ-02 真实坐标）
  void _initCampusMarkers() {
    final List<Map<String, dynamic>> pois = [
      // ================= 一、北区（文科类学院）=================
      {'id': 'n1', 'name': '马克思主义学院', 'type': 'college', 'pos': const LatLng(29.826663, 106.428258), 'desc': '北区荟文楼'},
      {'id': 'n2', 'name': '文学院', 'type': 'college', 'pos': const LatLng(29.825848, 106.428817), 'desc': '雨僧楼（1教）'},
      {'id': 'n3', 'name': '外国语学院', 'type': 'college', 'pos': const LatLng(29.8228, 106.4296), 'desc': '雨僧楼内'},
      {'id': 'n4', 'name': '历史文化学院', 'type': 'college', 'pos': const LatLng(29.8224, 106.4294), 'desc': '雨僧楼侧楼'},
      {'id': 'n5', 'name': '教育学部', 'type': 'college', 'pos': const LatLng(29.8218, 106.4270), 'desc': '师元楼'},
      {'id': 'n6', 'name': '心理学部', 'type': 'college', 'pos': const LatLng(29.8221, 106.4268), 'desc': '师元楼旁'},
      {'id': 'n7', 'name': '经济管理学院', 'type': 'college', 'pos': const LatLng(29.8206, 106.4262), 'desc': '崇实楼'},
      {'id': 'n8', 'name': '法学院', 'type': 'college', 'pos': const LatLng(29.8209, 106.4258), 'desc': '法学院大楼'},
      {'id': 'n9', 'name': '国家治理学院', 'type': 'college', 'pos': const LatLng(29.8211, 106.4256), 'desc': '法学院旁'},
      {'id': 'n10', 'name': '商贸学院', 'type': 'college', 'pos': const LatLng(29.8202, 106.4255), 'desc': '北区办公区'},
      {'id': 'n11', 'name': '新闻传媒学院', 'type': 'college', 'pos': const LatLng(29.8222, 106.4285), 'desc': '崇德湖旁'},
      {'id': 'n12', 'name': '音乐学院', 'type': 'college', 'pos': const LatLng(29.8229, 106.4276), 'desc': '艺术楼'},
      {'id': 'n13', 'name': '美术学院', 'type': 'college', 'pos': const LatLng(29.8232, 106.4274), 'desc': '艺术楼'},
      {'id': 'n14', 'name': '体育学院', 'type': 'college', 'pos': const LatLng(29.8185, 106.4250), 'desc': '体育馆内'},

      // ================= 二、南区（理工类/农林类学院）=================
      {'id': 's1', 'name': '农学与生物科技学院', 'type': 'college', 'pos': const LatLng(29.8136, 106.4200), 'desc': '南区农科楼'},
      {'id': 's2', 'name': '植物保护学院', 'type': 'college', 'pos': const LatLng(29.8133, 106.4197), 'desc': '农科片区'},
      {'id': 's3', 'name': '园艺园林学院', 'type': 'college', 'pos': const LatLng(29.8139, 106.4194), 'desc': '园艺楼'},
      {'id': 's4', 'name': '资源环境学院', 'type': 'college', 'pos': const LatLng(29.8145, 106.4208), 'desc': '资环院'},
      {'id': 's5', 'name': '食品科学学院', 'type': 'college', 'pos': const LatLng(29.8142, 106.4203), 'desc': '食品楼'},
      {'id': 's6', 'name': '药学院', 'type': 'college', 'pos': const LatLng(29.8130, 106.4189), 'desc': '药谷'},
      {'id': 's7', 'name': '生命科学学院', 'type': 'college', 'pos': const LatLng(29.8152, 106.4211), 'desc': '生科院'},
      {'id': 's8', 'name': '化学化工学院', 'type': 'college', 'pos': const LatLng(29.8158, 106.4218), 'desc': '化学楼'},
      {'id': 's9', 'name': '物理科学与技术学院', 'type': 'college', 'pos': const LatLng(29.8162, 106.4223), 'desc': '物理楼'},
      {'id': 's10', 'name': '材料与能源学院', 'type': 'college', 'pos': const LatLng(29.8166, 106.4227), 'desc': '材料楼'},
      {'id': 's11', 'name': '计算机与信息科学学院', 'type': 'college', 'pos': const LatLng(29.82, 106.42), 'desc': '计科院'},
      {'id': 's12', 'name': '软件学院', 'type': 'college', 'pos': const LatLng(29.8177, 106.4240), 'desc': '计科院同楼'},
      {'id': 's13', 'name': '电子信息工程学院', 'type': 'college', 'pos': const LatLng(29.8179, 106.4243), 'desc': '电信院'},
      {'id': 's14', 'name': '人工智能学院', 'type': 'college', 'pos': const LatLng(29.8181, 106.4245), 'desc': '工学楼'},
      {'id': 's15', 'name': '数学与统计学院', 'type': 'college', 'pos': const LatLng(29.8169, 106.4232), 'desc': '数统院'},
      {'id': 's16', 'name': '地理科学学院', 'type': 'college', 'pos': const LatLng(29.8150, 106.4206), 'desc': '地理院'},
      {'id': 's17', 'name': '蚕桑纺织与生物质科学学院', 'type': 'college', 'pos': const LatLng(29.8146, 106.4192), 'desc': '蚕学馆'},
      {'id': 's18', 'name': '工程技术学院', 'type': 'college', 'pos': const LatLng(29.8155, 106.4215), 'desc': '工科院'},
      {'id': 's19', 'name': '国际学院', 'type': 'college', 'pos': const LatLng(29.8208, 106.4248), 'desc': '国际教育中心'},
      {'id': 's20', 'name': '教师教育学院', 'type': 'college', 'pos': const LatLng(29.8216, 106.4266), 'desc': '师元楼片区'},
      {'id': 's21', 'name': '含弘学院', 'type': 'college', 'pos': const LatLng(29.8210, 106.4260), 'desc': '含弘门旁'},

      // ================= 三、关键地标（真实坐标）=================
      {'id': 'g1', 'name': '含弘门（1号门）', 'type': 'gate', 'pos': const LatLng(29.8215, 106.4253), 'desc': '西南大学主校门'},
      {'id': 'g2', 'name': '学行门（2号门）', 'type': 'gate', 'pos': const LatLng(29.8178, 106.4258), 'desc': '天生路主入口'},
      {'id': 'g3', 'name': '天生门（3号门）', 'type': 'gate', 'pos': const LatLng(29.8188, 106.4246), 'desc': '3号门'},

      {'id': 'l1', 'name': '中心图书馆', 'type': 'library', 'pos': const LatLng(29.8235, 106.4308), 'desc': '西南大学中心图书馆'},
      {'id': 'l2', 'name': '南区图书馆', 'type': 'library', 'pos': const LatLng(29.8168, 106.4230), 'desc': '南区图书馆'},

      {'id': 'sp1', 'name': '中心体育馆', 'type': 'sports', 'pos': const LatLng(29.8182, 106.4252), 'desc': '体育馆'},
      {'id': 'sp2', 'name': '第一运动场', 'type': 'sports', 'pos': const LatLng(29.8220, 106.4278), 'desc': '北区操场'},
      {'id': 'sp3', 'name': '第二运动场', 'type': 'sports', 'pos': const LatLng(29.8195, 106.4225), 'desc': '南区操场'},
    ];

    for (var p in pois) {
      double markerHue;
      switch (p['type']) {
        case 'college': markerHue = BitmapDescriptor.hueAzure; break;   // 蓝色：学院
        case 'library': markerHue = BitmapDescriptor.hueViolet; break;  // 紫色：图书馆
        case 'sports':  markerHue = BitmapDescriptor.hueGreen; break;   // 绿色：运动场馆
        case 'gate':    markerHue = BitmapDescriptor.hueRed; break;     // 红色：校门
        default:        markerHue = BitmapDescriptor.hueOrange;
      }

      final marker = Marker(
        position: p['pos'] as LatLng,
        icon: BitmapDescriptor.defaultMarkerWithHue(markerHue),
        infoWindow: InfoWindow(
          title: p['name'] as String,
          snippet: p['desc'] as String,
        ),
      );
      _markers[p['id'] as String] = marker;
    }
  }

  // 缩放功能
  void _zoom(bool zoomIn) {
    double newZoom = _currentCameraPosition.zoom + (zoomIn ? 1.0 : -1.0);
    _mapController?.moveCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: _currentCameraPosition.target,
          zoom: newZoom,
          tilt: 0.0,
          bearing: _currentCameraPosition.bearing,
        ),
      ),
      animated: true,
    );
  }

  // 复位功能 (全局居中视角)
  void _resetPosition() {
    _mapController?.moveCamera(
      CameraUpdate.newCameraPosition(
        const CameraPosition(target: _swuCenter, zoom: 15.0, tilt: 0.0, bearing: 0.0),
      ),
      animated: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 🌏 地图主体
          AMapWidget(
            mapType: MapType.normal,
            initialCameraPosition: _currentCameraPosition,
            markers: Set<Marker>.of(_markers.values),
            myLocationStyleOptions: MyLocationStyleOptions(true),
            compassEnabled: true,

            // 🌟 优化 1：限制地图显示边界 (西南大学周边坐标)
            // 防止用户滑动到区域外，减少非必要地图瓦片的网络请求和内存加载
            limitBounds: LatLngBounds(
              southwest: const LatLng(29.80649, 106.402434),
              northeast: const LatLng(29.835163, 106.436554),
            ),

            // 🌟 优化 2：限制缩放级别
            // 防止地图缩得太小（视野过大），导致瞬间渲染海量瓦片导致卡顿
            minMaxZoomPreference: const MinMaxZoomPreference(14.0, 20.0),

            // 🌟 优化 3：关闭 3D 建筑物渲染
            // 极大减轻虚拟机的 GPU 渲染压力
            buildingsEnabled: false,

            // 🌟 核心魔法：关闭高德底图自带文字！
            labelsEnabled: false,

            onMapCreated: (controller) => _mapController = controller,
            onCameraMove: (CameraPosition position) {
              _currentCameraPosition = position;
            },
          ),

          // 🛠️ 自定义图例面板
          Positioned(
            top: 50,
            left: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('西大纯净版导览图', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                  const SizedBox(height: 8),
                  _buildLegendRow(Colors.blue, '各学院教学楼'),
                  _buildLegendRow(Colors.purple, '图书馆'),
                  _buildLegendRow(Colors.green, '体育场馆'),
                  _buildLegendRow(Colors.red, '主要校门'),
                ],
              ),
            ),
          ),

          // 🛠️ 放大缩小/复位控件
          Positioned(
            right: 16,
            bottom: 120,
            child: Column(
              children: [
                _buildMapBtn(Icons.add, () => _zoom(true)),
                const SizedBox(height: 8),
                _buildMapBtn(Icons.remove, () => _zoom(false)),
                const SizedBox(height: 16),
                _buildMapBtn(Icons.my_location, _resetPosition, color: AppTheme.primary),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendRow(Color color, String label) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.black87)),
        ],
      ),
    );
  }

  Widget _buildMapBtn(IconData icon, VoidCallback onTap, {Color color = Colors.black87}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 3))],
        ),
        child: Icon(icon, color: color, size: 24),
      ),
    );
  }
}
