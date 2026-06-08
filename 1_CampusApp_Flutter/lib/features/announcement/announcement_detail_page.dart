import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;

class AnnouncementDetailPage extends StatefulWidget {
  final String url;
  final String title;

  const AnnouncementDetailPage({super.key, required this.url, required this.title});

  @override
  State<AnnouncementDetailPage> createState() => _AnnouncementDetailPageState();
}

class _AnnouncementDetailPageState extends State<AnnouncementDetailPage> {
  String? localPath;
  String status = "正在下载 PDF...";

  @override
  void initState() {
    super.initState();
    _downloadPdf();
  }

  Future<void> _downloadPdf() async {
    // 关键修正：如果是模拟器，将 localhost 替换为 10.0.2.2
    String targetUrl = widget.url.replaceAll("localhost", "10.0.2.2");

    try {
      print("准备下载: $targetUrl");
      final response = await http.get(Uri.parse(targetUrl));

      if (response.statusCode == 200) {
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/temp_announcement.pdf');
        await file.writeAsBytes(response.bodyBytes);

        if (mounted) {
          setState(() {
            localPath = file.path;
            status = "下载完成";
          });
        }
      } else {
        setState(() => status = "下载失败 (状态码: ${response.statusCode})");
      }
    } catch (e) {
      setState(() => status = "连接失败: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: localPath != null
          ? PDFView(filePath: localPath!)
          : Center(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(status),
        ],
      )),
    );
  }
}