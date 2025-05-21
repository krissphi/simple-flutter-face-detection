import 'dart:io';

import 'package:flutter/material.dart';

class ImagePreview extends StatefulWidget {
  final String? imagePath;

  const ImagePreview({super.key, this.imagePath});

  @override
  State<ImagePreview> createState() => _ImagePreviewState();
}

class _ImagePreviewState extends State<ImagePreview> {
  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Image.file(File(widget.imagePath ?? ""), fit: BoxFit.cover),
      ),
    );
  }
}
