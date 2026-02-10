import 'package:flutter/material.dart';

// Shared robust image loading widget with retry logic
class RobustImage extends StatefulWidget {
  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final Widget? placeholder;
  final Widget? errorWidget;
  final Duration retryDelay;
  final int maxRetries;

  const RobustImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.placeholder,
    this.errorWidget,
    this.retryDelay = const Duration(seconds: 2),
    this.maxRetries = 3,
  });

  @override
  State<RobustImage> createState() => _RobustImageState();
}

class _RobustImageState extends State<RobustImage> {
  bool _isLoading = true;
  bool _hasError = false;
  int _retryCount = 0;

  @override
  void didUpdateWidget(RobustImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      setState(() {
        _isLoading = true;
        _hasError = false;
        _retryCount = 0;
      });
    }
  }

  void _retryLoading() {
    if (_retryCount < widget.maxRetries) {
      setState(() {
        _isLoading = true;
        _hasError = false;
        _retryCount++;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError && _retryCount >= widget.maxRetries) {
      return widget.errorWidget ??
          Container(
            width: widget.width,
            height: widget.height,
            color: Colors.grey[300],
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.image_not_supported,
                  size: 32,
                  color: Colors.grey,
                ),
                SizedBox(height: 4),
                Text(
                  'Image unavailable',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          );
    }

    Widget imageWidget = Image.network(
      widget.url,
      fit: widget.fit,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) {
          if (mounted) {
            setState(() {
              _isLoading = false;
              _hasError = false;
            });
          }
          return child;
        }
        return Container(
          width: widget.width,
          height: widget.height,
          color: Colors.grey[200],
          child: const Center(
            child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _hasError = true;
          });
        }

        if (_retryCount < widget.maxRetries) {
          Future.delayed(widget.retryDelay, () {
            if (mounted) {
              _retryLoading();
            }
          });
          return Container(
            width: widget.width,
            height: widget.height,
            color: Colors.grey[200],
            child: const Center(
              child: SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }

        return widget.errorWidget ??
            Container(
              width: widget.width,
              height: widget.height,
              color: Colors.grey[300],
              child: const Icon(
                Icons.broken_image,
                color: Colors.grey,
                size: 20,
              ),
            );
      },
    );

    if (widget.borderRadius != null) {
      imageWidget = ClipRRect(
        borderRadius: widget.borderRadius!,
        child: imageWidget,
      );
    }

    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          imageWidget,
          if (_isLoading && !_hasError)
            Container(
              color: Colors.grey[200],
              child: const Center(
                child: SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
