import 'package:flutter/material.dart';

/// The route owns its text controller through the complete dismissal animation.
Future<String?> showFormaTextPrompt(
  BuildContext context, {
  required String title,
  required String label,
  required String action,
  String description = '',
  String initialValue = '',
  int? maxLength,
  TextInputType keyboardType = TextInputType.text,
  String? Function(String?)? validator,
}) => showDialog<String>(
  context: context,
  builder: (_) => _TextPrompt(
    title: title,
    label: label,
    action: action,
    description: description,
    initialValue: initialValue,
    maxLength: maxLength,
    keyboardType: keyboardType,
    validator: validator,
  ),
);

class _TextPrompt extends StatefulWidget {
  const _TextPrompt({
    required this.title,
    required this.label,
    required this.action,
    required this.description,
    required this.initialValue,
    required this.maxLength,
    required this.keyboardType,
    required this.validator,
  });
  final String title, label, action, description, initialValue;
  final int? maxLength;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;
  @override
  State<_TextPrompt> createState() => _TextPromptState();
}

class _TextPromptState extends State<_TextPrompt> {
  final form = GlobalKey<FormState>();
  late final controller = TextEditingController(text: widget.initialValue);
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void submit() {
    if (form.currentState!.validate())
      Navigator.pop(context, controller.text.trim());
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: SingleChildScrollView(
      child: Form(
        key: form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.description.isNotEmpty) ...[
              Text(widget.description, style: const TextStyle(height: 1.7)),
              const SizedBox(height: 14),
            ],
            TextFormField(
              controller: controller,
              keyboardType: widget.keyboardType,
              maxLength: widget.maxLength,
              validator: widget.validator,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => submit(),
              decoration: InputDecoration(labelText: widget.label),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('إلغاء'),
      ),
      FilledButton(onPressed: submit, child: Text(widget.action)),
    ],
  );
}
