import 'package:flutter/material.dart';

class SettingPage extends StatefulWidget {
  final Function(bool, bool) onSettingsChanged;
  final bool initialAdBlock;
  final bool initialSecurity;

  const SettingPage({
    super.key,
    required this.onSettingsChanged,
    required this.initialAdBlock,
    required this.initialSecurity,
  });

  @override
  _SettingPageState createState() => _SettingPageState();
}

class _SettingPageState extends State<SettingPage> {
  late bool isAdBlockEnabled;
  late bool isSecurityEnabled;

  @override
  void initState() {
    super.initState();
    isAdBlockEnabled = widget.initialAdBlock;
    isSecurityEnabled = widget.initialSecurity;
  }

  void _updateSettings() {
    widget.onSettingsChanged(isAdBlockEnabled, isSecurityEnabled);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Cài đặt')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              title: Text('AdBlock'),
              subtitle: Text('Chặn quảng cáo trên ứng dụng'),
              value: isAdBlockEnabled,
              onChanged: (bool value) {
                setState(() {
                  isAdBlockEnabled = value;
                });
                _updateSettings();
              },
            ),
            SwitchListTile(
              title: Text('Security'),
              subtitle: Text('Bật chế độ bảo mật nâng cao'),
              value: isSecurityEnabled,
              onChanged: (bool value) {
                setState(() {
                  isSecurityEnabled = value;
                });
                _updateSettings();
              },
            ),
          ],
        ),
      ),
    );
  }
}
