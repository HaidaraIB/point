import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:point/Services/mobile_version_gate.dart';
import 'package:url_launcher/url_launcher.dart';

/// Full-screen gate when the installed build is below Firestore minimum.
class ForceUpdatePage extends StatefulWidget {
  const ForceUpdatePage({super.key});

  @override
  State<ForceUpdatePage> createState() => _ForceUpdatePageState();
}

class _ForceUpdatePageState extends State<ForceUpdatePage> {
  String? _storeUrl;
  String _returnSplashRoute = '/mobileSplash';
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    final args = Get.arguments;
    if (args is ForceUpdateArgs) {
      _storeUrl = args.storeUrl;
      _returnSplashRoute = args.returnSplashRoute;
    } else if (args is String) {
      _storeUrl = args;
    }
  }

  Future<void> _openStore() async {
    final url = _storeUrl;
    if (url == null || url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (!await canLaunchUrl(uri)) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _recheckGate() async {
    setState(() => _checking = true);
    final snap = await MobileVersionGate.evaluate();
    if (!mounted) return;
    setState(() => _checking = false);

    if (!snap.blocked) {
      Get.offAllNamed(_returnSplashRoute);
      return;
    }
    setState(() => _storeUrl = snap.storeUrl);
  }

  @override
  Widget build(BuildContext context) {
    final hasUrl = _storeUrl != null && _storeUrl!.isNotEmpty;

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'force_update.title'.tr,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 16),
                Text(
                  hasUrl
                      ? 'force_update.body'.tr
                      : 'force_update.missing_store_url'.tr,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 32),
                FilledButton(
                  onPressed: !hasUrl || _checking ? null : _openStore,
                  child: Text('force_update.open_store'.tr),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _checking ? null : _recheckGate,
                  child: _checking
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text('force_update.check_again'.tr),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
