import 'package:flutter/material.dart';
import 'package:conduit/bridge_generated.dart/client.dart';
import 'package:conduit/bridge_generated.dart/factory.dart';
import 'package:conduit/bridge_generated.dart/lnurl.dart';
import 'package:conduit/screens/lnurl_amount_screen.dart';
import 'package:conduit/widgets/text_entry_body_widget.dart';

class _AddressTextController extends TextEditingController {
  Color? primaryColor;

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final atIndex = text.indexOf('@');
    if (atIndex == -1 || primaryColor == null) {
      return TextSpan(text: text, style: style);
    }

    return TextSpan(
      children: [
        TextSpan(text: text.substring(0, atIndex), style: style),
        TextSpan(
          text: text.substring(atIndex),
          style: style?.copyWith(color: primaryColor),
        ),
      ],
    );
  }
}

class LightningAddressEntryScreen extends StatefulWidget {
  final ConduitClient client;
  final ConduitClientFactory clientFactory;

  const LightningAddressEntryScreen({
    super.key,
    required this.client,
    required this.clientFactory,
  });

  @override
  State<LightningAddressEntryScreen> createState() =>
      _LightningAddressEntryScreenState();
}

class _LightningAddressEntryScreenState
    extends State<LightningAddressEntryScreen> {
  final _controller = _AddressTextController();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.requestFocus();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _handleConfirm() async {
    final input = _controller.text.trim();

    final lnurl = parseLnurl(request: input);

    if (lnurl == null) {
      throw 'Failed to parse lightning address';
    }

    final payResponse = await lnurlFetchLimits(lnurl: lnurl);

    final contactName = await widget.clientFactory.getContactName(lnurl: lnurl);

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder:
            (_) => LnurlAmountScreen(
              client: widget.client,
              clientFactory: widget.clientFactory,
              lnurl: lnurl,
              payResponse: payResponse,
              contactName: contactName,
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _controller.primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(title: const Text('Lightning Address')),
      body: TextEntryBody(
        controller: _controller,
        focusNode: _focusNode,
        onConfirm: _handleConfirm,
        keyboardType: TextInputType.emailAddress,
      ),
    );
  }
}
